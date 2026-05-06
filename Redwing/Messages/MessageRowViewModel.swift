import Foundation

struct MessageRowViewModel: Identifiable, Equatable {
    let id: String
    let sender: String
    let body: String
    let detail: String
    let depth: Int
    let isSkeleton: Bool
    let isPlaceholderParent: Bool
    let isDeletedTombstone: Bool

    static func skeleton(id: Int) -> MessageRowViewModel {
        MessageRowViewModel(
            id: "message-skeleton-\(id)",
            sender: "",
            body: "",
            detail: "",
            depth: 0,
            isSkeleton: true,
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )
    }
}
