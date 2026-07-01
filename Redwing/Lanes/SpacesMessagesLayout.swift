import Foundation

enum SpacesMessagesLayout {
    static let preferredSpacing: CGFloat = 12
    static let minimumSpacesWidth: CGFloat = 220
    static let minimumMessagesWidth: CGFloat = 420

    struct Widths: Equatable {
        let spaces: CGFloat
        let messages: CGFloat
        let effectiveSpacing: CGFloat
    }

    static func widths(totalWidth: CGFloat, isMessagesOpen: Bool) -> Widths {
        guard totalWidth.isFinite else {
            return Widths(spaces: 0, messages: 0, effectiveSpacing: 0)
        }

        let safeTotalWidth = max(totalWidth, 0)
        guard isMessagesOpen else {
            return Widths(spaces: safeTotalWidth, messages: 0, effectiveSpacing: 0)
        }

        let effectiveSpacing = min(preferredSpacing, safeTotalWidth)
        let availableWidth = safeTotalWidth - effectiveSpacing
        let combinedMinimumWidth = minimumSpacesWidth + minimumMessagesWidth

        guard availableWidth >= combinedMinimumWidth else {
            let scale = availableWidth / combinedMinimumWidth
            return Widths(
                spaces: minimumSpacesWidth * scale,
                messages: minimumMessagesWidth * scale,
                effectiveSpacing: effectiveSpacing
            )
        }

        let requestedSpacesWidth = availableWidth / 3
        let spacesWidth = max(requestedSpacesWidth, minimumSpacesWidth)
        return Widths(
            spaces: spacesWidth,
            messages: availableWidth - spacesWidth,
            effectiveSpacing: effectiveSpacing
        )
    }
}
