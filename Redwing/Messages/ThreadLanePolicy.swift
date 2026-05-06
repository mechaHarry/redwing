import Foundation

enum ThreadLanePolicy {
    static func shouldShowThreadLane(for entry: MessageThreadEntryDTO) -> Bool {
        entry.parentID != nil ||
            !entry.childIDs.isEmpty ||
            entry.isPlaceholderParent ||
            entry.isDeletedTombstone
    }
}
