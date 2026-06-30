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

    func testActiveThreadSnapshotTargetsNewestThreadReply() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        let stream = fake.messagesStreamsBySpaceID["space-1"]!
        stream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["child"], body: "Parent"),
                "child": message(id: "child", parentID: "parent", body: "Child")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.messageRows.map(\.id) == ["parent"] }
        coordinator.select(messageID: "parent")

        stream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["child", "new-reply"], body: "Parent"),
                "child": message(id: "child", parentID: "parent", body: "Child"),
                "new-reply": message(id: "new-reply", parentID: "parent", body: "Newest")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.threadRows.map(\.id) == ["parent", "child", "new-reply"] }

        XCTAssertEqual(coordinator.threadRows.map(\.id), ["parent", "child", "new-reply"])
        XCTAssertEqual(coordinator.threadScrollTargetID, "new-reply")
    }

    func testSelectingSpaceRestoresLastOpenedThread() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        let firstStream = fake.messagesStreamsBySpaceID["space-1"]!
        firstStream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["child"], body: "Parent"),
                "child": message(id: "child", parentID: "parent", body: "Child")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.messageRows.map(\.id) == ["parent"] }
        coordinator.select(messageID: "parent")

        await coordinator.select(spaceID: "space-2")
        let secondStream = fake.messagesStreamsBySpaceID["space-2"]!
        secondStream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["other"],
            entriesByID: ["other": message(id: "other", body: "Other")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.messageRows.map(\.id) == ["other"] }
        XCTAssertFalse(coordinator.isThreadLaneVisible)

        await coordinator.select(spaceID: "space-1")
        let restoredFirstStream = fake.messagesStreamsBySpaceID["space-1"]!
        XCTAssertFalse(restoredFirstStream.isCancelled)
        restoredFirstStream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["child"], body: "Parent"),
                "child": message(id: "child", parentID: "parent", body: "Child")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.threadRows.map(\.id) == ["parent", "child"] }

        XCTAssertEqual(coordinator.selectedMessageID, "parent")
        XCTAssertTrue(coordinator.isThreadLaneVisible)
        XCTAssertEqual(coordinator.messageScrollTargetID, "parent")
        XCTAssertEqual(coordinator.threadScrollTargetID, "child")
    }

    func testMessagesLaneTargetsBottommostMessageWithoutPriorFocus() {
        let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["older", "newer"],
            entriesByID: [
                "older": message(id: "older", body: "Older"),
                "newer": message(id: "newer", body: "Newer")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertEqual(coordinator.messageScrollTargetID, "newer")
    }

    func testRealtimeSnapshotDoesNotReplaceInitialScrollRequest() {
        let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())

        coordinator.apply(snapshot: snapshot(ids: ["older", "newest"]))
        let initialRequest = coordinator.messageScrollRequest

        coordinator.apply(snapshot: snapshot(ids: ["older", "newest", "later"]))

        XCTAssertEqual(coordinator.messageRows.map(\.id), ["older", "newest", "later"])
        XCTAssertEqual(coordinator.messageScrollRequest?.targetID, "newest")
        XCTAssertEqual(coordinator.messageScrollRequest?.id, initialRequest?.id)
    }

    func testThreadLaneIssuesNewScrollRequestWhenNewestReplyTargetRepeats() {
        let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["reply"], body: "Parent"),
                "reply": message(id: "reply", parentID: "parent", body: "Original")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        coordinator.select(messageID: "parent")
        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["reply"], body: "Parent"),
                "reply": message(id: "reply", parentID: "parent", body: "Updated")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        let firstRequest = coordinator.threadScrollRequest

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": message(id: "parent", childIDs: ["reply"], body: "Parent"),
                "reply": message(id: "reply", parentID: "parent", body: "Updated again")
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertEqual(coordinator.threadScrollRequest?.targetID, "reply")
        XCTAssertNotEqual(coordinator.threadScrollRequest?.id, firstRequest?.id)
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

    func testCloseCancelsStreamClearsPresentationAndPreservesRememberedSelection() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1", spaceTitle: "General")
        let stream = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
        stream.probe.yield(snapshot(ids: ["message-1"], hasMore: true))
        await waitUntil { coordinator.messageRows.map(\.id) == ["message-1"] }
        coordinator.select(messageID: "message-1")

        coordinator.close()

        XCTAssertTrue(stream.isCancelled)
        XCTAssertNil(coordinator.selectedSpaceID)
        XCTAssertNil(coordinator.selectedSpaceTitle)
        XCTAssertNil(coordinator.selectedMessageID)
        XCTAssertEqual(coordinator.messageRows, [])
        XCTAssertEqual(coordinator.threadRows, [])
        XCTAssertFalse(coordinator.isThreadLaneVisible)
        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertFalse(coordinator.hasMore)
        XCTAssertFalse(coordinator.isLoadingNextPage)
        XCTAssertNil(coordinator.messageScrollTargetID)
        XCTAssertNil(coordinator.threadScrollTargetID)
        XCTAssertNil(coordinator.messageScrollRequest)
        XCTAssertNil(coordinator.threadScrollRequest)
        XCTAssertNil(coordinator.footerState)
        XCTAssertEqual(coordinator.status, .idle)

        await coordinator.select(spaceID: "space-1", spaceTitle: "General")
        let replacement = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
        replacement.probe.yield(snapshot(ids: ["message-1"]))
        await waitUntil { coordinator.messageRows.map(\.id) == ["message-1"] }

        XCTAssertEqual(coordinator.selectedMessageID, "message-1")
    }

    func testRetryReplacesFailedStreamAndRetainsCurrentPresentationIdentity() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1", spaceTitle: "General")
        let first = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
        first.probe.yield(snapshot(ids: ["message-1"]))
        await waitUntil { coordinator.messageRows.map(\.id) == ["message-1"] }
        coordinator.select(messageID: "message-1")
        first.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: [],
            entriesByID: [:],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: "offline"
        ))
        await waitUntil { coordinator.status == .failed("Messages refresh failed") }

        await coordinator.retry()
        let replacement = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])

        XCTAssertTrue(first.isCancelled)
        XCTAssertFalse(replacement === first)
        XCTAssertEqual(replacement.refreshCount, 1)
        XCTAssertEqual(coordinator.selectedSpaceID, "space-1")
        XCTAssertEqual(coordinator.selectedSpaceTitle, "General")
        XCTAssertEqual(coordinator.selectedMessageID, "message-1")
    }

    func testMessagesFooterAndGuardedPaginationFollowSnapshotState() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        XCTAssertNil(coordinator.footerState)
        await coordinator.select(spaceID: "space-1", spaceTitle: "General")
        XCTAssertEqual(coordinator.selectedSpaceTitle, "General")
        XCTAssertNil(coordinator.footerState)

        coordinator.apply(snapshot: snapshot(ids: ["one"], hasMore: true))
        XCTAssertEqual(coordinator.footerState, .searching)

        await coordinator.loadNextPageFromFooterIfNeeded()
        await coordinator.loadNextPageFromFooterIfNeeded()

        XCTAssertTrue(coordinator.isLoadingNextPage)
        XCTAssertEqual(fake.messagesStreamsBySpaceID["space-1"]?.loadNextPageCount, 1)

        coordinator.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["one"],
            entriesByID: ["one": message(id: "one", body: "one")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertFalse(coordinator.isLoadingNextPage)
        XCTAssertEqual(coordinator.footerState, .allFound)
    }
}

private func snapshot(ids: [String], hasMore: Bool = false) -> MessageThreadSnapshotDTO {
    MessageThreadSnapshotDTO(
        topLevelMessageIDs: ids,
        entriesByID: Dictionary(uniqueKeysWithValues: ids.map { id in
            (id, message(id: id, body: id))
        }),
        isRefreshing: false,
        isLoadingNextPage: false,
        hasMore: hasMore,
        lastErrorDescription: nil
    )
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

    func makeTeamsStream() async throws -> TeamsStreamProviding {
        FakeTeamsStream()
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        try await withCheckedThrowingContinuation { continuation in
            messageStreamContinuations.append(continuation)
        }
    }

    func loadManagerChain() async throws -> [PersonItem] {
        []
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
