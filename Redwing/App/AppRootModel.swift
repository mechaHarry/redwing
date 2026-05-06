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
    @Published private(set) var accountSession: AccountSession?
    @Published private(set) var spacesCoordinator: SpacesCoordinator?
    @Published private(set) var messagesCoordinator: MessagesCoordinator?
    @Published private(set) var attentionFeed: AttentionFeedStore?

    let diagnostics: DiagnosticsStore

    init(diagnostics: DiagnosticsStore? = nil) {
        self.diagnostics = diagnostics ?? DiagnosticsStore()
    }

    func markLoading() {
        phase = .loading
    }

    func markReady() {
        phase = .ready
    }

    func markFailed(_ message: String) {
        phase = .failed(message)
    }

    func markSetupRequired() {
        phase = .setupRequired
    }

    func configure(clientProvider: WebexClientProviding, currentUserID: String) {
        let session = AccountSession(clientProvider: clientProvider, diagnostics: diagnostics)
        accountSession = session
        spacesCoordinator = SpacesCoordinator(session: session, diagnostics: diagnostics)
        messagesCoordinator = MessagesCoordinator(session: session, diagnostics: diagnostics)
        attentionFeed = AttentionFeedStore(currentUserID: currentUserID)
    }

    func updateCurrentUserID(_ currentUserID: String) {
        attentionFeed?.updateCurrentUserID(currentUserID)
    }
}
