import XCTest
@testable import Redwing

@MainActor
final class MessagesCoordinatorTests: XCTestCase {
    func testSelectingSpaceCreatesOneSharedThreadStream() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        await coordinator.select(spaceID: "space-1")

        XCTAssertNotNil(fake.messagesStreamsBySpaceID["space-1"])
        XCTAssertEqual(fake.messagesStreamsBySpaceID["space-1"]?.refreshCount, 1)
        XCTAssertTrue(coordinator.isShowingSkeletons)
    }

    func testSnapshotFeedsMessagesAndConditionalThreadLane() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        let stream = fake.messagesStreamsBySpaceID["space-1"]!
        stream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": MessageThreadEntryDTO(
                    id: "parent",
                    parentID: nil,
                    childIDs: ["child"],
                    sender: "a@example.com",
                    body: "Parent",
                    created: Date(timeIntervalSince1970: 1),
                    mentionedPeople: [],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                ),
                "child": MessageThreadEntryDTO(
                    id: "child",
                    parentID: "parent",
                    childIDs: [],
                    sender: "b@example.com",
                    body: "Child",
                    created: Date(timeIntervalSince1970: 2),
                    mentionedPeople: [],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                )
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.messageRows.map(\.id) == ["parent"] }

        XCTAssertEqual(coordinator.messageRows.map(\.id), ["parent"])
        coordinator.select(messageID: "parent")
        XCTAssertTrue(coordinator.isThreadLaneVisible)
        XCTAssertEqual(coordinator.threadRows.map(\.id), ["parent", "child"])

        coordinator.select(messageID: "child")
        XCTAssertTrue(coordinator.isThreadLaneVisible)
        XCTAssertEqual(coordinator.threadRows.map(\.id), ["parent", "child"])
    }

    func testLiveSnapshotsUpdateAttentionFeedForSelectedSpace() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let attentionFeed = AttentionFeedStore(currentUserID: "person-123")
        let coordinator = MessagesCoordinator(
            session: session,
            diagnostics: DiagnosticsStore(),
            attentionFeed: attentionFeed
        )

        await coordinator.select(spaceID: "space-1", spaceTitle: "General")
        let stream = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
        stream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["mention"],
            entriesByID: [
                "mention": MessageThreadEntryDTO(
                    id: "mention",
                    parentID: nil,
                    childIDs: [],
                    sender: "a@example.com",
                    body: "Can you review?",
                    created: Date(timeIntervalSince1970: 1),
                    mentionedPeople: ["person-123"],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                )
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { attentionFeed.items.map(\.id) == ["mention"] }

        XCTAssertEqual(attentionFeed.items.first?.spaceID, "space-1")
        XCTAssertEqual(attentionFeed.items.first?.spaceTitle, "General")
    }

    func testSameSpaceSelectionIsNoOpAfterUnavailableStream() async {
        let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["cached"],
            entriesByID: ["cached": message(id: "cached", body: "Cached")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))

        await coordinator.select(spaceID: "space-1")

        XCTAssertEqual(coordinator.messageRows.map(\.id), ["cached"])
        XCTAssertEqual(coordinator.status, .connected)
        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertTrue(coordinator.hasMore)
    }

    func testSelectingGrandchildBuildsThreadLaneFromRootParent() {
        let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["reply-1"], body: "Parent"),
                "reply-1": message(id: "reply-1", parentID: "parent", childIDs: ["reply-2"], body: "Reply 1"),
                "reply-2": message(id: "reply-2", parentID: "reply-1", body: "Reply 2")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        coordinator.select(messageID: "reply-2")

        XCTAssertTrue(coordinator.isThreadLaneVisible)
        XCTAssertEqual(coordinator.threadRows.map(\.id), ["parent", "reply-1", "reply-2"])
        XCTAssertEqual(coordinator.threadRows.map(\.depth), [0, 1, 2])
    }

    func testRepeatedSelectCancelsOldStreamAndIgnoresStaleSnapshots() async {
        let provider = SuspendedMessagesProvider()
        let session = AccountSession(clientProvider: provider, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())
        let firstStream = FakeMessagesThreadStream()
        let secondStream = FakeMessagesThreadStream()

        let firstSelect = Task { await coordinator.select(spaceID: "old-space") }
        await provider.waitForMessageStreamRequestCount(1)

        let secondSelect = Task { await coordinator.select(spaceID: "new-space") }
        await provider.waitForMessageStreamRequestCount(2)

        await provider.resumeMessageStreamRequest(at: 1, with: secondStream)
        await secondSelect.value

        await provider.resumeMessageStreamRequest(at: 0, with: firstStream)
        await firstSelect.value

        XCTAssertTrue(firstStream.isCancelled)
        XCTAssertFalse(secondStream.isCancelled)
        XCTAssertEqual(firstStream.refreshCount, 0)
        XCTAssertEqual(secondStream.refreshCount, 1)
        XCTAssertEqual(coordinator.selectedSpaceID, "new-space")

        firstStream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["old"],
            entriesByID: ["old": message(id: "old", body: "Old")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        secondStream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["new"],
            entriesByID: ["new": message(id: "new", body: "New")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.messageRows.map(\.body) == ["New"] }

        XCTAssertEqual(coordinator.messageRows.map(\.body), ["New"])
        XCTAssertTrue(coordinator.hasMore)
    }

    func testSnapshotErrorPublishesGenericStatusAndRedactedDiagnosticsDetail() {
        let diagnostics = DiagnosticsStore()
        let coordinator = MessagesCoordinator(session: nil, diagnostics: diagnostics)

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: [],
            entriesByID: [:],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: "Bearer secret-token client_secret=super-secret"
        ))

        XCTAssertEqual(coordinator.status, .failed("Messages refresh failed"))
        XCTAssertEqual(coordinator.status.label, "Failed: Messages refresh failed")
        XCTAssertEqual(diagnostics.entries.last?.source, .messages)
        XCTAssertEqual(diagnostics.entries.last?.message, "Messages refresh failed")
        XCTAssertEqual(diagnostics.entries.last?.detail, "Bearer <redacted> client_secret=<redacted>")
    }

    func testLoadNextPageDelegatesToCurrentStream() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        await coordinator.loadNextPage()

        XCTAssertEqual(fake.messagesStreamsBySpaceID["space-1"]?.loadNextPageCount, 1)
    }
}

private func message(
    id: String,
    parentID: String? = nil,
    childIDs: [String] = [],
    sender: String = "a@example.com",
    body: String
) -> MessageThreadEntryDTO {
    MessageThreadEntryDTO(
        id: id,
        parentID: parentID,
        childIDs: childIDs,
        sender: sender,
        body: body,
        created: nil,
        mentionedPeople: [],
        mentionedGroups: [],
        isPlaceholderParent: false,
        isDeletedTombstone: false
    )
}

@MainActor
private func waitUntil(
    _ condition: @escaping () -> Bool,
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        await Task.yield()
    }
    XCTAssertTrue(condition(), file: file, line: line)
}

private actor SuspendedMessagesProvider: WebexClientProviding {
    private var messageStreamContinuations: [CheckedContinuation<MessagesThreadStreamProviding, Error>] = []

    func existingAccount() async throws -> WebexAccountSummary? {
        nil
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        WebexAccountSummary(id: "account-1", displayName: "Test User", grantedScopes: credentials.scopes)
    }

    func startRealtime() async -> AsyncStream<RealtimeStateDTO> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        FakeSpacesStream()
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        try await withCheckedThrowingContinuation { continuation in
            messageStreamContinuations.append(continuation)
        }
    }

    func signOut() async throws {}

    func waitForMessageStreamRequestCount(_ count: Int) async {
        while messageStreamContinuations.count < count {
            await Task.yield()
        }
    }

    func resumeMessageStreamRequest(at index: Int, with stream: MessagesThreadStreamProviding) {
        messageStreamContinuations[index].resume(returning: stream)
    }
}
