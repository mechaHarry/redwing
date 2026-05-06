import Foundation

struct SpaceRowViewModel: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isSkeleton: Bool

    static func skeleton(id: Int) -> SpaceRowViewModel {
        SpaceRowViewModel(id: "space-skeleton-\(id)", title: "", detail: "", isSkeleton: true)
    }
}
