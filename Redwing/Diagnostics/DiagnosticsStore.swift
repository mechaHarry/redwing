import Combine
import Foundation

@MainActor
final class DiagnosticsStore: ObservableObject {
    enum Source: String, Equatable {
        case app
        case auth
        case realtime
        case spaces
        case messages
        case attention
        case ui
    }

    enum Severity: String, Equatable {
        case info
        case warning
        case error
    }

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let timestamp: Date
        let source: Source
        let severity: Severity
        let message: String
        let detail: String?
    }

    @Published private(set) var entries: [Entry] = []

    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    func append(
        source: Source,
        severity: Severity,
        message: String,
        detail: String? = nil
    ) {
        entries.append(Entry(
            id: UUID(),
            timestamp: now(),
            source: source,
            severity: severity,
            message: message,
            detail: detail.map(Self.redacted)
        ))
    }

    func clear() {
        entries.removeAll()
    }

    private static func redacted(_ value: String) -> String {
        var output = value
        output = output.replacingOccurrences(
            of: #"Bearer\s+[A-Za-z0-9._\-]+"#,
            with: "Bearer <redacted>",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"client_secret=([^&\s]+)"#,
            with: "client_secret=<redacted>",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"wss://[^\s]+"#,
            with: "wss://<redacted>",
            options: .regularExpression
        )
        return output
    }
}
