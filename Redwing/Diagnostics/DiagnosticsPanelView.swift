import SwiftUI

struct DiagnosticsPanelView: View {
    @ObservedObject var diagnostics: DiagnosticsStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Diagnostics")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    diagnostics.clear()
                }
                .disabled(diagnostics.entries.isEmpty)
            }
            .padding()

            Divider()

            if diagnostics.entries.isEmpty {
                ContentUnavailableView("No Diagnostics", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(diagnostics.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.source.rawValue.capitalized)
                            Text(entry.severity.rawValue.capitalized)
                                .foregroundStyle(entry.severity.foregroundStyle)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(entry.message)
                            .textSelection(.enabled)

                        if let detail = entry.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

private extension DiagnosticsStore.Severity {
    var foregroundStyle: Color {
        switch self {
        case .info:
            return .secondary
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}
