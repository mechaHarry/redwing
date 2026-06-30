import Foundation

enum SpacesMessagesLayout {
    static let spacing: CGFloat = 12
    static let minimumSpacesWidth: CGFloat = 220
    static let minimumMessagesWidth: CGFloat = 420

    struct Widths: Equatable {
        let spaces: CGFloat
        let messages: CGFloat
    }

    static func widths(totalWidth: CGFloat, isMessagesOpen: Bool) -> Widths {
        let safeTotalWidth = max(totalWidth, 0)
        guard isMessagesOpen else {
            return Widths(spaces: safeTotalWidth, messages: 0)
        }

        let availableWidth = max(safeTotalWidth - spacing, 0)
        let combinedMinimumWidth = minimumSpacesWidth + minimumMessagesWidth

        guard availableWidth >= combinedMinimumWidth else {
            let scale = availableWidth / combinedMinimumWidth
            return Widths(
                spaces: minimumSpacesWidth * scale,
                messages: minimumMessagesWidth * scale
            )
        }

        let requestedSpacesWidth = availableWidth / 3
        let spacesWidth = max(requestedSpacesWidth, minimumSpacesWidth)
        return Widths(
            spaces: spacesWidth,
            messages: availableWidth - spacesWidth
        )
    }
}
