import XCTest
@testable import Redwing

final class SpacesMessagesLayoutTests: XCTestCase {
    private let accuracy: CGFloat = 0.000_001

    func testClosedMessagesUsesAllAvailableWidthForSpaces() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 900, isMessagesOpen: false)

        XCTAssertEqual(widths, .init(spaces: 900, messages: 0, effectiveSpacing: 0))
    }

    func testOpenMessagesUsesOneToTwoSplitAfterSpacing() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 912, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 300, messages: 600, effectiveSpacing: 12))
        assertOpenTotal(widths, equals: 912)
    }

    func testOpenMessagesPreservesMinimumWidthsAtExactMinimumTotal() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 652, isMessagesOpen: true)

        XCTAssertEqual(widths, .init(spaces: 220, messages: 420, effectiveSpacing: 12))
    }

    func testOpenMessagesBelowMinimumScalesWithoutOverflow() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 500, isMessagesOpen: true)

        XCTAssertGreaterThanOrEqual(widths.spaces, 0)
        XCTAssertGreaterThanOrEqual(widths.messages, 0)
        XCTAssertGreaterThanOrEqual(widths.effectiveSpacing, 0)
        assertOpenTotal(widths, equals: 500)
    }

    func testZeroTotalWidthIsContained() {
        assertSafeWidths(totalWidth: 0)
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: 0, isMessagesOpen: true).effectiveSpacing,
            0
        )
    }

    func testTotalWidthBelowPreferredSpacingIsContained() {
        assertSafeWidths(totalWidth: 5)
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: 5, isMessagesOpen: true).effectiveSpacing,
            5
        )
    }

    func testNegativeTotalWidthReturnsSafeValues() {
        assertSafeWidths(totalWidth: -100)

        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: false),
            .init(spaces: 0, messages: 0, effectiveSpacing: 0)
        )
        XCTAssertEqual(
            SpacesMessagesLayout.widths(totalWidth: -100, isMessagesOpen: true),
            .init(spaces: 0, messages: 0, effectiveSpacing: 0)
        )
    }

    func testNonFiniteTotalWidthsReturnFiniteZeros() {
        for totalWidth in [CGFloat.nan, .infinity, -.infinity] {
            for isMessagesOpen in [false, true] {
                let widths = SpacesMessagesLayout.widths(
                    totalWidth: totalWidth,
                    isMessagesOpen: isMessagesOpen
                )

                XCTAssertTrue(widths.spaces.isFinite)
                XCTAssertTrue(widths.messages.isFinite)
                XCTAssertTrue(widths.effectiveSpacing.isFinite)
                XCTAssertEqual(
                    widths,
                    .init(spaces: 0, messages: 0, effectiveSpacing: 0)
                )
            }
        }
    }

    func testFractionalNormalWidthMaintainsExactOneToTwoRatio() {
        let totalWidth: CGFloat = 912.25
        let widths = SpacesMessagesLayout.widths(
            totalWidth: totalWidth,
            isMessagesOpen: true
        )

        XCTAssertEqual(widths.effectiveSpacing, 12, accuracy: accuracy)
        XCTAssertEqual(widths.messages, 2 * widths.spaces, accuracy: accuracy)
        assertOpenTotal(widths, equals: totalWidth)
    }

    func testFractionalContractedWidthFillsAvailableSpace() {
        let totalWidth: CGFloat = 22.063
        let widths = SpacesMessagesLayout.widths(
            totalWidth: totalWidth,
            isMessagesOpen: true
        )

        XCTAssertGreaterThanOrEqual(widths.spaces, 0)
        XCTAssertGreaterThanOrEqual(widths.messages, 0)
        XCTAssertEqual(widths.effectiveSpacing, 12, accuracy: accuracy)
        assertOpenTotal(widths, equals: totalWidth)
    }

    func testCombinedMinimumBoundaryTransitionsFromProportionalContraction() {
        let delta: CGFloat = 0.001
        let belowTotal: CGFloat = 652 - delta
        let below = SpacesMessagesLayout.widths(totalWidth: belowTotal, isMessagesOpen: true)
        let scale = (belowTotal - SpacesMessagesLayout.preferredSpacing) / 640

        XCTAssertEqual(below.spaces, 220 * scale, accuracy: accuracy)
        XCTAssertEqual(below.messages, 420 * scale, accuracy: accuracy)
        assertOpenTotal(below, equals: belowTotal)

        let at = SpacesMessagesLayout.widths(totalWidth: 652, isMessagesOpen: true)
        XCTAssertEqual(at.spaces, 220, accuracy: accuracy)
        XCTAssertEqual(at.messages, 420, accuracy: accuracy)
        assertOpenTotal(at, equals: 652)

        let aboveTotal: CGFloat = 652 + delta
        let above = SpacesMessagesLayout.widths(totalWidth: aboveTotal, isMessagesOpen: true)
        XCTAssertEqual(above.spaces, 220, accuracy: accuracy)
        XCTAssertEqual(above.messages, 420 + delta, accuracy: accuracy)
        assertOpenTotal(above, equals: aboveTotal)
    }

    func testIdealRatioBoundaryTransitionsAtSpacesMinimum() {
        let delta: CGFloat = 0.001
        let belowTotal: CGFloat = 672 - delta
        let below = SpacesMessagesLayout.widths(totalWidth: belowTotal, isMessagesOpen: true)
        XCTAssertEqual(below.spaces, 220, accuracy: accuracy)
        XCTAssertEqual(below.messages, 440 - delta, accuracy: accuracy)
        assertOpenTotal(below, equals: belowTotal)

        let at = SpacesMessagesLayout.widths(totalWidth: 672, isMessagesOpen: true)
        XCTAssertEqual(at.spaces, 220, accuracy: accuracy)
        XCTAssertEqual(at.messages, 440, accuracy: accuracy)
        assertOpenTotal(at, equals: 672)

        let aboveTotal: CGFloat = 672 + delta
        let above = SpacesMessagesLayout.widths(totalWidth: aboveTotal, isMessagesOpen: true)
        XCTAssertEqual(above.messages, 2 * above.spaces, accuracy: accuracy)
        assertOpenTotal(above, equals: aboveTotal)
    }

    private func assertSafeWidths(totalWidth: CGFloat) {
        for isMessagesOpen in [false, true] {
            let widths = SpacesMessagesLayout.widths(
                totalWidth: totalWidth,
                isMessagesOpen: isMessagesOpen
            )
            let safeTotalWidth = max(totalWidth, 0)
            let computedTotalWidth = widths.spaces + widths.effectiveSpacing + widths.messages

            XCTAssertGreaterThanOrEqual(widths.spaces, 0)
            XCTAssertGreaterThanOrEqual(widths.messages, 0)
            XCTAssertGreaterThanOrEqual(widths.effectiveSpacing, 0)
            XCTAssertLessThanOrEqual(computedTotalWidth, safeTotalWidth + accuracy)
            if isMessagesOpen {
                XCTAssertEqual(computedTotalWidth, safeTotalWidth, accuracy: accuracy)
            }
        }
    }

    private func assertOpenTotal(
        _ widths: SpacesMessagesLayout.Widths,
        equals totalWidth: CGFloat
    ) {
        XCTAssertEqual(
            widths.spaces + widths.effectiveSpacing + widths.messages,
            totalWidth,
            accuracy: accuracy
        )
    }
}
