import Foundation

enum StatusIndicator: Equatable {
    case green
    case yellow
    case red
    case gray
}

enum SessionStatus: Equatable {
    case idle
    case connected
    case refreshing
    case reconnecting(String)
    case failed(String)

    var indicator: StatusIndicator {
        switch self {
        case .connected:
            return .green
        case .refreshing, .reconnecting:
            return .yellow
        case .failed:
            return .red
        case .idle:
            return .gray
        }
    }

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .connected:
            return "Connected"
        case .refreshing:
            return "Refreshing"
        case .reconnecting(let reason):
            return "Reconnecting: \(reason)"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}
