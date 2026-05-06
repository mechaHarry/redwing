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
    private var realtimeGeneration = 0

    init(clientProvider: WebexClientProviding, diagnostics: DiagnosticsStore) {
        self.clientProvider = clientProvider
        self.diagnostics = diagnostics
    }

    deinit {
        realtimeTask?.cancel()
    }

    func start() async {
        phase = .loading
        clearSessionState()
        do {
            guard let account = try await clientProvider.existingAccount() else {
                phase = .setupRequired
                return
            }
            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            await startRealtime()
        } catch {
            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Failed to load account", detail: message)
            phase = .failed("Account load failed")
            tokenStatus = .failed("Account load failed")
        }
    }

    func authorize(credentials: SetupCredentials) async {
        phase = .loading
        clearSessionState()
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
            phase = .failed("Authorization failed")
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
        cancelRealtimeTask()
        await clientProvider.signOut()
        activeAccount = nil
        phase = .setupRequired
        realtimeStatus = .idle
        tokenStatus = .idle
    }

    private func startRealtime() async {
        cancelRealtimeTask()
        realtimeStatus = .refreshing
        let states = await clientProvider.startRealtime()
        let generation = realtimeGeneration
        await withCheckedContinuation { continuation in
            realtimeTask = Task { [weak self] in
                continuation.resume()
                for await state in states {
                    self?.applyRealtimeState(state, generation: generation)
                }
            }
        }
    }

    private func cancelRealtimeTask() {
        realtimeTask?.cancel()
        realtimeTask = nil
        realtimeGeneration += 1
    }

    private func clearSessionState() {
        cancelRealtimeTask()
        activeAccount = nil
        realtimeStatus = .idle
        tokenStatus = .idle
    }

    private func applyRealtimeState(_ state: RealtimeStateDTO, generation: Int) {
        guard generation == realtimeGeneration else {
            return
        }

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
            realtimeStatus = .failed("Realtime failed")
            diagnostics.append(source: .realtime, severity: .error, message: "Realtime failed", detail: message)
        }
    }
}
