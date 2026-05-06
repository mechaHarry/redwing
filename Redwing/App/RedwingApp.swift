import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel = AppRootModel()
    @State private var isShowingDiagnostics = false

    var body: some Scene {
        WindowGroup("Redwing") {
            RedwingRootView(
                rootModel: rootModel,
                isShowingDiagnostics: $isShowingDiagnostics
            )
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Redwing", systemImage: "bolt.horizontal.circle") {
            if let attentionFeed = rootModel.attentionFeed {
                MenuBarView(attentionFeed: attentionFeed, openWindow: openMainWindow)
            } else {
                Button("Open Redwing") {
                    openMainWindow()
                }
                Divider()
                Text("Setup required")
            }
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
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
