import Foundation

struct LaneLayoutModel: Equatable {
    enum LaneID: Equatable {
        case spaces
        case messages
        case thread
    }

    struct Lane: Equatable {
        let id: LaneID
        let minWidth: CGFloat
        let preferredWeight: CGFloat
    }

    let threadVisible: Bool
    let focusedLane: LaneID

    var visibleLanes: [Lane] {
        var lanes = [
            lane(for: .spaces),
            lane(for: .messages),
        ]

        if threadVisible {
            lanes.append(lane(for: .thread))
        }

        return lanes
    }

    func width(for laneID: LaneID, totalWidth: CGFloat) -> CGFloat {
        guard let lane = visibleLanes.first(where: { $0.id == laneID }) else {
            return 0
        }

        let minimumWidth = visibleLanes.reduce(0) { $0 + $1.minWidth }
        guard totalWidth > minimumWidth else {
            return lane.minWidth
        }

        let totalWeight = visibleLanes.reduce(0) { $0 + $1.preferredWeight }
        guard totalWeight > 0 else {
            return lane.minWidth
        }

        let extraWidth = totalWidth - minimumWidth
        return lane.minWidth + extraWidth * (lane.preferredWeight / totalWeight)
    }

    private func lane(for id: LaneID) -> Lane {
        Lane(
            id: id,
            minWidth: minWidth(for: id),
            preferredWeight: preferredWeight(for: id)
        )
    }

    private func minWidth(for id: LaneID) -> CGFloat {
        switch id {
        case .spaces:
            return 180
        case .messages:
            return 260
        case .thread:
            return 240
        }
    }

    private func preferredWeight(for id: LaneID) -> CGFloat {
        switch id {
        case .spaces:
            return focusedLane == .spaces ? 1.35 : 0.75
        case .messages:
            return focusedLane == .messages ? 1.60 : 1.0
        case .thread:
            return focusedLane == .thread ? 1.45 : 0.9
        }
    }
}
