import Combine
import Foundation

@MainActor
final class AccountSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case setupRequired
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activeAccount: WebexAccountSummary?
    @Published private(set) var realtimeStatus: SessionStatus = .idle
    @Published private(set) var tokenStatus: SessionStatus = .idle

    private let clientProvider: WebexClientProviding
    private let diagnostics: DiagnosticsStore
    private var realtimeTask: Task<Void, Never>?

    init(clientProvider: WebexClientProviding, diagnostics: DiagnosticsStore) {
        self.clientProvider = clientProvider
        self.diagnostics = diagnostics
    }

    deinit {
        realtimeTask?.cancel()
    }

    func start() async {
        phase = .loading
        do {
            guard let account = try await clientProvider.existingAccount() else {
                phase = .setupRequired
                tokenStatus = .idle
                return
            }
            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            await startRealtime()
        } catch {
            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Failed to load account", detail: message)
            phase = .failed(message)
            tokenStatus = .failed("Account load failed")
        }
    }

    func authorize(credentials: SetupCredentials) async {
        phase = .loading
        do {
            try SetupValidation.validate(credentials)
            let account = try await clientProvider.authorize(credentials: credentials)
            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            diagnostics.append(source: .auth, severity: .info, message: "Authorized Webex account")
            await startRealtime()
        } catch {
            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Authorization failed", detail: message)
            phase = .failed(message)
            tokenStatus = .failed("Authorization failed")
        }
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        try await clientProvider.makeSpacesStream()
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        try await clientProvider.makeMessagesThreadStream(spaceID: spaceID)
    }

    func signOut() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        await clientProvider.signOut()
        activeAccount = nil
        phase = .setupRequired
        realtimeStatus = .idle
        tokenStatus = .idle
    }

    private func startRealtime() async {
        realtimeTask?.cancel()
        realtimeStatus = .refreshing
        let states = await clientProvider.startRealtime()
        await withCheckedContinuation { continuation in
            realtimeTask = Task { [weak self] in
                continuation.resume()
                for await state in states {
                    self?.applyRealtimeState(state)
                }
            }
        }
    }

    private func applyRealtimeState(_ state: RealtimeStateDTO) {
        switch state {
        case .disconnected:
            realtimeStatus = .idle
        case .connecting:
            realtimeStatus = .refreshing
        case .connected:
            realtimeStatus = .connected
        case .reconnecting(let attempt, let delay):
            realtimeStatus = .reconnecting("attempt \(attempt), \(String(format: "%.1f", delay))s")
        case .failed(let message):
            realtimeStatus = .failed(message)
            diagnostics.append(source: .realtime, severity: .error, message: "Realtime failed", detail: message)
        }
    }
}
