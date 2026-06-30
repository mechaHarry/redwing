import XCTest
@testable import Redwing

@MainActor
final class SpacesMessagesIntegrationTests: XCTestCase {
    func testSelectingSpaceStoresIDBeforeOpeningMessages() async {
        let spaces = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let messages = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let row = SpaceRowViewModel(
            id: "space-1",
            title: "General",
            teamLabel: nil,
            createdLabel: "",
            lastActivityLabel: "",
            avatarState: .groupPlaceholder,
            isSkeleton: false
        )

        spaces.select(spaceID: row.id)
        XCTAssertEqual(spaces.selectedSpaceID, "space-1")

        await messages.select(spaceID: row.id, spaceTitle: row.title)
        XCTAssertEqual(messages.selectedSpaceID, "space-1")
        XCTAssertEqual(messages.selectedSpaceTitle, "General")
    }
}
