import XCTest
@testable import Redwing

final class WindowFocusControllerTests: XCTestCase {
    func testReopenWithOnlyVisibleAuxiliaryWindowOpensMainWindow() {
        let candidates = [
            WindowFocusController.Candidate(
                identifier: nil,
                title: "Redwing",
                isVisible: true,
                isMiniaturized: false
            )
        ]

        assertReopen(candidates: candidates, expectedOpenCount: 1, expectedFocusedIndices: [])
    }

    func testReopenWithNoWindowsOpensMainWindow() {
        assertReopen(candidates: [], expectedOpenCount: 1, expectedFocusedIndices: [])
    }

    func testReopenWithMixedWindowsFocusesIdentifiedMainWindow() {
        let candidates = [
            WindowFocusController.Candidate(
                identifier: nil,
                title: "Status Item Window",
                isVisible: true,
                isMiniaturized: false
            ),
            WindowFocusController.Candidate(
                identifier: RedwingWindowID.main,
                title: "Localized Main Window",
                isVisible: true,
                isMiniaturized: false
            )
        ]

        assertReopen(candidates: candidates, expectedOpenCount: 0, expectedFocusedIndices: [1])
    }

    func testReopenFocusesMiniaturizedIdentifiedMainWindow() {
        let candidates = [
            WindowFocusController.Candidate(
                identifier: RedwingWindowID.main,
                title: "Redwing",
                isVisible: false,
                isMiniaturized: true
            )
        ]

        assertReopen(candidates: candidates, expectedOpenCount: 0, expectedFocusedIndices: [0])
    }

    func testReopenFocusesIdentifiedMainWindowRegardlessOfTitle() {
        for title in ["Wrong Title", ""] {
            let candidates = [
                WindowFocusController.Candidate(
                    identifier: RedwingWindowID.main,
                    title: title,
                    isVisible: true,
                    isMiniaturized: false
                )
            ]

            assertReopen(candidates: candidates, expectedOpenCount: 0, expectedFocusedIndices: [0])
        }
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

    private func assertReopen(
        candidates: [WindowFocusController.Candidate],
        expectedOpenCount: Int,
        expectedFocusedIndices: [Int],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var openCount = 0
        var focusedIndices: [Int] = []

        let shouldHandleDefaultReopen = WindowFocusController.handleReopen(
            from: candidates,
            openMainWindow: { openCount += 1 },
            focusMainWindowAtIndex: { focusedIndices.append($0) }
        )

        XCTAssertFalse(shouldHandleDefaultReopen, file: file, line: line)
        XCTAssertEqual(openCount, expectedOpenCount, file: file, line: line)
        XCTAssertEqual(focusedIndices, expectedFocusedIndices, file: file, line: line)
    }
}
