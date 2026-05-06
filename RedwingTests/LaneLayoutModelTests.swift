import XCTest
@testable import Redwing

final class LaneLayoutModelTests: XCTestCase {
    func testThreadLaneHiddenForStandaloneSelection() {
        let model = LaneLayoutModel(threadVisible: false, focusedLane: .messages)

        XCTAssertEqual(model.visibleLanes.map(\.id), [.spaces, .messages])
        XCTAssertGreaterThan(
            model.width(for: .messages, totalWidth: 1200),
            model.width(for: .spaces, totalWidth: 1200)
        )
    }

    func testThreadLaneVisibleWhenThreadSelected() {
        let model = LaneLayoutModel(threadVisible: true, focusedLane: .thread)

        XCTAssertEqual(model.visibleLanes.map(\.id), [.spaces, .messages, .thread])
        XCTAssertGreaterThan(
            model.width(for: .thread, totalWidth: 1200),
            model.width(for: .spaces, totalWidth: 1200)
        )
    }

    func testMinimumWidthsPreventCollapse() {
        let model = LaneLayoutModel(threadVisible: true, focusedLane: .messages)

        XCTAssertGreaterThanOrEqual(model.width(for: .spaces, totalWidth: 500), 180)
        XCTAssertGreaterThanOrEqual(model.width(for: .messages, totalWidth: 500), 260)
    }
}
