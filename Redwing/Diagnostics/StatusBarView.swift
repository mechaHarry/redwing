import SwiftUI

struct StatusBarView: View {
    @ObservedObject var accountSession: AccountSession
    @ObservedObject var spaces: SpacesCoordinator

    let onShowDiagnostics: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            StatusItemView(title: "WebSocket", status: accountSession.realtimeStatus)
            StatusItemView(title: "Token", status: accountSession.tokenStatus)
            StatusItemView(title: "Spaces", status: spaces.status)

            Spacer()

            Button("Diagnostics") {
                onShowDiagnostics()
            }
            .controlSize(.small)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}

private struct StatusItemView: View {
    let title: String
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.indicator.color)
                .frame(width: 7, height: 7)
            Text(title)
                .lineLimit(1)
        }
        .help("\(title): \(status.label)")
    }
}

private extension StatusIndicator {
    var color: Color {
        switch self {
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        case .gray:
            return .secondary
        }
    }
}
