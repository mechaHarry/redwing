import Foundation

enum SpacesMessagesLayout {
    static let spacing: CGFloat = 12
    static let minimumSpacesWidth: CGFloat = 220
    static let minimumMessagesWidth: CGFloat = 420

    struct Widths: Equatable {
        let spaces: CGFloat
        let messages: CGFloat
        let spacing: CGFloat
    }

    static func widths(totalWidth: CGFloat, isMessagesOpen: Bool) -> Widths {
        let safeTotalWidth = max(totalWidth, 0)
        guard isMessagesOpen else {
            return Widths(spaces: safeTotalWidth, messages: 0, spacing: 0)
        }

        let effectiveSpacing = min(spacing, safeTotalWidth)
        let availableWidth = safeTotalWidth - effectiveSpacing
        let combinedMinimumWidth = minimumSpacesWidth + minimumMessagesWidth

        guard availableWidth >= combinedMinimumWidth else {
            let scale = availableWidth / combinedMinimumWidth
            return Widths(
                spaces: minimumSpacesWidth * scale,
                messages: minimumMessagesWidth * scale,
                spacing: effectiveSpacing
            )
        }

        let requestedSpacesWidth = availableWidth / 3
        let spacesWidth = max(requestedSpacesWidth, minimumSpacesWidth)
        return Widths(
            spaces: spacesWidth,
            messages: availableWidth - spacesWidth,
            spacing: effectiveSpacing
        )
    }
}
