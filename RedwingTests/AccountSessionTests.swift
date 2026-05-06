import XCTest
@testable import Redwing

@MainActor
final class AccountSessionTests: XCTestCase {
    func testLoadExistingAccountStartsRealtime() async throws {
        let fake = FakeWebexClientProviding()
        fake.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let diagnostics = DiagnosticsStore()
        let session = AccountSession(clientProvider: fake, diagnostics: diagnostics)

        await session.start()

        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.activeAccount?.id, "a1")
        XCTAssertTrue(fake.didStartRealtime)
    }

    func testMissingAccountRequiresSetup() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())

        await session.start()

        XCTAssertEqual(session.phase, .setupRequired)
        XCTAssertNil(session.activeAccount)
    }

    func testRealtimeStateUpdatesStatus() async throws {
        let fake = FakeWebexClientProviding()
        fake.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())

        await session.start()
        fake.realtimeProbe.yield(.connected)
        await Task.yield()

        XCTAssertEqual(session.realtimeStatus, .connected)
    }

    func testSignOutCancelsSessionState() async {
        let fake = FakeWebexClientProviding()
        fake.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())

        await session.start()
        await session.signOut()

        XCTAssertTrue(fake.didSignOut)
        XCTAssertEqual(session.phase, .setupRequired)
        XCTAssertNil(session.activeAccount)
    }

    func testReloadMissingAccountClearsActiveAccountAndIgnoresOldRealtimeEvents() async {
        let fake = FakeWebexClientProviding()
        fake.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())

        await session.start()
        fake.account = nil
        await session.start()
        fake.realtimeProbe.yield(.connected)
        await Task.yield()

        XCTAssertEqual(session.phase, .setupRequired)
        XCTAssertNil(session.activeAccount)
        XCTAssertEqual(session.realtimeStatus, .idle)
        XCTAssertEqual(session.tokenStatus, .idle)
    }

    func testAuthorizationValidationFailureDoesNotCallProviderAndPublishesGenericFailure() async {
        let spy = SpyWebexClientProviding()
        let diagnostics = DiagnosticsStore()
        let session = AccountSession(clientProvider: spy, diagnostics: diagnostics)
        let credentials = SetupCredentials(
            clientID: "",
            clientSecret: "submitted-client-secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )

        await session.authorize(credentials: credentials)

        XCTAssertEqual(spy.authorizeCount, 0)
        XCTAssertEqual(spy.startRealtimeCount, 0)
        XCTAssertEqual(session.phase, .failed("Authorization failed"))
        XCTAssertEqual(session.tokenStatus, .failed("Authorization failed"))
        XCTAssertNil(session.activeAccount)
    }

    func testProviderAuthorizationFailurePublishesGenericStateAndRedactsDiagnostics() async {
        let spy = SpyWebexClientProviding()
        spy.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let diagnostics = DiagnosticsStore()
        let session = AccountSession(clientProvider: spy, diagnostics: diagnostics)

        await session.start()
        spy.authorizeResult = .failure(SecretError("Bearer abc client_secret=def wss://example.test/socket"))
        await session.authorize(credentials: validCredentials())

        XCTAssertEqual(session.phase, .failed("Authorization failed"))
        XCTAssertEqual(session.tokenStatus, .failed("Authorization failed"))
        XCTAssertNil(session.activeAccount)
        XCTAssertFalse(String(describing: session.phase).contains("abc"))
        XCTAssertFalse(session.tokenStatus.label.contains("def"))
        XCTAssertEqual(diagnostics.entries.last?.message, "Authorization failed")
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("abc") ?? true)
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("def") ?? true)
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("example.test") ?? true)
    }

    func testRealtimeFailurePublishesGenericStateAndRedactsDiagnostics() async {
        let fake = FakeWebexClientProviding()
        fake.account = WebexAccountSummary(id: "a1", displayName: "User", grantedScopes: ["spark:all", "spark:kms"])
        let diagnostics = DiagnosticsStore()
        let session = AccountSession(clientProvider: fake, diagnostics: diagnostics)

        await session.start()
        fake.realtimeProbe.yield(.failed("Bearer abc client_secret=def wss://example.test/socket"))
        await Task.yield()

        XCTAssertEqual(session.realtimeStatus, .failed("Realtime failed"))
        XCTAssertFalse(session.realtimeStatus.label.contains("abc"))
        XCTAssertFalse(session.realtimeStatus.label.contains("def"))
        XCTAssertEqual(diagnostics.entries.last?.message, "Realtime failed")
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("abc") ?? true)
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("def") ?? true)
        XCTAssertFalse(diagnostics.entries.last?.detail?.contains("example.test") ?? true)
    }

    private func validCredentials() -> SetupCredentials {
        SetupCredentials(
            clientID: "client-id",
            clientSecret: "client-secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )
    }
}

private struct SecretError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private struct SpyWebexClientState {
    var account: WebexAccountSummary?
    var authorizeResult: Result<WebexAccountSummary, Error>?
    var authorizeCount = 0
    var startRealtimeCount = 0
    var didSignOut = false
}

private final class TestLockIsolated<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

private final class SpyWebexClientProviding: WebexClientProviding, @unchecked Sendable {
    let realtimeProbe = StreamProbe<RealtimeStateDTO>()
    private let state = TestLockIsolated(SpyWebexClientState())

    var account: WebexAccountSummary? {
        get { state.withValue { $0.account } }
        set { state.withValue { $0.account = newValue } }
    }

    var authorizeResult: Result<WebexAccountSummary, Error>? {
        get { state.withValue { $0.authorizeResult } }
        set { state.withValue { $0.authorizeResult = newValue } }
    }

    var authorizeCount: Int {
        state.withValue { $0.authorizeCount }
    }

    var startRealtimeCount: Int {
        state.withValue { $0.startRealtimeCount }
    }

    func existingAccount() async throws -> WebexAccountSummary? {
        account
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        try state.withValue { state in
            state.authorizeCount += 1
            switch state.authorizeResult {
            case .success(let account):
                state.account = account
                return account
            case .failure(let error):
                throw error
            case nil:
                let account = WebexAccountSummary(id: "account-1", displayName: "Test User", grantedScopes: credentials.scopes)
                state.account = account
                return account
            }
        }
    }

    func startRealtime() async -> AsyncStream<RealtimeStateDTO> {
        state.withValue { $0.startRealtimeCount += 1 }
        return realtimeProbe.stream
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        FakeSpacesStream()
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        FakeMessagesThreadStream()
    }

    func signOut() async {
        state.withValue { $0.didSignOut = true }
    }
}
