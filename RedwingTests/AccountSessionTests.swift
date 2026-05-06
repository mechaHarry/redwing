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
}
