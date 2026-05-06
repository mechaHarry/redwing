import Foundation

@MainActor
final class AppRootModel: ObservableObject {
    enum Phase: Equatable {
        case setupRequired
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .setupRequired

    func markLoading() {
        phase = .loading
    }

    func markReady() {
        phase = .ready
    }

    func markFailed(_ message: String) {
        phase = .failed(message)
    }
}
