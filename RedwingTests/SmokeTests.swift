import XCTest
@testable import Redwing

@MainActor
final class SmokeTests: XCTestCase {
    func testAppRootModelTransitions() {
        let model = AppRootModel()
        XCTAssertEqual(model.phase, .setupRequired)

        model.markLoading()
        XCTAssertEqual(model.phase, .loading)

        model.markReady()
        XCTAssertEqual(model.phase, .ready)

        model.markFailed("broken")
        XCTAssertEqual(model.phase, .failed("broken"))
    }
}
