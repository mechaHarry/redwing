import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel: AppRootModel = {
        let model = AppRootModel()
        model.configure(clientProvider: WebexSDKAdapter(), currentUserID: "")
        return model
    }()
    @State private var isShowingDiagnostics = false
    @State private var mainWindowFocusRequestID = 0
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Redwing", id: RedwingWindowID.main) {
            RedwingRootView(
                rootModel: rootModel,
                isShowingDiagnostics: $isShowingDiagnostics,
                mainWindowFocusRequestID: mainWindowFocusRequestID
            )
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)

        MenuBarExtra("Redwing", systemImage: "bolt.horizontal.circle") {
            if let attentionFeed = rootModel.attentionFeed {
                MenuBarView(attentionFeed: attentionFeed, openWindow: openMainWindow.callAsFunction)
            } else {
                Button("Open Redwing") {
                    openMainWindow()
                }
                Divider()
                Text("Setup required")
            }
        }
    }

    private var openMainWindow: MainWindowOpeningAction {
        MainWindowOpeningAction(
            openWindow: { openWindow(id: $0) },
            requestFocus: { mainWindowFocusRequestID += 1 },
            activate: { NSApp.activate(ignoringOtherApps: true) }
        )
    }
}

enum RedwingWindowID {
    static let main = "main"
}

struct MainWindowOpeningAction {
    let openWindow: (String) -> Void
    let requestFocus: () -> Void
    let activate: () -> Void

    func callAsFunction() {
        openWindow(RedwingWindowID.main)
        requestFocus()
        activate()
    }
}

private struct RedwingRootView: View {
    @ObservedObject var rootModel: AppRootModel
    @Binding var isShowingDiagnostics: Bool
    let mainWindowFocusRequestID: Int

    var body: some View {
        Group {
            if let accountSession = rootModel.accountSession,
               let spaces = rootModel.spacesCoordinator,
               let messages = rootModel.messagesCoordinator,
               let attentionFeed = rootModel.attentionFeed {
                RedwingSessionView(
                    accountSession: accountSession,
                    spaces: spaces,
                    messages: messages,
                    attentionFeed: attentionFeed,
                    isShowingDiagnostics: $isShowingDiagnostics
                )
            } else {
                SetupView { credentials in
                    authorize(credentials)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(WindowFocusAttachment(requestID: mainWindowFocusRequestID))
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsPanelView(diagnostics: rootModel.diagnostics)
        }
    }

    private func authorize(_ credentials: SetupCredentials) {
        Task {
            guard let accountSession = rootModel.accountSession else {
                return
            }

            await accountSession.authorize(credentials: credentials)
            if accountSession.phase == .ready {
                if let currentUserID = accountSession.activeAccount?.id {
                    rootModel.updateCurrentUserID(currentUserID)
                }
                await rootModel.spacesCoordinator?.start()
            }
        }
    }
}

private struct RedwingSessionView: View {
    @ObservedObject var accountSession: AccountSession
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var attentionFeed: AttentionFeedStore
    @Binding var isShowingDiagnostics: Bool

    var body: some View {
        Group {
            switch accountSession.phase {
            case .idle, .loading, .ready:
                VStack(spacing: 0) {
                    LaneSurfaceView(spaces: spaces, messages: messages)

                    Divider()

                    StatusBarView(
                        accountSession: accountSession,
                        spaces: spaces,
                        messages: messages,
                        attentionFeed: attentionFeed
                    ) {
                        isShowingDiagnostics = true
                    }
                }
            case .setupRequired, .failed:
                SetupView { credentials in
                    authorize(credentials)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await start()
        }
    }

    private func start() async {
        guard accountSession.phase == .idle else {
            return
        }

        await accountSession.start()
        if accountSession.phase == .ready {
            if let currentUserID = accountSession.activeAccount?.id {
                attentionFeed.updateCurrentUserID(currentUserID)
            }
            await spaces.start()
        }
    }

    private func authorize(_ credentials: SetupCredentials) {
        Task {
            await accountSession.authorize(credentials: credentials)
            if accountSession.phase == .ready {
                if let currentUserID = accountSession.activeAccount?.id {
                    attentionFeed.updateCurrentUserID(currentUserID)
                }
                await spaces.start()
            }
        }
    }
}
