import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel = AppRootModel()

    var body: some Scene {
        WindowGroup("Redwing") {
            RootPlaceholderView(model: rootModel)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Redwing", systemImage: "bolt.horizontal.circle") {
            Button("Open Redwing") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Text("Attention feed unavailable")
        }
    }
}

private struct RootPlaceholderView: View {
    @ObservedObject var model: AppRootModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 42))
            Text("Redwing")
                .font(.title)
            Text(statusText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusText: String {
        switch model.phase {
        case .setupRequired:
            return "Setup required"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .failed(let message):
            return message
        }
    }
}
