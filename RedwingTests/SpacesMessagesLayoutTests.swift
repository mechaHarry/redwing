import XCTest
@testable import Redwing

final class SpacesMessagesLayoutTests: XCTestCase {
    func testClosedMessagesUsesAllAvailableWidthForSpaces() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 900, isMessagesOpen: false)

        XCTAssertEqual(widths, .init(spaces: 900, messages: 0, spacing: 0))
    }

    func testOpenMessagesUsesOneToTwoSplitAfterSpacing() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 912, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 300, messages: 600, spacing: 12))
        XCTAssertEqual(widths.spaces + widths.spacing + widths.messages, 912)
    }

    func testOpenMessagesPreservesMinimumWidthsAtExactMinimumTotal() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 652, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 220, messages: 420, spacing: 12))
    }

    func testOpenMessagesBelowMinimumScalesWithoutOverflow() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 500, isMessagesOpen: true)

        XCTAssertGreaterThanOrEqual(widths.spaces, 0)
        XCTAssertGreaterThanOrEqual(widths.messages, 0)
        XCTAssertGreaterThanOrEqual(widths.spacing, 0)
        XCTAssertEqual(widths.spaces + widths.spacing + widths.messages, 500)
    }

    func testZeroTotalWidthIsContained() {
        assertSafeWidths(totalWidth: 0)
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: 0, isMessagesOpen: true).spacing,
            0
        )
    }

    func testTotalWidthBelowStandardSpacingIsContained() {
        assertSafeWidths(totalWidth: 5)
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: 5, isMessagesOpen: true).spacing,
            5
        )
    }

    func testNegativeTotalWidthReturnsSafeValues() {
        assertSafeWidths(totalWidth: -100)

        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: false),
            .init(spaces: 0, messages: 0, spacing: 0)
        )
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: true),
            .init(spaces: 0, messages: 0, spacing: 0)
        )
    }

    private func assertSafeWidths(totalWidth: CGFloat) {
        for isMessagesOpen in [false, true] {
            let widths = SpacesMessagesLayout.widths(
                totalWidth: totalWidth,
                isMessagesOpen: isMessagesOpen
            )
            let safeTotalWidth = max(totalWidth, 0)
            let computedTotalWidth = widths.spaces + widths.spacing + widths.messages

            XCTAssertGreaterThanOrEqual(widths.spaces, 0)
            XCTAssertGreaterThanOrEqual(widths.messages, 0)
            XCTAssertGreaterThanOrEqual(widths.spacing, 0)
            XCTAssertLessThanOrEqual(computedTotalWidth, safeTotalWidth)
            if isMessagesOpen {
                XCTAssertEqual(computedTotalWidth, safeTotalWidth)
            }
        }
    }
}
