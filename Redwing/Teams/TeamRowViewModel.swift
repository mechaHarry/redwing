import Foundation

struct TeamRowViewModel: Identifiable, Equatable {
    let id: String
    let name: String
    let creatorLabel: String
    let createdLabel: String
    let isSkeleton: Bool

    static func skeleton(id: Int) -> TeamRowViewModel {
        TeamRowViewModel(
            id: "team-skeleton-\(id)",
            name: "Loading team",
            creatorLabel: "",
            createdLabel: "",
            isSkeleton: true
        )
    }
}
