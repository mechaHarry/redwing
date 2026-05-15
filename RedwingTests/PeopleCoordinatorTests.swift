import XCTest
@testable import Redwing

@MainActor
final class PeopleCoordinatorTests: XCTestCase {
    func testManagerChainRendersCurrentUserAtBottomAndManagersAbove() async {
        let fake = FakeWebexClientProviding()
        fake.managerChainResult = .success([
            PersonItem(id: "me", displayName: "Current User", title: "Engineer", department: "Platform", avatarURL: nil, managerID: "manager-1"),
            PersonItem(id: "manager-1", displayName: "Manager One", title: "Director", department: "Engineering", avatarURL: URL(string: "https://example.com/m1.png"), managerID: "manager-2"),
            PersonItem(id: "manager-2", displayName: "Manager Two", title: nil, department: nil, avatarURL: nil, managerID: nil)
        ])
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = PeopleCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()

        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.nodes.map(\.name), ["Manager Two", "Manager One", "Current User"])
        XCTAssertEqual(coordinator.nodes.map(\.id), ["manager-2", "manager-1", "me"])
        XCTAssertEqual(coordinator.nodes[1].avatarState, .remote(URL(string: "https://example.com/m1.png")!))
        XCTAssertEqual(coordinator.status, .connected)
    }

    func testManagerChainFailurePublishesGenericStatusAndDiagnostics() async {
        struct Failure: Error {}
        let diagnostics = DiagnosticsStore()
        let fake = FakeWebexClientProviding()
        fake.managerChainResult = .failure(Failure())
        let session = AccountSession(clientProvider: fake, diagnostics: diagnostics)
        let coordinator = PeopleCoordinator(session: session, diagnostics: diagnostics)

        await coordinator.start()

        XCTAssertEqual(coordinator.status, .failed("People unavailable"))
        XCTAssertEqual(diagnostics.entries.last?.message, "People manager chain failed")
    }
}
