import Foundation

struct SpaceRowViewModel: Identifiable, Equatable {
    let id: String
    let title: String
    let teamLabel: String
    let typeLabel: String
    let createdLabel: String
    let lastActivityLabel: String
    let iconURL: URL?
    let isSkeleton: Bool

    static func skeleton(id: Int) -> SpaceRowViewModel {
        SpaceRowViewModel(
            id: "space-skeleton-\(id)",
            title: "",
            teamLabel: "",
            typeLabel: "",
            createdLabel: "",
            lastActivityLabel: "",
            iconURL: nil,
            isSkeleton: true
        )
    }
}
