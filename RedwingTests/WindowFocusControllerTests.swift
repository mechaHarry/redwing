import XCTest
@testable import Redwing

final class WindowFocusControllerTests: XCTestCase {
    func testMainWindowLookupPrefersVisibleRedwingWindow() {
        let candidates = [
            WindowFocusController.Candidate(title: "Other", isVisible: true, isMiniaturized: false),
            WindowFocusController.Candidate(title: "Redwing", isVisible: true, isMiniaturized: false)
        ]

        XCTAssertEqual(WindowFocusController.preferredMainWindowIndex(from: candidates), 1)
    }

    func testMainWindowLookupFallsBackToMiniaturizedRedwingWindow() {
        let candidates = [
            WindowFocusController.Candidate(title: "Redwing", isVisible: false, isMiniaturized: true)
        ]

        XCTAssertEqual(WindowFocusController.preferredMainWindowIndex(from: candidates), 0)
    }

    func testDefaultReopenIsAllowedWhenOnlyVisibleAuxiliaryWindowsExist() {
        let candidates = [
            WindowFocusController.Candidate(
                title: "Item-0",
                isVisible: true,
                isMiniaturized: false
            )
        ]

        XCTAssertNil(WindowFocusController.preferredMainWindowIndex(from: candidates))
    }

    func testDefaultReopenIsAllowedWhenOnlyMiniaturizedAuxiliaryWindowsExist() {
        let candidates = [
            WindowFocusController.Candidate(
                title: "Status Item Window",
                isVisible: false,
                isMiniaturized: true
            )
        ]

        XCTAssertNil(WindowFocusController.preferredMainWindowIndex(from: candidates))
    }

    func testMainWindowLookupSelectsMiniaturizedRedwingWindowFromMixedCandidates() {
        let candidates = [
            WindowFocusController.Candidate(
                title: "Status Item Window",
                isVisible: true,
                isMiniaturized: false
            ),
            WindowFocusController.Candidate(
                title: "Redwing",
                isVisible: false,
                isMiniaturized: true
            )
        ]

        XCTAssertEqual(WindowFocusController.preferredMainWindowIndex(from: candidates), 1)
    }

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

    func testCurrentDesktopCollectionBehaviorAddsMoveToActiveSpace() {
        let behavior = WindowFocusController.collectionBehaviorForCurrentDesktop(from: [])

        XCTAssertTrue(behavior.contains(.moveToActiveSpace))
    }

    func testCurrentDesktopCollectionBehaviorPreservesExistingOptions() {
        let behavior = WindowFocusController.collectionBehaviorForCurrentDesktop(from: [.fullScreenPrimary])

        XCTAssertTrue(behavior.contains(.fullScreenPrimary))
        XCTAssertTrue(behavior.contains(.moveToActiveSpace))
    }
}
