import XCTest
@testable import Redwing

@MainActor
final class SpacesMessagesIntegrationTests: XCTestCase {
    func testOpeningSpaceSelectsSpaceBeforeMessagesWithRowIdentity() async {
        var calls: [OpeningCall] = []
        let action = SpaceOpeningAction(
            selectSpace: { calls.append(.space(id: $0)) },
            selectMessages: { calls.append(.messages(id: $0, title: $1)) }
        )

        await action(makeRow())

        XCTAssertEqual(
            calls,
            [
                .space(id: "space-1"),
                .messages(id: "space-1", title: "General"),
            ]
        )
    }

    func testOpeningSpaceIntegratesSpacesAndMessagesCoordinators() async {
        let spaces = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let messages = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let action = SpaceOpeningAction(
            selectSpace: spaces.select(spaceID:),
            selectMessages: messages.select(spaceID:spaceTitle:)
        )

        await action(makeRow())

        XCTAssertEqual(spaces.selectedSpaceID, "space-1")
        XCTAssertEqual(messages.selectedSpaceID, "space-1")
        XCTAssertEqual(messages.selectedSpaceTitle, "General")
    }

    private func makeRow() -> SpaceRowViewModel {
        SpaceRowViewModel(
            id: "space-1",
            title: "General",
            teamLabel: nil,
            createdLabel: "",
            lastActivityLabel: "",
            avatarState: .groupPlaceholder,
            isSkeleton: false
        )
    }
}

private enum OpeningCall: Equatable {
    case space(id: String)
    case messages(id: String, title: String)
}
