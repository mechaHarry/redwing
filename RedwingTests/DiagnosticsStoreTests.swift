import XCTest
@testable import Redwing

@MainActor
final class DiagnosticsStoreTests: XCTestCase {
    func testAppendRedactsSecretsAndKeepsEntriesInMemory() {
        let store = DiagnosticsStore(now: { Date(timeIntervalSince1970: 10) })

        store.append(
            source: .auth,
            severity: .error,
            message: "Token failed",
            detail: "Bearer abc client_secret=def websocket=wss://example.test/socket"
        )

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].timestamp, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(store.entries[0].source, .auth)
        XCTAssertEqual(store.entries[0].severity, .error)
        XCTAssertFalse(store.entries[0].detail?.contains("abc") ?? true)
        XCTAssertFalse(store.entries[0].detail?.contains("def") ?? true)
        XCTAssertFalse(store.entries[0].detail?.contains("wss://example.test/socket") ?? true)
    }

    func testAppendRedactsSecretsFromMessage() {
        let store = DiagnosticsStore(now: { Date(timeIntervalSince1970: 10) })

        store.append(
            source: .auth,
            severity: .error,
            message: "Bearer abc+/= client_secret=def websocket=wss://example.test/socket"
        )

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries[0].message.contains("abc+/="))
        XCTAssertFalse(store.entries[0].message.contains("def"))
        XCTAssertFalse(store.entries[0].message.contains("wss://example.test/socket"))
    }

    func testAppendRedactsExpandedSecretFormats() {
        let store = DiagnosticsStore(now: { Date(timeIntervalSince1970: 10) })

        store.append(
            source: .auth,
            severity: .error,
            message: "Token failed",
            detail: #"Bearer abc+/= {"client_secret":"json-secret"} client_secret: colon-secret"#
        )

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries[0].detail?.contains("abc+/=") ?? true)
        XCTAssertFalse(store.entries[0].detail?.contains("json-secret") ?? true)
        XCTAssertFalse(store.entries[0].detail?.contains("colon-secret") ?? true)
    }

    func testClearRemovesSessionEntries() {
        let store = DiagnosticsStore(now: { Date(timeIntervalSince1970: 1) })
        store.append(source: .ui, severity: .info, message: "Loaded")
        XCTAssertEqual(store.entries.count, 1)

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSessionStatusIndicatorMapping() {
        XCTAssertEqual(SessionStatus.idle.indicator, .gray)
        XCTAssertEqual(SessionStatus.connected.indicator, .green)
        XCTAssertEqual(SessionStatus.refreshing.indicator, .yellow)
        XCTAssertEqual(SessionStatus.failed("no token").indicator, .red)
        XCTAssertEqual(SessionStatus.reconnecting("retry").indicator, .yellow)
    }

    func testSessionStatusLabelMapping() {
        XCTAssertEqual(SessionStatus.idle.label, "Idle")
        XCTAssertEqual(SessionStatus.connected.label, "Connected")
        XCTAssertEqual(SessionStatus.refreshing.label, "Refreshing")
        XCTAssertEqual(SessionStatus.failed("no token").label, "Failed: no token")
        XCTAssertEqual(SessionStatus.reconnecting("retry").label, "Reconnecting: retry")
    }
}
