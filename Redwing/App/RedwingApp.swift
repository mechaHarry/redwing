import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @NSApplicationDelegateAdaptor(RedwingAppDelegate.self) private var appDelegate
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

final class RedwingAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        guard !sender.windows.isEmpty else {
            return true
        }

        Task { @MainActor in
            WindowFocusController.moveMainWindowToCurrentDesktop(windows: sender.windows)
        }
        return false
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
               let teams = rootModel.teamsCoordinator,
               let people = rootModel.peopleCoordinator,
               let attentionFeed = rootModel.attentionFeed {
                RedwingSessionView(
                    accountSession: accountSession,
                    spaces: spaces,
                    messages: messages,
                    teams: teams,
                    people: people,
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
                await rootModel.teamsCoordinator?.start()
                await rootModel.peopleCoordinator?.start()
            }
        }
    }
}

struct SessionSidebarView: View {
    @Binding var selection: RedwingMainTab

    var body: some View {
        let sidebarShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        GlassEffectContainer {
            VStack(spacing: 10) {
                ForEach(RedwingMainTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == tab ? .primary : .secondary)
                    .background {
                        if selection == tab {
                            Circle()
                                .fill(.regularMaterial)
                        }
                    }
                    .help(tab.title)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    .keyboardShortcut(KeyEquivalent(tab.keyboardShortcutKey), modifiers: .command)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .frame(width: 68)
            .glassEffect(.regular, in: sidebarShape)
        }
        .padding(.leading, 16)
        .padding(.vertical, 20)
    }
}

struct SessionTabsView: View {
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var teams: TeamsCoordinator
    @ObservedObject var people: PeopleCoordinator
    @ObservedObject var navigation: SessionNavigationState

    var body: some View {
        HStack(spacing: 0) {
            SessionSidebarView(selection: $navigation.selectedTab)

            Group {
                switch navigation.selectedTab {
                case .spaces:
                    SpacesMessagesSurface(
                        spaces: spaces,
                        messages: messages,
                        navigation: navigation
                    )
                case .teams:
                    TeamsLaneSurfaceView(
                        teams: teams,
                        scrollAnchorID: $navigation.teamsScrollID
                    )
                case .people:
                    PeopleHierarchyView(
                        people: people,
                        scrollAnchorID: $navigation.peopleScrollID
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
            .animation(.easeInOut(duration: 0.2), value: navigation.selectedTab)
        }
    }
}

extension RedwingMainTab {
    var keyboardShortcutKey: Character {
        switch self {
        case .spaces:
            "1"
        case .teams:
            "2"
        case .people:
            "3"
        }
    }
}

private struct RedwingSessionView: View {
    @ObservedObject var accountSession: AccountSession
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var teams: TeamsCoordinator
    @ObservedObject var people: PeopleCoordinator
    @ObservedObject var attentionFeed: AttentionFeedStore
    @Binding var isShowingDiagnostics: Bool
    @StateObject private var navigation = SessionNavigationState()

    var body: some View {
        Group {
            switch accountSession.phase {
            case .idle, .loading, .ready:
                VStack(spacing: 0) {
                    SessionTabsView(
                        spaces: spaces,
                        messages: messages,
                        teams: teams,
                        people: people,
                        navigation: navigation
                    )

                    Divider()

                    StatusBarView(
                        accountSession: accountSession,
                        spaces: spaces,
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
            await teams.start()
            await people.start()
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
                await teams.start()
                await people.start()
            }
        }
    }
}
