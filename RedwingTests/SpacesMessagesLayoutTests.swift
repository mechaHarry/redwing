import XCTest
@testable import Redwing

final class SpacesMessagesLayoutTests: XCTestCase {
    func testClosedMessagesUsesAllAvailableWidthForSpaces() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 900, isMessagesOpen: false)

        XCTAssertEqual(widths, .init(spaces: 900, messages: 0))
    }

    func testOpenMessagesUsesOneToTwoSplitAfterSpacing() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 912, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 300, messages: 600))
        XCTAssertEqual(widths.spaces + SpacesMessagesLayout.spacing + widths.messages, 912)
    }

    func testOpenMessagesPreservesMinimumWidthsAtExactMinimumTotal() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 652, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 220, messages: 420))
    }

    func testOpenMessagesBelowMinimumScalesWithoutOverflow() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 500, isMessagesOpen: true)

        XCTAssertGreaterThanOrEqual(widths.spaces, 0)
        XCTAssertGreaterThanOrEqual(widths.messages, 0)
        XCTAssertEqual(widths.spaces + SpacesMessagesLayout.spacing + widths.messages, 500)
    }

    func testNegativeTotalWidthReturnsSafeValues() {
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: false),
            .init(spaces: 0, messages: 0)
        )

        let openWidths = SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: true)
        XCTAssertGreaterThanOrEqual(openWidths.spaces, 0)
        XCTAssertGreaterThanOrEqual(openWidths.messages, 0)
        XCTAssertEqual(openWidths, .init(spaces: 0, messages: 0))
    }
}
