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
    private var sessionGeneration = 0

    init(clientProvider: WebexClientProviding, diagnostics: DiagnosticsStore) {
        self.clientProvider = clientProvider
        self.diagnostics = diagnostics
    }

    deinit {
        realtimeTask?.cancel()
    }

    func start() async {
        phase = .loading
        let generation = clearSessionState()
        do {
            guard let account = try await clientProvider.existingAccount() else {
                guard isCurrent(generation) else {
                    return
                }
                phase = .setupRequired
                return
            }

            guard isCurrent(generation) else {
                return
            }

            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            await startRealtime(generation: generation)
        } catch {
            guard isCurrent(generation) else {
                return
            }

            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Failed to load account", detail: message)
            phase = .failed("Account load failed")
            tokenStatus = .failed("Account load failed")
        }
    }

    func authorize(credentials: SetupCredentials) async {
        phase = .loading
        let generation = clearSessionState()
        do {
            try SetupValidation.validate(credentials)
            let account = try await clientProvider.authorize(credentials: credentials)
            guard isCurrent(generation) else {
                return
            }

            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            diagnostics.append(source: .auth, severity: .info, message: "Authorized Webex account")
            await startRealtime(generation: generation)
        } catch {
            guard isCurrent(generation) else {
                return
            }

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
        let previousAccount = activeAccount
        let generation = clearSessionState()
        do {
            try await clientProvider.signOut()
            guard isCurrent(generation) else {
                return
            }

            phase = .setupRequired
        } catch {
            guard isCurrent(generation) else {
                return
            }

            let message = String(describing: error)
            activeAccount = previousAccount
            phase = .failed("Sign out failed")
            tokenStatus = .failed("Sign out failed")
            diagnostics.append(source: .auth, severity: .error, message: "Sign out failed", detail: message)
        }
    }

    private func startRealtime(generation: Int) async {
        guard isCurrent(generation) else {
            return
        }

        cancelRealtimeTask()
        realtimeStatus = .refreshing
        let states = await clientProvider.startRealtime()
        guard isCurrent(generation) else {
            return
        }

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
    }

    private func clearSessionState() -> Int {
        cancelRealtimeTask()
        sessionGeneration += 1
        activeAccount = nil
        realtimeStatus = .idle
        tokenStatus = .idle
        return sessionGeneration
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == sessionGeneration
    }

    private func applyRealtimeState(_ state: RealtimeStateDTO, generation: Int) {
        guard isCurrent(generation) else {
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
