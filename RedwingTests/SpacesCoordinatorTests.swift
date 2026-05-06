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
