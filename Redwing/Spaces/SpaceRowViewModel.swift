import Foundation

enum SpaceAvatarState: Equatable, Hashable {
    case remote(URL)
    case loading
    case directPlaceholder
    case groupPlaceholder
}

struct SpaceRowViewModel: Identifiable, Equatable {
    let id: String
    let title: String
    let teamLabel: String?
    let createdLabel: String
    let lastActivityLabel: String
    let avatarState: SpaceAvatarState
    let isSkeleton: Bool

    static func skeleton(id: Int) -> SpaceRowViewModel {
        SpaceRowViewModel(
            id: "space-skeleton-\(id)",
            title: "",
            teamLabel: nil,
            createdLabel: "",
            lastActivityLabel: "",
            avatarState: .groupPlaceholder,
            isSkeleton: true
        )
    }
}
