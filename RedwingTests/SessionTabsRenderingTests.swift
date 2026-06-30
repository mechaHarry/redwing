import AppKit
import SwiftUI
import XCTest
@testable import Redwing

@MainActor
final class SessionTabsRenderingTests: XCTestCase {
    func testRenderedSessionTabsPreserveIndependentNavigationAcrossSwitches() async {
        let diagnostics = DiagnosticsStore()
        let spaces = SpacesCoordinator(session: nil, diagnostics: diagnostics)
        let messages = MessagesCoordinator(session: nil, diagnostics: diagnostics)
        let teams = TeamsCoordinator(session: nil, diagnostics: diagnostics)
        let people = PeopleCoordinator(session: nil, diagnostics: diagnostics)
        let navigation = SessionNavigationState()
        navigation.spacesScrollID = "space-anchor"
        navigation.rememberMessageAnchor(
            spaceID: "selected-space",
            id: "message-anchor",
            index: 1
        )
        await messages.select(spaceID: "selected-space", spaceTitle: "Selected Space")
        let hostingView = NSHostingView(rootView: SessionTabsView(
            spaces: spaces,
            messages: messages,
            teams: teams,
            people: people,
            navigation: navigation
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1_000, height: 700)
        hostingView.layoutSubtreeIfNeeded()

        navigation.selectedTab = .teams
        navigation.teamsScrollID = "team-anchor"
        await render(hostingView)
        navigation.selectedTab = .people
        navigation.peopleScrollID = "person-anchor"
        await render(hostingView)
        navigation.selectedTab = .spaces
        await render(hostingView)

        XCTAssertEqual(navigation.selectedTab, .spaces)
        XCTAssertEqual(navigation.spacesScrollID, "space-anchor")
        XCTAssertEqual(navigation.teamsScrollID, "team-anchor")
        XCTAssertEqual(navigation.peopleScrollID, "person-anchor")
        XCTAssertEqual(messages.selectedSpaceID, "selected-space")
        XCTAssertEqual(
            navigation.restoredMessageID(
                spaceID: "selected-space",
                rowIDs: ["older-message", "message-anchor"]
            ),
            "message-anchor"
        )
        withExtendedLifetime(hostingView) {}
    }

    func testMainTabsProvideDirectCommandNumberShortcuts() {
        XCTAssertEqual(RedwingMainTab.spaces.keyboardShortcutKey, "1")
        XCTAssertEqual(RedwingMainTab.teams.keyboardShortcutKey, "2")
        XCTAssertEqual(RedwingMainTab.people.keyboardShortcutKey, "3")
    }

    private func render<Content: View>(_ hostingView: NSHostingView<Content>) async {
        await Task.yield()
        hostingView.layoutSubtreeIfNeeded()
    }
}
