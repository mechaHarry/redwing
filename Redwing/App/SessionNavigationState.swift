import Combine

struct IndexedScrollAnchor {
    let id: String
    let index: Int
}

@MainActor
final class SessionNavigationState: ObservableObject {
    @Published var selectedTab: RedwingMainTab = .spaces
    @Published var spacesScrollID: String?
    @Published var teamsScrollID: String?
    @Published var peopleScrollID: String?

    private var messageAnchorsBySpaceID: [String: IndexedScrollAnchor] = [:]

    func rememberMessageAnchor(spaceID: String, id: String?, index: Int?) {
        guard let id, let index else {
            return
        }

        messageAnchorsBySpaceID[spaceID] = IndexedScrollAnchor(id: id, index: index)
    }

    func restoredMessageID(spaceID: String, rowIDs: [String]) -> String? {
        guard !rowIDs.isEmpty, let anchor = messageAnchorsBySpaceID[spaceID] else {
            return nil
        }

        if rowIDs.contains(anchor.id) {
            return anchor.id
        }

        let restoredIndex = min(max(anchor.index, 0), rowIDs.count - 1)
        return rowIDs[restoredIndex]
    }
}

enum RedwingMainTab: String, CaseIterable, Identifiable {
    case spaces
    case teams
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spaces:
            "Spaces"
        case .teams:
            "Teams"
        case .people:
            "People"
        }
    }

    var systemImage: String {
        switch self {
        case .spaces:
            "bubble.left.and.bubble.right.fill"
        case .teams:
            "person.3.fill"
        case .people:
            "person.crop.circle.fill"
        }
    }
}
