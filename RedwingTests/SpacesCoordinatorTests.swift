import XCTest
@testable import Redwing

@MainActor
final class SpacesCoordinatorTests: XCTestCase {
    func testStartKeepsSkeletonUntilSnapshotArrives() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = SpacesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()

        XCTAssertTrue(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows.count, SpacesCoordinator.skeletonRowCount)

        fake.spacesStream.probe.yield(SpaceSnapshot(
            spaces: [SpaceItem(id: "s1", title: "General", lastActivity: Date(timeIntervalSince1970: 10))],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.rows.map(\.title) == ["General"] }

        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows.map(\.title), ["General"])
        XCTAssertTrue(coordinator.hasMore)
    }

    func testSelectSpaceStoresSelectedID() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [SpaceItem(id: "s1", title: "General", lastActivity: nil)],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        coordinator.select(spaceID: "s1")

        XCTAssertEqual(coordinator.selectedSpaceID, "s1")
    }

    func testRowsDisplayTeamContextOnlyForResolvedTeamsAndDirectMessages() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(id: "s1", title: "General", type: .group, teamID: "team-123", lastActivity: nil),
                SpaceItem(id: "s2", title: "Direct", type: .direct, teamID: nil, lastActivity: nil),
                SpaceItem(id: "s3", title: "Unresolved", type: .group, teamID: nil, lastActivity: nil),
                SpaceItem(id: "s4", title: "Resolved", type: .group, teamID: "team-456", teamName: "Platform Team", lastActivity: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertNil(coordinator.rows[0].teamLabel)
        XCTAssertEqual(coordinator.rows[1].teamLabel, "Direct Message")
        XCTAssertNil(coordinator.rows[2].teamLabel)
        XCTAssertEqual(coordinator.rows[3].teamLabel, "Platform Team")
        XCTAssertEqual(
            coordinator.rows.map(\.avatarState),
            [.groupPlaceholder, .directPlaceholder, .groupPlaceholder, .groupPlaceholder]
        )
    }

    func testRowsFleshInSpaceEnrichmentWithoutResettingSkeletonsOrIDs() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let avatarURL = URL(string: "https://example.com/direct.png")!

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(id: "group-space", title: "General", type: .group, teamID: "team-123", lastActivity: nil),
                SpaceItem(id: "direct-space", title: "Alex", type: .direct, teamID: nil, lastActivity: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        let baseRowIDs = coordinator.rows.map(\.id)
        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertNil(coordinator.rows[0].teamLabel)
        XCTAssertEqual(coordinator.rows[1].teamLabel, "Direct Message")
        XCTAssertEqual(coordinator.rows.map(\.avatarState), [.groupPlaceholder, .directPlaceholder])

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(
                    id: "group-space",
                    title: "General",
                    type: .group,
                    teamID: "team-123",
                    teamName: "Platform Team",
                    lastActivity: nil
                ),
                SpaceItem(
                    id: "direct-space",
                    title: "Alex",
                    type: .direct,
                    teamID: nil,
                    lastActivity: nil,
                    iconURL: avatarURL
                )
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertEqual(coordinator.rows.map(\.id), baseRowIDs)
        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows[0].teamLabel, "Platform Team")
        XCTAssertEqual(coordinator.rows[1].teamLabel, "Direct Message")
        XCTAssertEqual(coordinator.rows.map(\.avatarState), [.groupPlaceholder, .remote(avatarURL)])
    }

    func testRowsDisplayAvatarStateForDirectLoadingAndPlaceholders() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let avatarURL = URL(string: "https://example.com/direct.png")!

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(id: "group", title: "Group", type: .group, lastActivity: nil),
                SpaceItem(id: "direct", title: "Direct", type: .direct, lastActivity: nil),
                SpaceItem(id: "loading-direct", title: "Loading", type: .direct, lastActivity: nil, enrichmentStatus: .loading),
                SpaceItem(id: "loaded-direct", title: "Loaded", type: .direct, lastActivity: nil, iconURL: avatarURL, enrichmentStatus: .complete),
                SpaceItem(id: "loading-group", title: "Loading Team", type: .group, lastActivity: nil, enrichmentStatus: .loading)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertEqual(
            coordinator.rows.map(\.avatarState),
            [.groupPlaceholder, .directPlaceholder, .loading, .remote(avatarURL), .loading]
        )
    }

    func testRowsDisplayCreatedDateAndLastActiveDate() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let created = Date(timeIntervalSince1970: 1_704_110_400)
        let lastActivity = Date(timeIntervalSince1970: 1_704_114_000)

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(
                    id: "s1",
                    title: "General",
                    type: .group,
                    lastActivity: lastActivity,
                    created: created
                ),
                SpaceItem(id: "s2", title: "Direct", type: .direct, lastActivity: nil, created: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        XCTAssertTrue(coordinator.rows[0].createdLabel.hasPrefix("Created "))
        XCTAssertTrue(coordinator.rows[0].createdLabel.contains("2024"))
        XCTAssertTrue(coordinator.rows[0].lastActivityLabel.hasPrefix("Last active "))
        XCTAssertTrue(coordinator.rows[0].lastActivityLabel.contains("2024"))
        XCTAssertEqual(coordinator.rows[1].createdLabel, "Created unknown")
        XCTAssertEqual(coordinator.rows[1].lastActivityLabel, "Last active unknown")
    }

    func testRepeatedStartCancelsOldStreamAndIgnoresStaleSnapshots() async {
        let provider = SuspendedSpacesProvider()
        let session = AccountSession(clientProvider: provider, diagnostics: DiagnosticsStore())
        let coordinator = SpacesCoordinator(session: session, diagnostics: DiagnosticsStore())
        let firstStream = FakeSpacesStream()
        let secondStream = FakeSpacesStream()

        let firstStart = Task { await coordinator.start() }
        await provider.waitForStreamRequestCount(1)

        let secondStart = Task { await coordinator.start() }
        await provider.waitForStreamRequestCount(2)

        await provider.resumeStreamRequest(at: 1, with: secondStream)
        await secondStart.value

        await provider.resumeStreamRequest(at: 0, with: firstStream)
        await firstStart.value

        XCTAssertTrue(firstStream.isCancelled)
        XCTAssertFalse(secondStream.isCancelled)
        XCTAssertEqual(firstStream.refreshCount, 0)
        XCTAssertEqual(secondStream.refreshCount, 1)

        firstStream.probe.yield(SpaceSnapshot(
            spaces: [SpaceItem(id: "old", title: "Old", lastActivity: nil)],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        secondStream.probe.yield(SpaceSnapshot(
            spaces: [SpaceItem(id: "new", title: "New", lastActivity: nil)],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.rows.map(\.title) == ["New"] }

        XCTAssertEqual(coordinator.rows.map(\.title), ["New"])
        XCTAssertTrue(coordinator.hasMore)
    }

    func testSnapshotErrorPublishesGenericStatusAndRedactedDiagnosticsDetail() {
        let diagnostics = DiagnosticsStore()
        let coordinator = SpacesCoordinator(session: nil, diagnostics: diagnostics)

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: "Bearer secret-token client_secret=super-secret"
        ))

        XCTAssertEqual(coordinator.status, .failed("Spaces refresh failed"))
        XCTAssertEqual(coordinator.status.label, "Failed: Spaces refresh failed")
        XCTAssertEqual(diagnostics.entries.last?.message, "Spaces refresh failed")
        XCTAssertEqual(diagnostics.entries.last?.detail, "Bearer <redacted> client_secret=<redacted>")
    }

    func testLoadNextPageDelegatesToCurrentStream() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = SpacesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()
        await coordinator.loadNextPage()

        XCTAssertEqual(fake.spacesStream.loadNextPageCount, 1)
    }

    func testBottomVisibleRowLoadsNextPageOnlyWhenMorePagesExist() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = SpacesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()
        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(id: "s1", title: "First", lastActivity: nil),
                SpaceItem(id: "s2", title: "Second", lastActivity: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))

        await coordinator.loadNextPageIfNeeded(visibleRowID: "s1")
        XCTAssertEqual(fake.spacesStream.loadNextPageCount, 0)

        await coordinator.loadNextPageIfNeeded(visibleRowID: "s2")
        XCTAssertEqual(fake.spacesStream.loadNextPageCount, 1)

        await coordinator.loadNextPageIfNeeded(visibleRowID: "s2")
        XCTAssertEqual(fake.spacesStream.loadNextPageCount, 1)

        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [
                SpaceItem(id: "s1", title: "First", lastActivity: nil),
                SpaceItem(id: "s2", title: "Second", lastActivity: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await coordinator.loadNextPageIfNeeded(visibleRowID: "s2")

        XCTAssertEqual(fake.spacesStream.loadNextPageCount, 1)
    }
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

private actor SuspendedSpacesProvider: WebexClientProviding {
    private var streamContinuations: [CheckedContinuation<SpacesStreamProviding, Error>] = []

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
        try await withCheckedThrowingContinuation { continuation in
            streamContinuations.append(continuation)
        }
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        FakeMessagesThreadStream()
    }

    func signOut() async throws {}

    func waitForStreamRequestCount(_ count: Int) async {
        while streamContinuations.count < count {
            await Task.yield()
        }
    }

    func resumeStreamRequest(at index: Int, with stream: SpacesStreamProviding) {
        streamContinuations[index].resume(returning: stream)
    }
}
