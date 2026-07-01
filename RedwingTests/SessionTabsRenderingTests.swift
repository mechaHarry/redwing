import AppKit
import SwiftUI
import XCTest
@testable import Redwing

@MainActor
final class SessionTabsRenderingTests: XCTestCase {
    func testRenderedSessionTabsRestoreClampedMessageThroughProductionAPIsWithoutAXScrolling() async throws {
        let diagnostics = DiagnosticsStore()
        let spaces = SpacesCoordinator(session: nil, diagnostics: diagnostics)
        let messages = MessagesCoordinator(session: nil, diagnostics: diagnostics)
        let teams = TeamsCoordinator(session: nil, diagnostics: diagnostics)
        let people = PeopleCoordinator(session: nil, diagnostics: diagnostics)
        let navigation = SessionNavigationState()
        let hostingView = NSHostingView(rootView: SessionTabsView(
            spaces: spaces,
            messages: messages,
            teams: teams,
            people: people,
            navigation: navigation
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1_000, height: 700)
        await render(hostingView)

        spaces.apply(snapshot: SpaceSnapshot(
            spaces: [SpaceItem(id: "space-1", title: "Space One")],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        let row = try XCTUnwrap(spaces.rows.first)
        let openSpace = SpaceOpeningAction(
            selectSpace: spaces.select(spaceID:),
            selectMessages: messages.select(spaceID:spaceTitle:)
        )
        openSpace(row)
        messages.apply(snapshot: messageSnapshot(
            ids: ["message-first", "message-anchor", "message-requested"]
        ))
        navigation.rememberMessageAnchor(
            spaceID: row.id,
            id: "message-anchor",
            index: 1
        )

        navigation.selectedTab = .teams
        await render(hostingView)
        messages.apply(snapshot: messageSnapshot(
            ids: ["message-new", "message-last"]
        ))
        messages.select(messageID: "message-new")
        let pendingRequest = try XCTUnwrap(messages.messageScrollRequest)
        navigation.selectedTab = .people
        await render(hostingView)
        navigation.selectedTab = .spaces
        await render(hostingView)

        let currentRowIDs = messages.messageRows.map(\.id)
        let restoredID = try XCTUnwrap(
            navigation.restoredMessageID(spaceID: row.id, rowIDs: currentRowIDs)
        )
        let resolution = MessageScrollArbiter.resolve(
            currentSpaceID: messages.selectedSpaceID,
            realRowIDs: currentRowIDs,
            restoredID: restoredID,
            request: messages.messageScrollRequest
        )

        XCTAssertEqual(navigation.selectedTab, .spaces)
        XCTAssertEqual(spaces.selectedSpaceID, row.id)
        XCTAssertEqual(messages.selectedSpaceID, row.id)
        XCTAssertEqual(messages.selectedSpaceTitle, row.title)
        XCTAssertEqual(currentRowIDs, ["message-new", "message-last"])
        XCTAssertEqual(restoredID, "message-last")
        XCTAssertEqual(pendingRequest.targetID, "message-new")
        XCTAssertEqual(resolution, .restore(id: "message-last", consuming: nil))
        XCTAssertNil(messages.messageScrollRequest)
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

private func messageSnapshot(ids: [String]) -> MessageThreadSnapshotDTO {
    MessageThreadSnapshotDTO(
        topLevelMessageIDs: ids,
        entriesByID: Dictionary(uniqueKeysWithValues: ids.map { id in
            (id, MessageThreadEntryDTO(
                id: id,
                parentID: nil,
                childIDs: [],
                sender: "Sender",
                body: id,
                created: nil,
                mentionedPeople: [],
                mentionedGroups: [],
                isPlaceholderParent: false,
                isDeletedTombstone: false
            ))
        }),
        isRefreshing: false,
        isLoadingNextPage: false,
        hasMore: false,
        lastErrorDescription: nil
    )
}
