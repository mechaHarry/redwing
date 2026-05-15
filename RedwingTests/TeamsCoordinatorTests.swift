import XCTest
@testable import Redwing

@MainActor
final class TeamsCoordinatorTests: XCTestCase {
    func testStartKeepsSkeletonUntilSnapshotArrives() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = TeamsCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()

        XCTAssertTrue(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows.count, TeamsCoordinator.skeletonRowCount)

        fake.teamsStream.probe.yield(TeamSnapshot(
            teams: [TeamItem(id: "team-1", name: "Platform", creatorID: "person-1", created: Date(timeIntervalSince1970: 10))],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))
        await waitUntil { coordinator.rows.map(\.name) == ["Platform"] }

        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows[0].creatorLabel, "Creator person-1")
        XCTAssertTrue(coordinator.hasMore)
        XCTAssertEqual(coordinator.footerState, .searching)
    }

    func testBottomVisibleRowLoadsNextPageOnlyWhenMorePagesExist() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = TeamsCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()
        coordinator.apply(snapshot: TeamSnapshot(
            teams: [
                TeamItem(id: "t1", name: "First", creatorID: nil, created: nil),
                TeamItem(id: "t2", name: "Second", creatorID: nil, created: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))

        await coordinator.loadNextPageIfNeeded(visibleRowID: "t1")
        XCTAssertEqual(fake.teamsStream.loadNextPageCount, 0)

        await coordinator.loadNextPageIfNeeded(visibleRowID: "t2")
        XCTAssertEqual(fake.teamsStream.loadNextPageCount, 1)

        coordinator.apply(snapshot: TeamSnapshot(
            teams: [
                TeamItem(id: "t1", name: "First", creatorID: nil, created: nil),
                TeamItem(id: "t2", name: "Second", creatorID: nil, created: nil)
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await coordinator.loadNextPageIfNeeded(visibleRowID: "t2")

        XCTAssertEqual(fake.teamsStream.loadNextPageCount, 1)
        XCTAssertEqual(coordinator.footerState, .allFound)
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
