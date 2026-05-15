import Foundation

struct PersonNodeViewModel: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String?
    let avatarState: SpaceAvatarState
    let isSkeleton: Bool

    static func skeleton(id: Int) -> PersonNodeViewModel {
        PersonNodeViewModel(
            id: "person-skeleton-\(id)",
            name: "Loading person",
            subtitle: nil,
            avatarState: .directPlaceholder,
            isSkeleton: true
        )
    }
}
