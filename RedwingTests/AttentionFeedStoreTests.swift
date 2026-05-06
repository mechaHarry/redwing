import XCTest
@testable import Redwing

@MainActor
final class AttentionFeedStoreTests: XCTestCase {
    func testIncludesDirectMentionsAndAllGroupMentionsOnly() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["direct", "all", "plain"],
            entriesByID: [
                "direct": entry(id: "direct", mentionedPeople: ["me"], mentionedGroups: []),
                "all": entry(id: "all", created: Date(timeIntervalSince1970: 2), mentionedPeople: [], mentionedGroups: ["all"]),
                "plain": entry(id: "plain", mentionedPeople: [], mentionedGroups: [])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["all", "direct"])
    }

    func testDedupesByMessageIDAcrossRefreshes() {
        let store = AttentionFeedStore(currentUserID: "me")
        let snapshot = MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["m1"],
            entriesByID: ["m1": entry(id: "m1", mentionedPeople: ["me"], mentionedGroups: [])],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        )

        store.apply(snapshot: snapshot, spaceID: "space-1", spaceTitle: "General")
        store.apply(snapshot: snapshot, spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.count, 1)
    }

    func testRemovesItemWhenSameMessageBecomesIneligibleInLaterSnapshot() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["m1", "retained"],
            entriesByID: [
                "m1": entry(id: "m1", created: Date(timeIntervalSince1970: 2), mentionedPeople: ["me"]),
                "retained": entry(id: "retained", created: Date(timeIntervalSince1970: 1), mentionedPeople: ["me"])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")
        XCTAssertEqual(store.items.map(\.id), ["m1", "retained"])

        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["m1"],
            entriesByID: ["m1": entry(id: "m1", created: Date(timeIntervalSince1970: 3), mentionedPeople: [])],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["retained"])
    }

    func testChangingCurrentUserIDClearsStaleItemsAndUsesNewID() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["old"],
            entriesByID: ["old": entry(id: "old", mentionedPeople: ["me"])],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["old"])

        store.updateCurrentUserID("person-123")

        XCTAssertTrue(store.items.isEmpty)

        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["old", "new"],
            entriesByID: [
                "old": entry(id: "old", created: Date(timeIntervalSince1970: 2), mentionedPeople: ["me"]),
                "new": entry(id: "new", created: Date(timeIntervalSince1970: 1), mentionedPeople: ["person-123"])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["new"])
    }

    func testExcludesPlaceholderParentsAndDeletedTombstonesEvenWhenMentioned() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["placeholder", "deleted", "live"],
            entriesByID: [
                "placeholder": entry(id: "placeholder", mentionedPeople: ["me"], isPlaceholderParent: true),
                "deleted": entry(id: "deleted", mentionedGroups: ["all"], isDeletedTombstone: true),
                "live": entry(id: "live", mentionedPeople: ["me"])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["live"])
    }

    func testSnapshotErrorPublishesGenericStatus() {
        let store = AttentionFeedStore(currentUserID: "me")

        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: [],
            entriesByID: [:],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: "Bearer secret-token client_secret=super-secret"
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.status, .failed("Attention refresh failed"))
        XCTAssertEqual(store.status.label, "Failed: Attention refresh failed")
    }

    func testRefreshingSnapshotPublishesRefreshingStatus() {
        let store = AttentionFeedStore(currentUserID: "me")

        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: [],
            entriesByID: [:],
            isRefreshing: true,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.status, .refreshing)
        XCTAssertEqual(store.status.label, "Refreshing")
    }

    func testSortsNewestFirstWithIDTieBreaksAndNilDatesLast() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["nil", "new-b", "old", "new-a"],
            entriesByID: [
                "nil": entry(id: "nil", created: nil, mentionedPeople: ["me"]),
                "new-b": entry(id: "new-b", created: Date(timeIntervalSince1970: 3), mentionedPeople: ["me"]),
                "old": entry(id: "old", created: Date(timeIntervalSince1970: 1), mentionedPeople: ["me"]),
                "new-a": entry(id: "new-a", created: Date(timeIntervalSince1970: 3), mentionedPeople: ["me"])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["new-a", "new-b", "old", "nil"])
    }

    private func entry(
        id: String,
        created: Date? = Date(timeIntervalSince1970: 1),
        mentionedPeople: [String] = [],
        mentionedGroups: [String] = [],
        isPlaceholderParent: Bool = false,
        isDeletedTombstone: Bool = false
    ) -> MessageThreadEntryDTO {
        MessageThreadEntryDTO(
            id: id,
            parentID: nil,
            childIDs: [],
            sender: "a@example.com",
            body: id,
            created: created,
            mentionedPeople: mentionedPeople,
            mentionedGroups: mentionedGroups,
            isPlaceholderParent: isPlaceholderParent,
            isDeletedTombstone: isDeletedTombstone
        )
    }
}
