import SwiftUI

struct SpacesMessagesSurface: View {
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var navigation: SessionNavigationState

    @Namespace private var glassNamespace

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = geometry.size.width - 40
            let isMessagesOpen = messages.selectedSpaceID != nil
            let widths = SpacesMessagesLayout.widths(
                totalWidth: contentWidth,
                isMessagesOpen: isMessagesOpen
            )
            let openSpace = SpaceOpeningAction(
                selectSpace: spaces.select(spaceID:),
                selectMessages: messages.select(spaceID:spaceTitle:)
            )

            GlassEffectContainer(spacing: SpacesMessagesLayout.preferredSpacing) {
                HStack(spacing: widths.effectiveSpacing) {
                    LaneSurfaceView(
                        spaces: spaces,
                        scrollAnchorID: $navigation.spacesScrollID
                    ) { row in
                        Task { @MainActor in
                            await openSpace(row)
                        }
                    }
                    .frame(width: widths.spaces)
                    .glassEffectID("spaces-card", in: glassNamespace)

                    if isMessagesOpen {
                        MessagesSurfaceView(
                            messages: messages,
                            navigation: navigation,
                            onClose: messages.close
                        )
                        .frame(width: widths.messages)
                        .glassEffectID("messages-card", in: glassNamespace)
                    }
                }
                .padding(20)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: isMessagesOpen)
        }
    }
}
