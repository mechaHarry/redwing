import XCTest
import WebexSwiftSDK
@testable import Redwing

final class WebexSDKAdapterTests: XCTestCase {
    func testMapsAccountRecordUsingMetadataWhenPresent() {
        let accountID = WebexAccountID()
        let record = WebexAccountRecord(
            id: accountID,
            metadata: WebexAccountMetadata(
                webexUserID: "person-123",
                email: "alex@example.com",
                displayName: "Alex Rivera"
            )
        )

        let summary = WebexSDKAdapter.mapAccount(record, grantedScopes: ["spark:kms", "spark:all"])

        XCTAssertEqual(summary.id, "person-123")
        XCTAssertEqual(summary.displayName, "Alex Rivera")
        XCTAssertEqual(summary.grantedScopes, ["spark:kms", "spark:all"])
    }

    func testMapsAccountRecordFallbacksWithoutMetadata() {
        let accountID = WebexAccountID()
        let record = WebexAccountRecord(id: accountID, metadata: WebexAccountMetadata())

        let summary = WebexSDKAdapter.mapAccount(record)

        XCTAssertEqual(summary.id, accountID.rawValue)
        XCTAssertEqual(summary.displayName, "Webex Account")
        XCTAssertEqual(summary.grantedScopes, [])
    }

    func testMapsCurrentPersonToMentionMatchingAccountID() {
        let person = WebexPerson(
            id: "person-123",
            emails: ["alex@example.com"],
            displayName: "Alex Rivera"
        )

        let summary = WebexSDKAdapter.mapCurrentPerson(
            person,
            grantedScopes: ["spark:all", "spark:kms"]
        )

        XCTAssertEqual(summary.id, "person-123")
        XCTAssertEqual(summary.displayName, "Alex Rivera")
        XCTAssertEqual(summary.grantedScopes, ["spark:all", "spark:kms"])
    }

    func testProfileLookupFailureDoesNotUseInternalAccountIDWithoutMetadata() {
        let record = WebexAccountRecord(id: WebexAccountID(), metadata: WebexAccountMetadata())

        XCTAssertThrowsError(
            try WebexSDKAdapter.mapAccountAfterCurrentPersonLookupFailure(record)
        )
    }

    func testProfileLookupFailureCanUseStoredWebexUserID() throws {
        let record = WebexAccountRecord(
            id: WebexAccountID(),
            metadata: WebexAccountMetadata(
                webexUserID: "person-123",
                email: "alex@example.com",
                displayName: "Alex Rivera"
            )
        )

        let summary = try WebexSDKAdapter.mapAccountAfterCurrentPersonLookupFailure(
            record,
            grantedScopes: ["spark:all"]
        )

        XCTAssertEqual(summary.id, "person-123")
        XCTAssertEqual(summary.displayName, "Alex Rivera")
        XCTAssertEqual(summary.grantedScopes, ["spark:all"])
    }

    func testMapsRealtimeStates() {
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.disconnected), .disconnected)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.discovering), .connecting)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.registeringDevice), .connecting)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.connecting), .connecting)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.authorizing), .connecting)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.connected), .connected)
        XCTAssertEqual(WebexSDKAdapter.mapRealtimeState(.reconnecting(attempt: 2, delay: 1.5)), .reconnecting(attempt: 2, delay: 1.5))

        let failed = WebexSDKAdapter.mapRealtimeState(.failed(.network("token=abc client_secret=def")))
        guard case .failed(let message) = failed else {
            return XCTFail("Expected failed state")
        }
        XCTAssertFalse(message.contains("client_secret=def"))
    }

    func testMapsSpaceSnapshots() {
        let date = Date(timeIntervalSince1970: 12)
        let snapshot = WebexStreamSnapshot(
            items: [
                WebexSpace(id: "space-1", title: "General", lastActivity: date),
                WebexSpace(id: "space-2")
            ],
            revision: 1,
            lastUpdatedAt: date,
            isRefreshing: true,
            isLoadingNextPage: false,
            lastError: .rateLimited(retryAfter: 5),
            pagination: WebexStreamPagination(
                hasMore: true,
                nextPage: nil,
                pagesLoaded: 1,
                pageLimit: 3,
                capReached: false
            )
        )

        let dto = WebexSDKAdapter.mapSpaceSnapshot(snapshot)

        XCTAssertEqual(dto.spaces, [
            SpaceItem(id: "space-1", title: "General", lastActivity: date),
            SpaceItem(id: "space-2", title: "Untitled Space", lastActivity: nil)
        ])
        XCTAssertTrue(dto.isRefreshing)
        XCTAssertFalse(dto.isLoadingNextPage)
        XCTAssertTrue(dto.hasMore)
        XCTAssertEqual(dto.lastErrorDescription, "Rate limited; retry after 5.0 seconds")
    }

    func testMapsMessageThreadSnapshotFromSingleSDKThreadSnapshot() {
        let date = Date(timeIntervalSince1970: 24)
        let parent = WebexMessage(
            id: "parent",
            text: "Hello",
            personID: "person-1",
            personEmail: "alex@example.com",
            mentionedPeople: ["person-2"],
            mentionedGroups: ["all"],
            created: date
        )
        let reply = WebexMessage(
            id: "reply",
            parentID: "parent",
            markdown: "**Hi**",
            personID: "person-2",
            created: date.addingTimeInterval(1)
        )
        let snapshot = WebexMessageThreadSnapshot(
            topLevelMessageIDs: ["parent"],
            threadEntryByID: [
                "parent": WebexMessageThreadEntry(
                    id: "parent",
                    message: parent,
                    parentID: nil,
                    childIDs: ["reply"],
                    effectiveCreated: date,
                    isPlaceholderParent: false
                ),
                "reply": WebexMessageThreadEntry(
                    id: "reply",
                    message: reply,
                    parentID: "parent",
                    childIDs: [],
                    effectiveCreated: date.addingTimeInterval(1),
                    isPlaceholderParent: false
                ),
                "missing": WebexMessageThreadEntry(
                    id: "missing",
                    message: nil,
                    parentID: nil,
                    childIDs: [],
                    effectiveCreated: nil,
                    isPlaceholderParent: true
                )
            ],
            chronologicalMessageIDs: ["parent", "reply"],
            revision: 1,
            lastUpdatedAt: date,
            isRefreshing: false,
            isLoadingNextPage: true,
            lastError: nil,
            pagination: WebexStreamPagination(
                hasMore: true,
                nextPage: nil,
                pagesLoaded: 1,
                pageLimit: 2,
                capReached: false
            )
        )

        let dto = WebexSDKAdapter.mapMessageThreadSnapshot(snapshot)

        XCTAssertEqual(dto.topLevelMessageIDs, ["parent"])
        XCTAssertEqual(dto.entriesByID["parent"], MessageThreadEntryDTO(
            id: "parent",
            parentID: nil,
            childIDs: ["reply"],
            sender: "alex@example.com",
            body: "Hello",
            created: date,
            mentionedPeople: ["person-2"],
            mentionedGroups: ["all"],
            isPlaceholderParent: false,
            isDeletedTombstone: false
        ))
        XCTAssertEqual(dto.entriesByID["reply"]?.sender, "person-2")
        XCTAssertEqual(dto.entriesByID["reply"]?.body, "**Hi**")
        XCTAssertEqual(dto.entriesByID["missing"]?.isPlaceholderParent, true)
        XCTAssertTrue(dto.isLoadingNextPage)
        XCTAssertTrue(dto.hasMore)
    }

    func testRefreshTriggerFiltersByResourceAndRoomID() {
        XCTAssertTrue(WebexSDKSpacesStreamAdapter.shouldRefresh(for: WebexStreamTrigger(resource: "rooms", event: "created")))
        XCTAssertTrue(WebexSDKSpacesStreamAdapter.shouldRefresh(for: WebexStreamTrigger(resource: "messages", event: "created", roomID: "space-2")))
        XCTAssertTrue(WebexSDKSpacesStreamAdapter.shouldRefresh(for: WebexStreamTrigger(resource: "messages", event: "created")))
        XCTAssertFalse(WebexSDKSpacesStreamAdapter.shouldRefresh(for: WebexStreamTrigger(resource: "memberships", event: "created", roomID: "space-1")))

        XCTAssertTrue(WebexSDKMessagesThreadStreamAdapter.shouldRefresh(
            for: WebexStreamTrigger(resource: "messages", event: "created", roomID: "space-1"),
            spaceID: "space-1"
        ))
        XCTAssertTrue(WebexSDKMessagesThreadStreamAdapter.shouldRefresh(
            for: WebexStreamTrigger(resource: "messages", event: "created"),
            spaceID: "space-1"
        ))
        XCTAssertFalse(WebexSDKMessagesThreadStreamAdapter.shouldRefresh(
            for: WebexStreamTrigger(resource: "messages", event: "created", roomID: "space-2"),
            spaceID: "space-1"
        ))
        XCTAssertFalse(WebexSDKMessagesThreadStreamAdapter.shouldRefresh(
            for: WebexStreamTrigger(resource: "rooms", event: "updated", roomID: "space-1"),
            spaceID: "space-1"
        ))
    }
}
