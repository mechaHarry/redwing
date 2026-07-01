import XCTest
@testable import Redwing

@MainActor
final class SpacesMessagesIntegrationTests: XCTestCase {
    func testOpeningSpaceSelectsSpaceBeforeMessagesWithRowIdentity() {
        var calls: [OpeningCall] = []
        let action = SpaceOpeningAction(
            selectSpace: { calls.append(.space(id: $0)) },
            selectMessages: { calls.append(.messages(id: $0, title: $1)) }
        )

        action(makeRow())

        XCTAssertEqual(
            calls,
            [
                .space(id: "space-1"),
                .messages(id: "space-1", title: "General"),
            ]
        )
    }

    func testRapidSpaceOpeningsFinishEachSequenceBeforeStartingTheNext() {
        let spaces = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let messages = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        var calls: [OpeningCall] = []
        let action = SpaceOpeningAction(
            selectSpace: {
                calls.append(.space(id: $0))
                spaces.select(spaceID: $0)
            },
            selectMessages: {
                calls.append(.messages(id: $0, title: $1))
                messages.select(spaceID: $0, spaceTitle: $1)
            }
        )

        action(makeRow(id: "space-a", title: "Space A"))
        action(makeRow(id: "space-b", title: "Space B"))

        XCTAssertEqual(
            calls,
            [
                .space(id: "space-a"),
                .messages(id: "space-a", title: "Space A"),
                .space(id: "space-b"),
                .messages(id: "space-b", title: "Space B"),
            ]
        )
        XCTAssertEqual(spaces.selectedSpaceID, "space-b")
        XCTAssertEqual(messages.selectedSpaceID, "space-b")
        XCTAssertEqual(messages.selectedSpaceTitle, "Space B")
    }

    private func makeRow(
        id: String = "space-1",
        title: String = "General"
    ) -> SpaceRowViewModel {
        SpaceRowViewModel(
            id: id,
            title: title,
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
