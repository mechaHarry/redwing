import XCTest
@testable import Redwing

final class WindowFocusControllerTests: XCTestCase {
    func testCenteredFrameUsesTargetScreenVisibleFrame() {
        let frame = WindowFocusController.centeredFrame(
            windowSize: CGSize(width: 800, height: 500),
            visibleFrame: CGRect(x: 100, y: 50, width: 1200, height: 900)
        )

        XCTAssertEqual(frame, CGRect(x: 300, y: 250, width: 800, height: 500))
    }

    func testOversizedWindowIsClampedToVisibleFrame() {
        let frame = WindowFocusController.centeredFrame(
            windowSize: CGSize(width: 2000, height: 1200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 700)
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 1000, height: 700))
    }
}
