import Foundation

struct SpaceRowViewModel: Identifiable, Equatable {
    let id: String
    let title: String
    let teamLabel: String
    let iconURL: URL?
    let isSkeleton: Bool

    static func skeleton(id: Int) -> SpaceRowViewModel {
        SpaceRowViewModel(
            id: "space-skeleton-\(id)",
            title: "",
            teamLabel: "",
            iconURL: nil,
            isSkeleton: true
        )
    }
}
