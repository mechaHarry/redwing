import XCTest
@testable import Redwing

@MainActor
final class SessionNavigationStateTests: XCTestCase {
    func testTabScrollIDsRemainIndependentAcrossSelectedTabChanges() {
        let state = SessionNavigationState()

        state.spacesScrollID = "space-2"
        state.selectedTab = .teams
        state.teamsScrollID = "team-3"
        state.selectedTab = .people
        state.peopleScrollID = "person-4"
        state.selectedTab = .spaces

        XCTAssertEqual(state.spacesScrollID, "space-2")
        XCTAssertEqual(state.teamsScrollID, "team-3")
        XCTAssertEqual(state.peopleScrollID, "person-4")
    }

    func testMessageAnchorsAreStoredIndependentlyPerSpace() {
        let state = SessionNavigationState()

        state.rememberMessageAnchor(spaceID: "space-a", id: "message-a2", index: 1)
        state.rememberMessageAnchor(spaceID: "space-b", id: "message-b3", index: 2)

        XCTAssertEqual(
            state.restoredMessageID(spaceID: "space-a", rowIDs: ["message-a1", "message-a2"]),
            "message-a2"
        )
        XCTAssertEqual(
            state.restoredMessageID(spaceID: "space-b", rowIDs: ["message-b1", "message-b2", "message-b3"]),
            "message-b3"
        )
    }

    func testRestorationUsesSavedIDWhenStillPresent() {
        let state = SessionNavigationState()
        state.rememberMessageAnchor(spaceID: "space-a", id: "message-2", index: 1)

        XCTAssertEqual(
            state.restoredMessageID(spaceID: "space-a", rowIDs: ["message-3", "message-2", "message-1"]),
            "message-2"
        )
    }

    func testRestorationClampsSavedIndexWhenSavedIDWasRemoved() {
        let state = SessionNavigationState()
        state.rememberMessageAnchor(spaceID: "space-a", id: "removed", index: 20)

        XCTAssertEqual(
            state.restoredMessageID(spaceID: "space-a", rowIDs: ["message-1", "message-2", "message-3"]),
            "message-3"
        )
    }

    func testRestorationReturnsNilForEmptyRowsOrMissingAnchor() {
        let state = SessionNavigationState()
        state.rememberMessageAnchor(spaceID: "space-a", id: "message-1", index: 0)

        XCTAssertNil(state.restoredMessageID(spaceID: "space-a", rowIDs: []))
        XCTAssertNil(state.restoredMessageID(spaceID: "space-b", rowIDs: ["message-1"]))
    }

    func testRememberMessageAnchorIgnoresMissingIDOrIndex() {
        let state = SessionNavigationState()

        state.rememberMessageAnchor(spaceID: "space-a", id: nil, index: 0)
        state.rememberMessageAnchor(spaceID: "space-b", id: "message-1", index: nil)

        XCTAssertNil(state.restoredMessageID(spaceID: "space-a", rowIDs: ["message-1"]))
        XCTAssertNil(state.restoredMessageID(spaceID: "space-b", rowIDs: ["message-1"]))
    }
}
