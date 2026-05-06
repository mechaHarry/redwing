import XCTest
@testable import Redwing

@MainActor
final class SmokeTests: XCTestCase {
    func testAppRootModelTransitions() {
        let model = AppRootModel()
        XCTAssertEqual(model.phase, .setupRequired)

        model.markLoading()
        XCTAssertEqual(model.phase, .loading)

        model.markReady()
        XCTAssertEqual(model.phase, .ready)

        model.markFailed("broken")
        XCTAssertEqual(model.phase, .failed("broken"))

        model.markSetupRequired()
        XCTAssertEqual(model.phase, .setupRequired)
    }

    func testConfigureCreatesSessionCoordinatorsAndAttentionFeed() {
        let diagnostics = DiagnosticsStore()
        let model = AppRootModel(diagnostics: diagnostics)
        let clientProvider = FakeWebexClientProviding()

        model.configure(clientProvider: clientProvider, currentUserID: "person-123")

        XCTAssertNotNil(model.accountSession)
        XCTAssertNotNil(model.spacesCoordinator)
        XCTAssertNotNil(model.messagesCoordinator)
        XCTAssertNotNil(model.attentionFeed)
    }

    func testConfiguredAttentionFeedUsesSuppliedCurrentUserID() throws {
        let model = AppRootModel()
        model.configure(clientProvider: FakeWebexClientProviding(), currentUserID: "person-123")

        let attentionFeed = try XCTUnwrap(model.attentionFeed)
        attentionFeed.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["mention"],
            entriesByID: [
                "mention": MessageThreadEntryDTO(
                    id: "mention",
                    parentID: nil,
                    childIDs: [],
                    sender: "alex@example.com",
                    body: "Can you review this?",
                    created: Date(timeIntervalSince1970: 10),
                    mentionedPeople: ["person-123"],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                )
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(attentionFeed.items.map(\.id), ["mention"])
    }

    func testMainWindowOpeningActionOpensConfiguredWindowIDAndActivatesApp() {
        var openedWindowID: String?
        var activationCount = 0
        let action = MainWindowOpeningAction(
            openWindow: { openedWindowID = $0 },
            activate: { activationCount += 1 }
        )

        action()

        XCTAssertEqual(openedWindowID, RedwingWindowID.main)
        XCTAssertEqual(activationCount, 1)
    }
}
