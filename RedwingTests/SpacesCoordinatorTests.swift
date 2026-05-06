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
        await Task.yield()

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
}
