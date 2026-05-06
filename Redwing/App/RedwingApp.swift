import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel = AppRootModel()
    @State private var isShowingDiagnostics = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Redwing", id: RedwingWindowID.main) {
            RedwingRootView(
                rootModel: rootModel,
                isShowingDiagnostics: $isShowingDiagnostics
            )
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentMinSize)

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
            activate: { NSApp.activate(ignoringOtherApps: true) }
        )
    }
}

enum RedwingWindowID {
    static let main = "main"
}

struct MainWindowOpeningAction {
    let openWindow: (String) -> Void
    let activate: () -> Void

    func callAsFunction() {
        openWindow(RedwingWindowID.main)
        activate()
    }
}

private struct RedwingRootView: View {
    @ObservedObject var rootModel: AppRootModel
    @Binding var isShowingDiagnostics: Bool

    var body: some View {
        Group {
            if let accountSession = rootModel.accountSession,
               let spaces = rootModel.spacesCoordinator,
               let messages = rootModel.messagesCoordinator,
               let attentionFeed = rootModel.attentionFeed {
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
            } else {
                SetupView { credentials in
                    validateSetup(credentials)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsPanelView(diagnostics: rootModel.diagnostics)
        }
    }

    private func validateSetup(_ credentials: SetupCredentials) {
        do {
            try SetupValidation.validate(credentials)
            rootModel.markSetupRequired()
            rootModel.diagnostics.append(
                source: .auth,
                severity: .info,
                message: "Setup credentials validated",
                detail: "Authorization adapter pending"
            )
        } catch {
            rootModel.markSetupRequired()
            rootModel.diagnostics.append(
                source: .auth,
                severity: .error,
                message: "Setup validation failed",
                detail: String(describing: error)
            )
        }
    }
}
