import Combine
import Foundation

@MainActor
final class AttentionFeedStore: ObservableObject {
    @Published private(set) var items: [AttentionItemViewModel] = []
    @Published private(set) var status: SessionStatus = .idle

    private var currentUserID: String

    init(currentUserID: String) {
        self.currentUserID = currentUserID
    }

    func updateCurrentUserID(_ currentUserID: String) {
        guard self.currentUserID != currentUserID else {
            return
        }

        self.currentUserID = currentUserID
        items.removeAll()
    }

    func apply(snapshot: MessageThreadSnapshotDTO, spaceID: String, spaceTitle: String) {
        status = snapshot.lastErrorDescription.map { _ in SessionStatus.failed("Attention refresh failed") }
            ?? (snapshot.isRefreshing ? .refreshing : .connected)
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for entry in snapshot.entriesByID.values {
            guard !entry.isPlaceholderParent,
                  !entry.isDeletedTombstone,
                  let reason = attentionReason(for: entry)
            else {
                byID[entry.id] = nil
                continue
            }

            byID[entry.id] = AttentionItemViewModel(
                id: entry.id,
                spaceID: spaceID,
                spaceTitle: spaceTitle,
                sender: entry.sender,
                body: entry.body,
                created: entry.created,
                reason: reason
            )
        }

        items = byID.values.sorted { left, right in
            switch (left.created, right.created) {
            case (.some(let leftDate), .some(let rightDate)):
                if leftDate == rightDate { return left.id < right.id }
                return leftDate > rightDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left.id < right.id
            }
        }
    }

    private func attentionReason(for entry: MessageThreadEntryDTO) -> String? {
        if entry.mentionedPeople.contains(currentUserID) {
            return "Mentioned you"
        }
        if entry.mentionedGroups.contains(where: { $0.lowercased() == "all" }) {
            return "Mentioned all"
        }
        return nil
    }
}
