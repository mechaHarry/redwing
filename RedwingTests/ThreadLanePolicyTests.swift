import XCTest
@testable import Redwing

final class ThreadLanePolicyTests: XCTestCase {
    func testStandaloneMessageDoesNotShowThreadLane() {
        let entry = MessageThreadEntryDTO(
            id: "m1",
            parentID: nil,
            childIDs: [],
            sender: "a@example.com",
            body: "Hello",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )

        XCTAssertFalse(ThreadLanePolicy.shouldShowThreadLane(for: entry))
    }

    func testChildOrPlaceholderShowsThreadLane() {
        let child = MessageThreadEntryDTO(
            id: "m1",
            parentID: "p1",
            childIDs: [],
            sender: "a@example.com",
            body: "Reply",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )
        let parent = MessageThreadEntryDTO(
            id: "p1",
            parentID: nil,
            childIDs: ["m1"],
            sender: "placeholder",
            body: "",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: true,
            isDeletedTombstone: false
        )

        XCTAssertTrue(ThreadLanePolicy.shouldShowThreadLane(for: child))
        XCTAssertTrue(ThreadLanePolicy.shouldShowThreadLane(for: parent))
    }

    func testDeletedTombstoneShowsThreadLane() {
        let tombstone = MessageThreadEntryDTO(
            id: "deleted",
            parentID: nil,
            childIDs: [],
            sender: "a@example.com",
            body: "",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: false,
            isDeletedTombstone: true
        )

        XCTAssertTrue(ThreadLanePolicy.shouldShowThreadLane(for: tombstone))
    }
}
