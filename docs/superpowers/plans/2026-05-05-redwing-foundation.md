# Redwing App Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native macOS Redwing foundation: Xcode app shell, setup/auth, one-account session, shared Webex realtime, Spaces -> Messages -> conditional Threads lanes, attention-only menu bar, status bar, diagnostics, and strict tests.

**Architecture:** Redwing owns app state, setup, session orchestration, lane UI, attention projection, status, diagnostics, and window placement. The `webex-swift-sdk` v2.5.0 owns OAuth/token lifecycle, Keychain-backed storage, REST transport, retry/backoff, realtime, snapshots, and `MessagesThreadStream`; Redwing accesses it through narrow protocols so unit tests use fakes.

**Tech Stack:** macOS SwiftUI + AppKit bridge, Xcode project, XCTest, local Swift package dependency `/Users/harriche/gits/github.com/mechaHarry/webex-swift-sdk`, SDK product `WebexSwiftSDK`.

---

## Scope Check

The approved spec contains several subsystems, but they are sequential parts of one app foundation rather than independent products. This plan implements them in dependency order:

1. app scaffold and test harness
2. domain/view models and diagnostics primitives
3. setup validation and secret-handling seam
4. account session and shared realtime seam
5. stream coordinators
6. attention feed
7. lane layout and skeleton UI
8. main/menu/status views
9. window focus bridge
10. SDK adapter and final build verification

No task should add Webex REST calls outside the SDK adapter.

## File Structure

Create this structure:

```text
redwing.xcodeproj/
  project.pbxproj
Redwing/
  App/
    RedwingApp.swift
    AppRootModel.swift
    RedwingEnvironment.swift
  Setup/
    SetupCredentials.swift
    SetupValidation.swift
    SetupCoordinator.swift
    SetupView.swift
  Account/
    AccountSession.swift
    WebexClientProviding.swift
    WebexSDKAdapter.swift
  Diagnostics/
    DiagnosticsStore.swift
    SessionStatus.swift
    StatusBarView.swift
    DiagnosticsPanelView.swift
  Spaces/
    SpacesCoordinator.swift
    SpaceRowViewModel.swift
  Messages/
    MessagesCoordinator.swift
    MessageRowViewModel.swift
    ThreadLanePolicy.swift
  Attention/
    AttentionFeedStore.swift
    AttentionItemViewModel.swift
    MenuBarView.swift
  Lanes/
    LaneLayoutModel.swift
    LaneSurfaceView.swift
    SkeletonViews.swift
  Window/
    WindowFocusController.swift
  Resources/
    Info.plist
    Redwing.entitlements
RedwingTests/
  Fakes/
    FakeWebexClientProviding.swift
    AsyncStreamTestSupport.swift
  SetupValidationTests.swift
  DiagnosticsStoreTests.swift
  AccountSessionTests.swift
  SpacesCoordinatorTests.swift
  MessagesCoordinatorTests.swift
  ThreadLanePolicyTests.swift
  AttentionFeedStoreTests.swift
  LaneLayoutModelTests.swift
  WindowFocusControllerTests.swift
```

Responsibility boundaries:

- `WebexClientProviding.swift` defines SDK-facing protocols and app-owned DTOs. Tests fake these protocols.
- `WebexSDKAdapter.swift` is the only production file importing `WebexSwiftSDK` directly, except thin model mapping helpers if a task explicitly adds them.
- Coordinator files are `@MainActor` observable state owners.
- View files are native SwiftUI and do not call SDK methods directly.
- `WindowFocusController.swift` is the only AppKit bridge for focus-following placement.

## Task 1: Xcode Project Scaffold

**Files:**
- Create: `redwing.xcodeproj/project.pbxproj`
- Create: `Redwing/App/RedwingApp.swift`
- Create: `Redwing/App/AppRootModel.swift`
- Create: `Redwing/App/RedwingEnvironment.swift`
- Create: `Redwing/Resources/Info.plist`
- Create: `Redwing/Resources/Redwing.entitlements`
- Create: `RedwingTests/SmokeTests.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create a minimal native app skeleton**

Create `Redwing/App/AppRootModel.swift`:

```swift
import Foundation

@MainActor
final class AppRootModel: ObservableObject {
    enum Phase: Equatable {
        case setupRequired
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .setupRequired

    func markLoading() {
        phase = .loading
    }

    func markReady() {
        phase = .ready
    }

    func markFailed(_ message: String) {
        phase = .failed(message)
    }
}
```

Create `Redwing/App/RedwingEnvironment.swift`:

```swift
import Foundation

struct RedwingEnvironment {
    var now: @Sendable () -> Date = { Date() }

    static let live = RedwingEnvironment()
}
```

Create `Redwing/App/RedwingApp.swift`:

```swift
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
```

Create `Redwing/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Redwing</string>
  <key>CFBundleIdentifier</key>
  <string>com.mechaharry.redwing</string>
  <key>CFBundleName</key>
  <string>Redwing</string>
  <key>CFBundleShortVersionString</key>
  <string>$(REDWING_SEMVER)</string>
  <key>CFBundleVersion</key>
  <string>$(REDWING_SEMVER)</string>
  <key>LSMinimumSystemVersion</key>
  <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
```

Create `Redwing/Resources/Redwing.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
</dict>
</plist>
```

Create `.gitignore`:

```gitignore
.DS_Store
.superpowers/
DerivedData/
*.xcuserdata/
```

- [ ] **Step 2: Create the Xcode project**

Create `redwing.xcodeproj/project.pbxproj` with:

- one macOS application target named `Redwing`
- one unit test target named `RedwingTests`
- bundle identifier `com.mechaharry.redwing`
- latest installed macOS only, currently deployment target `26.4`
- Swift language version inherited from Xcode
- local package reference `../webex-swift-sdk` if relative to `/Users/harriche/gits/github.com/mechaHarry/redwing`, or absolute local package path if Xcode rejects the relative path
- product dependency `WebexSwiftSDK` linked to the app target
- app sources from `Redwing/**/*.swift`
- test sources from `RedwingTests/**/*.swift`
- entitlements file `Redwing/Resources/Redwing.entitlements`
- Info.plist file `Redwing/Resources/Info.plist`

The implementation may create this project in Xcode once, then commit the resulting `project.pbxproj`. Do not add XcodeGen or another generator unless the user explicitly approves that new tool.

- [ ] **Step 3: Add the first smoke test**

Create `RedwingTests/SmokeTests.swift`:

```swift
import XCTest
@testable import Redwing

@MainActor
final class SmokeTests: XCTestCase {
    func testAppRootModelTransitions() {
        let model = AppRootModel()
        XCTAssertEqual(model.phase, .setupRequired)

        model.markLoading()
        XCTAssertEqual(model.phase, .loading)

        model.markReady()
        XCTAssertEqual(model.phase, .ready)

        model.markFailed("broken")
        XCTAssertEqual(model.phase, .failed("broken"))
    }
}
```

- [ ] **Step 4: Build and run the smoke test**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: test action succeeds and `SmokeTests/testAppRootModelTransitions` passes.

- [ ] **Step 5: Commit scaffold**

Run:

```bash
git add .gitignore redwing.xcodeproj Redwing RedwingTests
git commit -m "feat: scaffold native redwing app"
```

## Task 2: Diagnostics And Session Status Primitives

**Files:**
- Create: `Redwing/Diagnostics/DiagnosticsStore.swift`
- Create: `Redwing/Diagnostics/SessionStatus.swift`
- Test: `RedwingTests/DiagnosticsStoreTests.swift`

- [ ] **Step 1: Write diagnostics tests**

Create `RedwingTests/DiagnosticsStoreTests.swift`:

```swift
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

    func testClearRemovesSessionEntries() {
        let store = DiagnosticsStore(now: { Date(timeIntervalSince1970: 1) })
        store.append(source: .ui, severity: .info, message: "Loaded")
        XCTAssertEqual(store.entries.count, 1)

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSessionStatusIndicatorMapping() {
        XCTAssertEqual(SessionStatus.connected.indicator, .green)
        XCTAssertEqual(SessionStatus.failed("no token").indicator, .red)
        XCTAssertEqual(SessionStatus.reconnecting("retry").indicator, .yellow)
    }
}
```

- [ ] **Step 2: Run diagnostics tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/DiagnosticsStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `DiagnosticsStore` and `SessionStatus` do not exist.

- [ ] **Step 3: Implement diagnostics primitives**

Create `Redwing/Diagnostics/SessionStatus.swift`:

```swift
import Foundation

enum StatusIndicator: Equatable {
    case green
    case yellow
    case red
    case gray
}

enum SessionStatus: Equatable {
    case idle
    case connected
    case refreshing
    case reconnecting(String)
    case failed(String)

    var indicator: StatusIndicator {
        switch self {
        case .connected:
            return .green
        case .refreshing, .reconnecting:
            return .yellow
        case .failed:
            return .red
        case .idle:
            return .gray
        }
    }

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .connected:
            return "Connected"
        case .refreshing:
            return "Refreshing"
        case .reconnecting(let reason):
            return "Reconnecting: \(reason)"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}
```

Create `Redwing/Diagnostics/DiagnosticsStore.swift`:

```swift
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
```

- [ ] **Step 4: Run diagnostics tests and verify pass**

Run the same `xcodebuild test -only-testing:RedwingTests/DiagnosticsStoreTests` command.

Expected: tests pass.

- [ ] **Step 5: Commit diagnostics primitives**

Run:

```bash
git add Redwing/Diagnostics RedwingTests/DiagnosticsStoreTests.swift
git commit -m "feat: add session diagnostics primitives"
```

## Task 3: Setup Credentials And Validation

**Files:**
- Create: `Redwing/Setup/SetupCredentials.swift`
- Create: `Redwing/Setup/SetupValidation.swift`
- Test: `RedwingTests/SetupValidationTests.swift`

- [ ] **Step 1: Write setup validation tests**

Create `RedwingTests/SetupValidationTests.swift`:

```swift
import XCTest
@testable import Redwing

final class SetupValidationTests: XCTestCase {
    func testValidCredentialsPass() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertNoThrow(try SetupValidation.validate(credentials))
    }

    func testMissingSecretFailsWithoutEchoingSecretValue() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "   ",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .missingClientSecret)
            XCTAssertFalse(String(describing: error).contains("secret"))
        }
    }

    func testRealtimeScopesAreRequired() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:messages_read"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .missingRequiredScopes(["spark:all", "spark:kms"]))
        }
    }

    func testInvalidRedirectURIFails() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "not a url",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .invalidRedirectURI)
        }
    }
}
```

- [ ] **Step 2: Run setup validation tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/SetupValidationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because setup types do not exist.

- [ ] **Step 3: Implement setup validation**

Create `Redwing/Setup/SetupCredentials.swift`:

```swift
import Foundation

struct SetupCredentials: Equatable {
    var clientID: String
    var clientSecret: String
    var redirectURI: String
    var scopesText: String

    var scopes: [String] {
        scopesText
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "," })
            .map(String.init)
    }
}
```

Create `Redwing/Setup/SetupValidation.swift`:

```swift
import Foundation

enum SetupValidation {
    enum ValidationError: Error, Equatable, CustomStringConvertible {
        case missingClientID
        case missingClientSecret
        case invalidRedirectURI
        case missingRequiredScopes([String])

        var description: String {
            switch self {
            case .missingClientID:
                return "Client ID is required"
            case .missingClientSecret:
                return "Client secret is required"
            case .invalidRedirectURI:
                return "Redirect URI must be a valid URL"
            case .missingRequiredScopes(let scopes):
                return "Missing required scopes: \(scopes.joined(separator: " "))"
            }
        }
    }

    static let requiredRealtimeScopes = ["spark:all", "spark:kms"]

    static func validate(_ credentials: SetupCredentials) throws {
        guard !credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingClientID
        }

        guard !credentials.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingClientSecret
        }

        guard let url = URL(string: credentials.redirectURI),
              url.scheme != nil,
              url.host != nil else {
            throw ValidationError.invalidRedirectURI
        }

        let scopeSet = Set(credentials.scopes)
        let missingScopes = requiredRealtimeScopes.filter { !scopeSet.contains($0) }
        guard missingScopes.isEmpty else {
            throw ValidationError.missingRequiredScopes(missingScopes)
        }
    }
}
```

- [ ] **Step 4: Run setup validation tests and verify pass**

Run the same `xcodebuild test -only-testing:RedwingTests/SetupValidationTests` command.

Expected: tests pass.

- [ ] **Step 5: Commit setup validation**

Run:

```bash
git add Redwing/Setup/SetupCredentials.swift Redwing/Setup/SetupValidation.swift RedwingTests/SetupValidationTests.swift
git commit -m "feat: validate native setup credentials"
```

## Task 4: SDK-Facing Protocols And Fakes

**Files:**
- Create: `Redwing/Account/WebexClientProviding.swift`
- Create: `RedwingTests/Fakes/FakeWebexClientProviding.swift`
- Create: `RedwingTests/Fakes/AsyncStreamTestSupport.swift`

- [ ] **Step 1: Create SDK-facing app DTOs and protocols**

Create `Redwing/Account/WebexClientProviding.swift`:

```swift
import Foundation

struct WebexAccountSummary: Equatable, Sendable {
    let id: String
    let displayName: String
    let grantedScopes: [String]
}

struct SpaceSnapshot: Equatable, Sendable {
    let spaces: [SpaceItem]
    let isRefreshing: Bool
    let isLoadingNextPage: Bool
    let hasMore: Bool
    let lastErrorDescription: String?
}

struct SpaceItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let lastActivity: Date?
}

struct MessageThreadSnapshotDTO: Equatable, Sendable {
    let topLevelMessageIDs: [String]
    let entriesByID: [String: MessageThreadEntryDTO]
    let isRefreshing: Bool
    let isLoadingNextPage: Bool
    let hasMore: Bool
    let lastErrorDescription: String?
}

struct MessageThreadEntryDTO: Identifiable, Equatable, Sendable {
    let id: String
    let parentID: String?
    let childIDs: [String]
    let sender: String
    let body: String
    let created: Date?
    let mentionedPeople: [String]
    let mentionedGroups: [String]
    let isPlaceholderParent: Bool
    let isDeletedTombstone: Bool
}

enum RealtimeStateDTO: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, delay: TimeInterval)
    case failed(String)
}

protocol SpacesStreamProviding: AnyObject, Sendable {
    var snapshots: AsyncStream<SpaceSnapshot> { get }
    func refresh() async
    func loadNextPage() async
    func cancel()
}

protocol MessagesThreadStreamProviding: AnyObject, Sendable {
    var snapshots: AsyncStream<MessageThreadSnapshotDTO> { get }
    func refresh() async
    func loadNextPage() async
    func cancel()
}

protocol WebexClientProviding: Sendable {
    func existingAccount() async throws -> WebexAccountSummary?
    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary
    func startRealtime() async -> AsyncStream<RealtimeStateDTO>
    func makeSpacesStream() async throws -> SpacesStreamProviding
    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding
    func signOut() async
}
```

- [ ] **Step 2: Create fake stream support**

Create `RedwingTests/Fakes/AsyncStreamTestSupport.swift`:

```swift
import Foundation

final class StreamProbe<Value>: @unchecked Sendable {
    let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation

    init() {
        var captured: AsyncStream<Value>.Continuation?
        self.stream = AsyncStream { continuation in
            captured = continuation
        }
        self.continuation = captured!
    }

    func yield(_ value: Value) {
        continuation.yield(value)
    }

    func finish() {
        continuation.finish()
    }
}
```

Create `RedwingTests/Fakes/FakeWebexClientProviding.swift`:

```swift
import Foundation
@testable import Redwing

final class FakeSpacesStream: SpacesStreamProviding, @unchecked Sendable {
    let probe = StreamProbe<SpaceSnapshot>()
    private(set) var refreshCount = 0
    private(set) var loadNextPageCount = 0
    private(set) var isCancelled = false

    var snapshots: AsyncStream<SpaceSnapshot> { probe.stream }

    func refresh() async { refreshCount += 1 }
    func loadNextPage() async { loadNextPageCount += 1 }
    func cancel() { isCancelled = true }
}

final class FakeMessagesThreadStream: MessagesThreadStreamProviding, @unchecked Sendable {
    let probe = StreamProbe<MessageThreadSnapshotDTO>()
    private(set) var refreshCount = 0
    private(set) var loadNextPageCount = 0
    private(set) var isCancelled = false

    var snapshots: AsyncStream<MessageThreadSnapshotDTO> { probe.stream }

    func refresh() async { refreshCount += 1 }
    func loadNextPage() async { loadNextPageCount += 1 }
    func cancel() { isCancelled = true }
}

final class FakeWebexClientProviding: WebexClientProviding, @unchecked Sendable {
    var account: WebexAccountSummary?
    var authorizeResult: Result<WebexAccountSummary, Error>?
    var spacesStream = FakeSpacesStream()
    var messagesStreamsBySpaceID: [String: FakeMessagesThreadStream] = [:]
    let realtimeProbe = StreamProbe<RealtimeStateDTO>()
    private(set) var didStartRealtime = false
    private(set) var didSignOut = false

    func existingAccount() async throws -> WebexAccountSummary? {
        account
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        switch authorizeResult {
        case .success(let account):
            self.account = account
            return account
        case .failure(let error):
            throw error
        case nil:
            let account = WebexAccountSummary(id: "account-1", displayName: "Test User", grantedScopes: credentials.scopes)
            self.account = account
            return account
        }
    }

    func startRealtime() async -> AsyncStream<RealtimeStateDTO> {
        didStartRealtime = true
        return realtimeProbe.stream
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        spacesStream
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        if let stream = messagesStreamsBySpaceID[spaceID] {
            return stream
        }
        let stream = FakeMessagesThreadStream()
        messagesStreamsBySpaceID[spaceID] = stream
        return stream
    }

    func signOut() async {
        didSignOut = true
    }
}
```

- [ ] **Step 3: Build tests**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all existing tests still pass.

- [ ] **Step 4: Commit SDK-facing seam**

Run:

```bash
git add Redwing/Account/WebexClientProviding.swift RedwingTests/Fakes
git commit -m "feat: add sdk-facing app protocols"
```

## Task 5: Account Session Coordinator

**Files:**
- Create: `Redwing/Account/AccountSession.swift`
- Test: `RedwingTests/AccountSessionTests.swift`

- [ ] **Step 1: Write account session tests**

Create `RedwingTests/AccountSessionTests.swift`:

```swift
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
```

- [ ] **Step 2: Run account session tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/AccountSessionTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `AccountSession` does not exist.

- [ ] **Step 3: Implement account session**

Create `Redwing/Account/AccountSession.swift`:

```swift
import Foundation

@MainActor
final class AccountSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case setupRequired
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activeAccount: WebexAccountSummary?
    @Published private(set) var realtimeStatus: SessionStatus = .idle
    @Published private(set) var tokenStatus: SessionStatus = .idle

    private let clientProvider: WebexClientProviding
    private let diagnostics: DiagnosticsStore
    private var realtimeTask: Task<Void, Never>?

    init(clientProvider: WebexClientProviding, diagnostics: DiagnosticsStore) {
        self.clientProvider = clientProvider
        self.diagnostics = diagnostics
    }

    deinit {
        realtimeTask?.cancel()
    }

    func start() async {
        phase = .loading
        do {
            guard let account = try await clientProvider.existingAccount() else {
                phase = .setupRequired
                tokenStatus = .idle
                return
            }
            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            await startRealtime()
        } catch {
            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Failed to load account", detail: message)
            phase = .failed(message)
            tokenStatus = .failed("Account load failed")
        }
    }

    func authorize(credentials: SetupCredentials) async {
        phase = .loading
        do {
            try SetupValidation.validate(credentials)
            let account = try await clientProvider.authorize(credentials: credentials)
            activeAccount = account
            tokenStatus = .connected
            phase = .ready
            diagnostics.append(source: .auth, severity: .info, message: "Authorized Webex account")
            await startRealtime()
        } catch {
            let message = String(describing: error)
            diagnostics.append(source: .auth, severity: .error, message: "Authorization failed", detail: message)
            phase = .failed(message)
            tokenStatus = .failed("Authorization failed")
        }
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        try await clientProvider.makeSpacesStream()
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        try await clientProvider.makeMessagesThreadStream(spaceID: spaceID)
    }

    func signOut() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        await clientProvider.signOut()
        activeAccount = nil
        phase = .setupRequired
        realtimeStatus = .idle
        tokenStatus = .idle
    }

    private func startRealtime() async {
        realtimeTask?.cancel()
        realtimeStatus = .refreshing
        let states = await clientProvider.startRealtime()
        realtimeTask = Task { [weak self] in
            for await state in states {
                await self?.applyRealtimeState(state)
            }
        }
    }

    private func applyRealtimeState(_ state: RealtimeStateDTO) {
        switch state {
        case .disconnected:
            realtimeStatus = .idle
        case .connecting:
            realtimeStatus = .refreshing
        case .connected:
            realtimeStatus = .connected
        case .reconnecting(let attempt, let delay):
            realtimeStatus = .reconnecting("attempt \(attempt), \(String(format: "%.1f", delay))s")
        case .failed(let message):
            realtimeStatus = .failed(message)
            diagnostics.append(source: .realtime, severity: .error, message: "Realtime failed", detail: message)
        }
    }
}
```

- [ ] **Step 4: Run account session tests and verify pass**

Run the same `xcodebuild test -only-testing:RedwingTests/AccountSessionTests` command.

Expected: tests pass.

- [ ] **Step 5: Commit account session**

Run:

```bash
git add Redwing/Account/AccountSession.swift RedwingTests/AccountSessionTests.swift
git commit -m "feat: coordinate one active webex account"
```

## Task 6: Spaces Coordinator

**Files:**
- Create: `Redwing/Spaces/SpaceRowViewModel.swift`
- Create: `Redwing/Spaces/SpacesCoordinator.swift`
- Test: `RedwingTests/SpacesCoordinatorTests.swift`

- [ ] **Step 1: Write spaces coordinator tests**

Create `RedwingTests/SpacesCoordinatorTests.swift`:

```swift
import XCTest
@testable import Redwing

@MainActor
final class SpacesCoordinatorTests: XCTestCase {
    func testStartKeepsSkeletonUntilSnapshotArrives() async throws {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = SpacesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.start()

        XCTAssertTrue(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows.count, SpacesCoordinator.skeletonRowCount)

        fake.spacesStream.probe.yield(SpaceSnapshot(
            spaces: [SpaceItem(id: "s1", title: "General", lastActivity: Date(timeIntervalSince1970: 10))],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: true,
            lastErrorDescription: nil
        ))
        await Task.yield()

        XCTAssertFalse(coordinator.isShowingSkeletons)
        XCTAssertEqual(coordinator.rows.map(\.title), ["General"])
        XCTAssertTrue(coordinator.hasMore)
    }

    func testSelectSpaceStoresSelectedID() {
        let coordinator = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        coordinator.apply(snapshot: SpaceSnapshot(
            spaces: [SpaceItem(id: "s1", title: "General", lastActivity: nil)],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))

        coordinator.select(spaceID: "s1")

        XCTAssertEqual(coordinator.selectedSpaceID, "s1")
    }
}
```

- [ ] **Step 2: Run spaces tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/SpacesCoordinatorTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because Spaces coordinator files do not exist.

- [ ] **Step 3: Implement spaces coordinator**

Create `Redwing/Spaces/SpaceRowViewModel.swift`:

```swift
import Foundation

struct SpaceRowViewModel: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isSkeleton: Bool

    static func skeleton(id: Int) -> SpaceRowViewModel {
        SpaceRowViewModel(id: "space-skeleton-\(id)", title: "", detail: "", isSkeleton: true)
    }
}
```

Create `Redwing/Spaces/SpacesCoordinator.swift`:

```swift
import Foundation

@MainActor
final class SpacesCoordinator: ObservableObject {
    static let skeletonRowCount = 8

    @Published private(set) var rows: [SpaceRowViewModel] = (0..<skeletonRowCount).map(SpaceRowViewModel.skeleton)
    @Published private(set) var selectedSpaceID: String?
    @Published private(set) var status: SessionStatus = .idle
    @Published private(set) var hasMore = false
    @Published private(set) var isShowingSkeletons = true

    private let session: AccountSession?
    private let diagnostics: DiagnosticsStore
    private var stream: SpacesStreamProviding?
    private var task: Task<Void, Never>?

    init(session: AccountSession?, diagnostics: DiagnosticsStore) {
        self.session = session
        self.diagnostics = diagnostics
    }

    deinit {
        task?.cancel()
        stream?.cancel()
    }

    func start() async {
        guard let session else { return }
        do {
            let stream = try await session.makeSpacesStream()
            self.stream = stream
            status = .refreshing
            subscribe(to: stream)
            await stream.refresh()
        } catch {
            status = .failed("Spaces unavailable")
            diagnostics.append(source: .spaces, severity: .error, message: "Spaces stream failed", detail: String(describing: error))
        }
    }

    func apply(snapshot: SpaceSnapshot) {
        hasMore = snapshot.hasMore
        status = snapshot.lastErrorDescription.map(SessionStatus.failed) ?? (snapshot.isRefreshing ? .refreshing : .connected)
        if let error = snapshot.lastErrorDescription {
            diagnostics.append(source: .spaces, severity: .error, message: "Spaces refresh failed", detail: error)
        }

        guard !snapshot.spaces.isEmpty else {
            rows = snapshot.isRefreshing ? rows : []
            isShowingSkeletons = snapshot.isRefreshing
            return
        }

        rows = snapshot.spaces.map { space in
            SpaceRowViewModel(
                id: space.id,
                title: space.title,
                detail: space.lastActivity.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "No recent activity",
                isSkeleton: false
            )
        }
        isShowingSkeletons = false
    }

    func select(spaceID: String) {
        selectedSpaceID = spaceID
    }

    func loadNextPage() async {
        await stream?.loadNextPage()
    }

    private func subscribe(to stream: SpacesStreamProviding) {
        task?.cancel()
        task = Task { [weak self] in
            for await snapshot in stream.snapshots {
                await self?.apply(snapshot: snapshot)
            }
        }
    }
}
```

- [ ] **Step 4: Run spaces tests and verify pass**

Run the same spaces test command.

Expected: tests pass.

- [ ] **Step 5: Commit spaces coordinator**

Run:

```bash
git add Redwing/Spaces RedwingTests/SpacesCoordinatorTests.swift
git commit -m "feat: coordinate spaces snapshots"
```

## Task 7: Messages Coordinator And Thread Lane Policy

**Files:**
- Create: `Redwing/Messages/MessageRowViewModel.swift`
- Create: `Redwing/Messages/ThreadLanePolicy.swift`
- Create: `Redwing/Messages/MessagesCoordinator.swift`
- Test: `RedwingTests/ThreadLanePolicyTests.swift`
- Test: `RedwingTests/MessagesCoordinatorTests.swift`

- [ ] **Step 1: Write thread lane policy tests**

Create `RedwingTests/ThreadLanePolicyTests.swift`:

```swift
import XCTest
@testable import Redwing

final class ThreadLanePolicyTests: XCTestCase {
    func testStandaloneMessageDoesNotShowThreadLane() {
        let entry = MessageThreadEntryDTO(
            id: "m1",
            parentID: nil,
            childIDs: [],
            sender: "a@example.com",
            body: "Hello",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )

        XCTAssertFalse(ThreadLanePolicy.shouldShowThreadLane(for: entry))
    }

    func testChildOrPlaceholderShowsThreadLane() {
        let child = MessageThreadEntryDTO(
            id: "m1",
            parentID: "p1",
            childIDs: [],
            sender: "a@example.com",
            body: "Reply",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )
        let parent = MessageThreadEntryDTO(
            id: "p1",
            parentID: nil,
            childIDs: ["m1"],
            sender: "placeholder",
            body: "",
            created: nil,
            mentionedPeople: [],
            mentionedGroups: [],
            isPlaceholderParent: true,
            isDeletedTombstone: false
        )

        XCTAssertTrue(ThreadLanePolicy.shouldShowThreadLane(for: child))
        XCTAssertTrue(ThreadLanePolicy.shouldShowThreadLane(for: parent))
    }
}
```

- [ ] **Step 2: Write messages coordinator tests**

Create `RedwingTests/MessagesCoordinatorTests.swift`:

```swift
import XCTest
@testable import Redwing

@MainActor
final class MessagesCoordinatorTests: XCTestCase {
    func testSelectingSpaceCreatesOneSharedThreadStream() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")

        XCTAssertNotNil(fake.messagesStreamsBySpaceID["space-1"])
        XCTAssertTrue(coordinator.isShowingSkeletons)
    }

    func testSnapshotFeedsMessagesAndConditionalThreadLane() async {
        let fake = FakeWebexClientProviding()
        let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
        let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

        await coordinator.select(spaceID: "space-1")
        let stream = fake.messagesStreamsBySpaceID["space-1"]!
        stream.probe.yield(MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["parent"],
            entriesByID: [
                "parent": MessageThreadEntryDTO(
                    id: "parent",
                    parentID: nil,
                    childIDs: ["child"],
                    sender: "a@example.com",
                    body: "Parent",
                    created: Date(timeIntervalSince1970: 1),
                    mentionedPeople: [],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                ),
                "child": MessageThreadEntryDTO(
                    id: "child",
                    parentID: "parent",
                    childIDs: [],
                    sender: "b@example.com",
                    body: "Child",
                    created: Date(timeIntervalSince1970: 2),
                    mentionedPeople: [],
                    mentionedGroups: [],
                    isPlaceholderParent: false,
                    isDeletedTombstone: false
                )
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ))
        await Task.yield()

        XCTAssertEqual(coordinator.messageRows.map(\.id), ["parent"])
        coordinator.select(messageID: "parent")
        XCTAssertTrue(coordinator.isThreadLaneVisible)
        XCTAssertEqual(coordinator.threadRows.map(\.id), ["parent", "child"])
    }
}
```

- [ ] **Step 3: Run messages tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/ThreadLanePolicyTests \
  -only-testing:RedwingTests/MessagesCoordinatorTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because messages files do not exist.

- [ ] **Step 4: Implement message row, policy, and coordinator**

Create `Redwing/Messages/MessageRowViewModel.swift`:

```swift
import Foundation

struct MessageRowViewModel: Identifiable, Equatable {
    let id: String
    let sender: String
    let body: String
    let detail: String
    let depth: Int
    let isSkeleton: Bool
    let isPlaceholderParent: Bool
    let isDeletedTombstone: Bool

    static func skeleton(id: Int) -> MessageRowViewModel {
        MessageRowViewModel(
            id: "message-skeleton-\(id)",
            sender: "",
            body: "",
            detail: "",
            depth: 0,
            isSkeleton: true,
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )
    }
}
```

Create `Redwing/Messages/ThreadLanePolicy.swift`:

```swift
import Foundation

enum ThreadLanePolicy {
    static func shouldShowThreadLane(for entry: MessageThreadEntryDTO) -> Bool {
        entry.parentID != nil ||
        !entry.childIDs.isEmpty ||
        entry.isPlaceholderParent ||
        entry.isDeletedTombstone
    }
}
```

Create `Redwing/Messages/MessagesCoordinator.swift`:

```swift
import Foundation

@MainActor
final class MessagesCoordinator: ObservableObject {
    static let skeletonRowCount = 8

    @Published private(set) var messageRows: [MessageRowViewModel] = (0..<skeletonRowCount).map(MessageRowViewModel.skeleton)
    @Published private(set) var threadRows: [MessageRowViewModel] = []
    @Published private(set) var selectedSpaceID: String?
    @Published private(set) var selectedMessageID: String?
    @Published private(set) var isThreadLaneVisible = false
    @Published private(set) var isShowingSkeletons = true
    @Published private(set) var status: SessionStatus = .idle
    @Published private(set) var hasMore = false

    private let session: AccountSession
    private let diagnostics: DiagnosticsStore
    private var stream: MessagesThreadStreamProviding?
    private var task: Task<Void, Never>?
    private var latestSnapshot: MessageThreadSnapshotDTO?

    init(session: AccountSession, diagnostics: DiagnosticsStore) {
        self.session = session
        self.diagnostics = diagnostics
    }

    deinit {
        task?.cancel()
        stream?.cancel()
    }

    func select(spaceID: String) async {
        guard selectedSpaceID != spaceID else { return }
        task?.cancel()
        stream?.cancel()
        selectedSpaceID = spaceID
        selectedMessageID = nil
        latestSnapshot = nil
        isThreadLaneVisible = false
        threadRows = []
        messageRows = (0..<Self.skeletonRowCount).map(MessageRowViewModel.skeleton)
        isShowingSkeletons = true
        status = .refreshing

        do {
            let stream = try await session.makeMessagesThreadStream(spaceID: spaceID)
            self.stream = stream
            subscribe(to: stream)
            await stream.refresh()
        } catch {
            status = .failed("Messages unavailable")
            diagnostics.append(source: .messages, severity: .error, message: "Messages stream failed", detail: String(describing: error))
        }
    }

    func apply(snapshot: MessageThreadSnapshotDTO) {
        latestSnapshot = snapshot
        hasMore = snapshot.hasMore
        status = snapshot.lastErrorDescription.map(SessionStatus.failed) ?? (snapshot.isRefreshing ? .refreshing : .connected)
        if let error = snapshot.lastErrorDescription {
            diagnostics.append(source: .messages, severity: .error, message: "Messages refresh failed", detail: error)
        }
        messageRows = snapshot.topLevelMessageIDs.compactMap { id in
            snapshot.entriesByID[id].map { row(from: $0, depth: 0) }
        }
        isShowingSkeletons = false
        rebuildThreadRows()
    }

    func select(messageID: String) {
        selectedMessageID = messageID
        rebuildThreadRows()
    }

    func loadNextPage() async {
        await stream?.loadNextPage()
    }

    private func subscribe(to stream: MessagesThreadStreamProviding) {
        task = Task { [weak self] in
            for await snapshot in stream.snapshots {
                await self?.apply(snapshot: snapshot)
            }
        }
    }

    private func rebuildThreadRows() {
        guard let selectedMessageID,
              let snapshot = latestSnapshot,
              let selectedEntry = snapshot.entriesByID[selectedMessageID],
              ThreadLanePolicy.shouldShowThreadLane(for: selectedEntry) else {
            isThreadLaneVisible = false
            threadRows = []
            return
        }

        isThreadLaneVisible = true
        let rootID = selectedEntry.parentID ?? selectedEntry.id
        threadRows = rowsWalking(id: rootID, snapshot: snapshot, depth: 0)
    }

    private func rowsWalking(id: String, snapshot: MessageThreadSnapshotDTO, depth: Int) -> [MessageRowViewModel] {
        guard let entry = snapshot.entriesByID[id] else { return [] }
        return [row(from: entry, depth: depth)] + entry.childIDs.flatMap { rowsWalking(id: $0, snapshot: snapshot, depth: depth + 1) }
    }

    private func row(from entry: MessageThreadEntryDTO, depth: Int) -> MessageRowViewModel {
        MessageRowViewModel(
            id: entry.id,
            sender: entry.sender,
            body: entry.body,
            detail: entry.created.map { $0.formatted(date: .omitted, time: .shortened) } ?? "",
            depth: depth,
            isSkeleton: false,
            isPlaceholderParent: entry.isPlaceholderParent,
            isDeletedTombstone: entry.isDeletedTombstone
        )
    }
}
```

- [ ] **Step 5: Run messages tests and verify pass**

Run the same messages test command.

Expected: tests pass.

- [ ] **Step 6: Commit messages coordination**

Run:

```bash
git add Redwing/Messages RedwingTests/ThreadLanePolicyTests.swift RedwingTests/MessagesCoordinatorTests.swift
git commit -m "feat: coordinate shared message thread stream"
```

## Task 8: Attention Feed Projection

**Files:**
- Create: `Redwing/Attention/AttentionItemViewModel.swift`
- Create: `Redwing/Attention/AttentionFeedStore.swift`
- Test: `RedwingTests/AttentionFeedStoreTests.swift`

- [ ] **Step 1: Write attention feed tests**

Create `RedwingTests/AttentionFeedStoreTests.swift`:

```swift
import XCTest
@testable import Redwing

@MainActor
final class AttentionFeedStoreTests: XCTestCase {
    func testIncludesDirectMentionsAndAllGroupMentionsOnly() {
        let store = AttentionFeedStore(currentUserID: "me")
        store.apply(snapshot: MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["direct", "all", "plain"],
            entriesByID: [
                "direct": entry(id: "direct", mentionedPeople: ["me"], mentionedGroups: []),
                "all": entry(id: "all", mentionedPeople: [], mentionedGroups: ["all"]),
                "plain": entry(id: "plain", mentionedPeople: [], mentionedGroups: [])
            ],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        ), spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.map(\.id), ["all", "direct"])
    }

    func testDedupesByMessageIDAcrossRefreshes() {
        let store = AttentionFeedStore(currentUserID: "me")
        let snapshot = MessageThreadSnapshotDTO(
            topLevelMessageIDs: ["m1"],
            entriesByID: ["m1": entry(id: "m1", mentionedPeople: ["me"], mentionedGroups: [])],
            isRefreshing: false,
            isLoadingNextPage: false,
            hasMore: false,
            lastErrorDescription: nil
        )

        store.apply(snapshot: snapshot, spaceID: "space-1", spaceTitle: "General")
        store.apply(snapshot: snapshot, spaceID: "space-1", spaceTitle: "General")

        XCTAssertEqual(store.items.count, 1)
    }

    private func entry(id: String, mentionedPeople: [String], mentionedGroups: [String]) -> MessageThreadEntryDTO {
        MessageThreadEntryDTO(
            id: id,
            parentID: nil,
            childIDs: [],
            sender: "a@example.com",
            body: id,
            created: id == "all" ? Date(timeIntervalSince1970: 2) : Date(timeIntervalSince1970: 1),
            mentionedPeople: mentionedPeople,
            mentionedGroups: mentionedGroups,
            isPlaceholderParent: false,
            isDeletedTombstone: false
        )
    }
}
```

- [ ] **Step 2: Run attention tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/AttentionFeedStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because attention files do not exist.

- [ ] **Step 3: Implement attention feed**

Create `Redwing/Attention/AttentionItemViewModel.swift`:

```swift
import Foundation

struct AttentionItemViewModel: Identifiable, Equatable {
    let id: String
    let spaceID: String
    let spaceTitle: String
    let sender: String
    let body: String
    let created: Date?
    let reason: String
}
```

Create `Redwing/Attention/AttentionFeedStore.swift`:

```swift
import Foundation

@MainActor
final class AttentionFeedStore: ObservableObject {
    @Published private(set) var items: [AttentionItemViewModel] = []
    @Published private(set) var status: SessionStatus = .idle

    private let currentUserID: String

    init(currentUserID: String) {
        self.currentUserID = currentUserID
    }

    func apply(snapshot: MessageThreadSnapshotDTO, spaceID: String, spaceTitle: String) {
        status = snapshot.lastErrorDescription.map(SessionStatus.failed) ?? .connected
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for entry in snapshot.entriesByID.values where !entry.isPlaceholderParent && !entry.isDeletedTombstone {
            guard let reason = attentionReason(for: entry) else { continue }
            byID[entry.id] = AttentionItemViewModel(
                id: entry.id,
                spaceID: spaceID,
                spaceTitle: spaceTitle,
                sender: entry.sender,
                body: entry.body,
                created: entry.created,
                reason: reason
            )
        }

        items = byID.values.sorted { left, right in
            switch (left.created, right.created) {
            case (.some(let leftDate), .some(let rightDate)):
                if leftDate == rightDate { return left.id < right.id }
                return leftDate > rightDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return left.id < right.id
            }
        }
    }

    private func attentionReason(for entry: MessageThreadEntryDTO) -> String? {
        if entry.mentionedPeople.contains(currentUserID) {
            return "Mentioned you"
        }
        if entry.mentionedGroups.contains(where: { $0.lowercased() == "all" }) {
            return "Mentioned all"
        }
        return nil
    }
}
```

- [ ] **Step 4: Run attention tests and verify pass**

Run the same attention test command.

Expected: tests pass.

- [ ] **Step 5: Commit attention feed**

Run:

```bash
git add Redwing/Attention RedwingTests/AttentionFeedStoreTests.swift
git commit -m "feat: derive attention-only feed"
```

## Task 9: Lane Layout And Skeleton Models

**Files:**
- Create: `Redwing/Lanes/LaneLayoutModel.swift`
- Create: `Redwing/Lanes/SkeletonViews.swift`
- Test: `RedwingTests/LaneLayoutModelTests.swift`

- [ ] **Step 1: Write lane layout tests**

Create `RedwingTests/LaneLayoutModelTests.swift`:

```swift
import XCTest
@testable import Redwing

final class LaneLayoutModelTests: XCTestCase {
    func testThreadLaneHiddenForStandaloneSelection() {
        let layout = LaneLayoutModel(threadVisible: false, focusedLane: .messages)

        XCTAssertEqual(layout.visibleLanes.map(\.id), [.spaces, .messages])
        XCTAssertGreaterThan(layout.width(for: .messages, totalWidth: 1200), layout.width(for: .spaces, totalWidth: 1200))
    }

    func testThreadLaneVisibleWhenThreadSelected() {
        let layout = LaneLayoutModel(threadVisible: true, focusedLane: .thread)

        XCTAssertEqual(layout.visibleLanes.map(\.id), [.spaces, .messages, .thread])
        XCTAssertGreaterThan(layout.width(for: .thread, totalWidth: 1200), layout.width(for: .spaces, totalWidth: 1200))
    }

    func testMinimumWidthsPreventCollapse() {
        let layout = LaneLayoutModel(threadVisible: true, focusedLane: .messages)

        XCTAssertGreaterThanOrEqual(layout.width(for: .spaces, totalWidth: 500), 180)
        XCTAssertGreaterThanOrEqual(layout.width(for: .messages, totalWidth: 500), 260)
    }
}
```

- [ ] **Step 2: Run lane tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/LaneLayoutModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because lane layout does not exist.

- [ ] **Step 3: Implement lane layout**

Create `Redwing/Lanes/LaneLayoutModel.swift`:

```swift
import Foundation

struct LaneLayoutModel: Equatable {
    enum LaneID: Equatable {
        case spaces
        case messages
        case thread
    }

    struct Lane: Equatable {
        let id: LaneID
        let minWidth: Double
        let preferredWeight: Double
    }

    let threadVisible: Bool
    let focusedLane: LaneID

    var visibleLanes: [Lane] {
        [
            Lane(id: .spaces, minWidth: 180, preferredWeight: focusedLane == .spaces ? 1.35 : 0.75),
            Lane(id: .messages, minWidth: 260, preferredWeight: focusedLane == .messages ? 1.60 : 1.0)
        ] + (threadVisible ? [
            Lane(id: .thread, minWidth: 240, preferredWeight: focusedLane == .thread ? 1.45 : 0.9)
        ] : [])
    }

    func width(for laneID: LaneID, totalWidth: Double) -> Double {
        guard let lane = visibleLanes.first(where: { $0.id == laneID }) else { return 0 }
        let minimumTotal = visibleLanes.map(\.minWidth).reduce(0, +)
        guard totalWidth > minimumTotal else {
            return lane.minWidth
        }
        let extra = totalWidth - minimumTotal
        let weightTotal = visibleLanes.map(\.preferredWeight).reduce(0, +)
        return lane.minWidth + extra * (lane.preferredWeight / weightTotal)
    }
}
```

Create `Redwing/Lanes/SkeletonViews.swift`:

```swift
import SwiftUI

struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 220, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading")
    }
}
```

- [ ] **Step 4: Run lane tests and verify pass**

Run the same lane test command.

Expected: tests pass.

- [ ] **Step 5: Commit lane models**

Run:

```bash
git add Redwing/Lanes RedwingTests/LaneLayoutModelTests.swift
git commit -m "feat: model stable horizontal lanes"
```

## Task 10: Main Views, Menu Bar, Status Bar, And Diagnostics Panel

**Files:**
- Create: `Redwing/Lanes/LaneSurfaceView.swift`
- Create: `Redwing/Diagnostics/StatusBarView.swift`
- Create: `Redwing/Diagnostics/DiagnosticsPanelView.swift`
- Create: `Redwing/Attention/MenuBarView.swift`
- Modify: `Redwing/App/RedwingApp.swift`
- Modify: `Redwing/App/AppRootModel.swift`
- Create: `Redwing/Setup/SetupView.swift`

- [ ] **Step 1: Extend root model for composed coordinators**

Modify `Redwing/App/AppRootModel.swift` to own the app-level stores:

```swift
import Foundation

@MainActor
final class AppRootModel: ObservableObject {
    enum Phase: Equatable {
        case setupRequired
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .setupRequired
    let diagnostics: DiagnosticsStore
    var accountSession: AccountSession?
    var spacesCoordinator: SpacesCoordinator?
    var messagesCoordinator: MessagesCoordinator?
    var attentionFeed: AttentionFeedStore?

    init(diagnostics: DiagnosticsStore = DiagnosticsStore()) {
        self.diagnostics = diagnostics
    }

    func configure(clientProvider: WebexClientProviding, currentUserID: String) {
        let session = AccountSession(clientProvider: clientProvider, diagnostics: diagnostics)
        self.accountSession = session
        self.spacesCoordinator = SpacesCoordinator(session: session, diagnostics: diagnostics)
        self.messagesCoordinator = MessagesCoordinator(session: session, diagnostics: diagnostics)
        self.attentionFeed = AttentionFeedStore(currentUserID: currentUserID)
    }

    func markLoading() { phase = .loading }
    func markReady() { phase = .ready }
    func markSetupRequired() { phase = .setupRequired }
    func markFailed(_ message: String) { phase = .failed(message) }
}
```

- [ ] **Step 2: Add setup view**

Create `Redwing/Setup/SetupView.swift`:

```swift
import SwiftUI

struct SetupView: View {
    @State private var credentials = SetupCredentials(
        clientID: "",
        clientSecret: "",
        redirectURI: "http://127.0.0.1:8282/oauth/callback",
        scopesText: "spark:all spark:kms"
    )
    let onAuthorize: (SetupCredentials) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Webex Setup")
                .font(.title2)
                .fontWeight(.semibold)
            TextField("Client ID", text: $credentials.clientID)
            SecureField("Client Secret", text: $credentials.clientSecret)
            TextField("Redirect URI", text: $credentials.redirectURI)
            TextField("Scopes", text: $credentials.scopesText)
            Button("Authorize") {
                onAuthorize(credentials)
            }
            .keyboardShortcut(.defaultAction)
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(width: 460)
    }
}
```

- [ ] **Step 3: Add lane surface and status views**

Create `Redwing/Lanes/LaneSurfaceView.swift` with native lists and skeleton rows:

```swift
import SwiftUI

struct LaneSurfaceView: View {
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator

    var body: some View {
        GeometryReader { proxy in
            let layout = LaneLayoutModel(
                threadVisible: messages.isThreadLaneVisible,
                focusedLane: messages.isThreadLaneVisible ? .thread : .messages
            )
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    spacesLane(width: layout.width(for: .spaces, totalWidth: proxy.size.width))
                    messagesLane(width: layout.width(for: .messages, totalWidth: proxy.size.width))
                    if messages.isThreadLaneVisible {
                        threadLane(width: layout.width(for: .thread, totalWidth: proxy.size.width))
                    }
                }
                .padding(10)
            }
        }
    }

    private func spacesLane(width: Double) -> some View {
        List(spaces.rows) { row in
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                Button {
                    spaces.select(spaceID: row.id)
                    Task { await messages.select(spaceID: row.id) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(row.title)
                        Text(row.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: width)
    }

    private func messagesLane(width: Double) -> some View {
        List(messages.messageRows) { row in
            messageRow(row) {
                messages.select(messageID: row.id)
            }
        }
        .frame(width: width)
    }

    private func threadLane(width: Double) -> some View {
        List(messages.threadRows) { row in
            messageRow(row) {}
                .padding(.leading, CGFloat(row.depth) * 18)
        }
        .frame(width: width)
    }

    private func messageRow(_ row: MessageRowViewModel, action: @escaping () -> Void) -> some View {
        Group {
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                Button(action: action) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.sender).fontWeight(.medium)
                        Text(row.body).lineLimit(3)
                        Text(row.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

Create `Redwing/Diagnostics/StatusBarView.swift`:

```swift
import SwiftUI

struct StatusBarView: View {
    let realtime: SessionStatus
    let token: SessionStatus
    let spaces: SessionStatus
    let messages: SessionStatus
    let attention: SessionStatus
    let onShowDiagnostics: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            StatusDot(label: "WebSocket", status: realtime)
            StatusDot(label: "Token", status: token)
            StatusDot(label: "Spaces", status: spaces)
            StatusDot(label: "Messages", status: messages)
            StatusDot(label: "Attention", status: attention)
            Spacer()
            Button("Diagnostics", action: onShowDiagnostics)
                .controlSize(.small)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(.bar)
    }
}

private struct StatusDot: View {
    let label: String
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .shadow(color: color.opacity(0.8), radius: 3)
                .frame(width: 7, height: 7)
            Text(label)
        }
        .help("\(label): \(status.label)")
    }

    private var color: Color {
        switch status.indicator {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        case .gray: return .secondary
        }
    }
}
```

Create `Redwing/Diagnostics/DiagnosticsPanelView.swift`:

```swift
import SwiftUI

struct DiagnosticsPanelView: View {
    @ObservedObject var diagnostics: DiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostics").font(.headline)
                Spacer()
                Button("Clear") { diagnostics.clear() }
            }
            List(diagnostics.entries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entry.source.rawValue) \(entry.severity.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.message)
                    if let detail = entry.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 360)
    }
}
```

Create `Redwing/Attention/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var feed: AttentionFeedStore
    let openWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Button("Open Redwing", action: openWindow)
            Divider()
            if feed.items.isEmpty {
                Text("No attention items")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(feed.items.prefix(8)) { item in
                    VStack(alignment: .leading) {
                        Text(item.spaceTitle).font(.caption).foregroundStyle(.secondary)
                        Text(item.body).lineLimit(2)
                        Text(item.reason).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
    }
}
```

- [ ] **Step 4: Wire views in `RedwingApp` with a compiling preview provider**

Modify `Redwing/App/RedwingApp.swift` so the window shows setup until a session is configured, then lane/status UI:

```swift
import AppKit
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel = AppRootModel()
    @State private var isShowingDiagnostics = false

    var body: some Scene {
        WindowGroup("Redwing") {
            rootView
                .frame(minWidth: 980, minHeight: 620)
                .sheet(isPresented: $isShowingDiagnostics) {
                    DiagnosticsPanelView(diagnostics: rootModel.diagnostics)
                }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Redwing", systemImage: "bolt.horizontal.circle") {
            if let feed = rootModel.attentionFeed {
                MenuBarView(feed: feed) {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else {
                Button("Open Redwing") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Divider()
                Text("Setup required")
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let session = rootModel.accountSession,
           let spaces = rootModel.spacesCoordinator,
           let messages = rootModel.messagesCoordinator,
           let attention = rootModel.attentionFeed {
            VStack(spacing: 0) {
                LaneSurfaceView(spaces: spaces, messages: messages)
                StatusBarView(
                    realtime: session.realtimeStatus,
                    token: session.tokenStatus,
                    spaces: spaces.status,
                    messages: messages.status,
                    attention: attention.status,
                    onShowDiagnostics: { isShowingDiagnostics = true }
                )
            }
        } else {
            SetupView { credentials in
                Task {
                    do {
                        try SetupValidation.validate(credentials)
                        rootModel.diagnostics.append(source: .auth, severity: .info, message: "Setup validated")
                    } catch {
                        rootModel.diagnostics.append(source: .auth, severity: .error, message: "Setup validation failed", detail: String(describing: error))
                    }
                }
            }
        }
    }
}
```

This wiring validates setup input and records diagnostics while the live SDK adapter is added in Task 12.

- [ ] **Step 5: Build the UI**

Run:

```bash
xcodebuild build \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 6: Commit UI composition**

Run:

```bash
git add Redwing/App Redwing/Setup/SetupView.swift Redwing/Lanes Redwing/Diagnostics Redwing/Attention/MenuBarView.swift
git commit -m "feat: compose native redwing shell"
```

## Task 11: Window Focus Controller

**Files:**
- Create: `Redwing/Window/WindowFocusController.swift`
- Test: `RedwingTests/WindowFocusControllerTests.swift`

- [ ] **Step 1: Write placement tests**

Create `RedwingTests/WindowFocusControllerTests.swift`:

```swift
import XCTest
@testable import Redwing

final class WindowFocusControllerTests: XCTestCase {
    func testCenteredFrameUsesTargetScreenVisibleFrame() {
        let frame = WindowFocusController.centeredFrame(
            windowSize: CGSize(width: 800, height: 500),
            visibleFrame: CGRect(x: 100, y: 50, width: 1200, height: 900)
        )

        XCTAssertEqual(frame.origin.x, 300)
        XCTAssertEqual(frame.origin.y, 250)
        XCTAssertEqual(frame.size.width, 800)
        XCTAssertEqual(frame.size.height, 500)
    }

    func testOversizedWindowIsClampedToVisibleFrame() {
        let frame = WindowFocusController.centeredFrame(
            windowSize: CGSize(width: 2000, height: 1200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 700)
        )

        XCTAssertEqual(frame.size.width, 1000)
        XCTAssertEqual(frame.size.height, 700)
    }
}
```

- [ ] **Step 2: Run window tests and verify failure**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -only-testing:RedwingTests/WindowFocusControllerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `WindowFocusController` does not exist.

- [ ] **Step 3: Implement window focus controller**

Create `Redwing/Window/WindowFocusController.swift`:

```swift
import AppKit

enum WindowFocusController {
    static func centeredFrame(windowSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(windowSize.width, visibleFrame.width)
        let height = min(windowSize.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )
    }

    @MainActor
    static func moveToCurrentDesktop(window: NSWindow?) {
        guard let window else { return }
        let targetScreen = NSScreen.main ?? window.screen ?? NSScreen.screens.first
        guard let visibleFrame = targetScreen?.visibleFrame else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = window.frame.size == .zero ? CGSize(width: 1100, height: 720) : window.frame.size
        window.setFrame(centeredFrame(windowSize: size, visibleFrame: visibleFrame), display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 4: Run window tests and verify pass**

Run the same window test command.

Expected: tests pass.

- [ ] **Step 5: Commit window controller**

Run:

```bash
git add Redwing/Window RedwingTests/WindowFocusControllerTests.swift
git commit -m "feat: add focus-following window placement"
```

## Task 12: Live Webex SDK Adapter

**Files:**
- Create: `Redwing/Account/WebexSDKAdapter.swift`
- Modify: `Redwing/App/RedwingApp.swift`
- Modify: `Redwing/App/AppRootModel.swift`

- [ ] **Step 1: Implement SDK adapter**

Create `Redwing/Account/WebexSDKAdapter.swift`:

```swift
import AppKit
import Foundation
import WebexSwiftSDK

final class WebexSDKAdapter: WebexClientProviding, @unchecked Sendable {
    private let keychainService = "com.mechaharry.redwing.webex"
    private var registry: WebexClientRegistry?
    private var client: WebexClient?
    private var realtimeConnection: WebexRealtimeConnection?

    func existingAccount() async throws -> WebexAccountSummary? {
        let registry = makeRegistry()
        let accounts = try await registry.listAccounts()
        guard let account = accounts.first else { return nil }
        self.client = try await registry.client(for: account.id)
        return WebexAccountSummary(
            id: account.id.rawValue,
            displayName: account.displayName ?? account.id.rawValue,
            grantedScopes: []
        )
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        try SetupValidation.validate(credentials)
        let registry = makeRegistry()
        let configuration = WebexIntegrationConfiguration(
            clientID: credentials.clientID,
            clientSecret: credentials.clientSecret,
            redirectURI: URL(string: credentials.redirectURI)!,
            scopes: credentials.scopes,
            prefersEphemeralWebBrowserSession: false
        )

        let authorized = try await registry.authorizeAndAddAccount(
            configuration: configuration,
            openAuthorizationURL: { url in
                guard NSWorkspace.shared.open(url) else {
                    throw WebexSDKError.network("Failed to open Webex authorization URL")
                }
            }
        )
        self.client = authorized.client
        return WebexAccountSummary(
            id: authorized.account.id.rawValue,
            displayName: authorized.account.displayName ?? authorized.account.id.rawValue,
            grantedScopes: credentials.scopes
        )
    }

    func startRealtime() async -> AsyncStream<RealtimeStateDTO> {
        guard let client else {
            return AsyncStream { continuation in
                continuation.yield(.failed("No active Webex client"))
                continuation.finish()
            }
        }
        let connection = client.realtime.connect(options: WebexRealtimeOptions(
            resources: [.messages, .spaces, .memberships, .attachmentActions],
            deviceName: "redwing"
        ))
        realtimeConnection = connection
        return connection.states.map { state in
            switch state {
            case .disconnected:
                return .disconnected
            case .discovering, .registeringDevice, .connecting, .authorizing:
                return .connecting
            case .connected:
                return .connected
            case .reconnecting(let attempt, let delay):
                return .reconnecting(attempt: attempt, delay: delay)
            case .failed(let error):
                return .failed(String(describing: error))
            }
        }
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        guard let client else { throw WebexSDKError.missingCredential }
        return SDKSpacesStream(stream: client.spaces.stream(
            params: .init(sortBy: .lastActivity, max: 40),
            pageLimit: 3
        ))
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        guard let client else { throw WebexSDKError.missingCredential }
        return SDKMessagesThreadStream(stream: client.messages.threadedStream(
            params: .init(roomID: spaceID, max: 50),
            pageLimit: 2
        ))
    }

    func signOut() async {
        realtimeConnection?.cancel()
        realtimeConnection = nil
    }

    private func makeRegistry() -> WebexClientRegistry {
        if let registry { return registry }
        let store = KeychainWebexStore(service: keychainService)
        let registry = WebexClientRegistry(store: store)
        self.registry = registry
        return registry
    }
}
```

Add private adapter stream wrappers in the same file:

```swift
private final class SDKSpacesStream: SpacesStreamProviding, @unchecked Sendable {
    private let stream: SpacesStream

    init(stream: SpacesStream) {
        self.stream = stream
    }

    var snapshots: AsyncStream<SpaceSnapshot> {
        stream.snapshots.map { snapshot in
            SpaceSnapshot(
                spaces: snapshot.items.map {
                    SpaceItem(id: $0.id, title: $0.title ?? "(untitled)", lastActivity: $0.lastActivity)
                },
                isRefreshing: snapshot.isRefreshing,
                isLoadingNextPage: snapshot.isLoadingNextPage,
                hasMore: snapshot.pagination.hasMore,
                lastErrorDescription: snapshot.lastError.map(String.init(describing:))
            )
        }
    }

    func refresh() async { await stream.refresh() }
    func loadNextPage() async { await stream.loadNextPage() }
    func cancel() {}
}

private final class SDKMessagesThreadStream: MessagesThreadStreamProviding, @unchecked Sendable {
    private let stream: MessagesThreadStream

    init(stream: MessagesThreadStream) {
        self.stream = stream
    }

    var snapshots: AsyncStream<MessageThreadSnapshotDTO> {
        stream.snapshots.map { snapshot in
            MessageThreadSnapshotDTO(
                topLevelMessageIDs: snapshot.topLevelMessageIDs,
                entriesByID: snapshot.threadEntryByID.mapValues { entry in
                    MessageThreadEntryDTO(
                        id: entry.id,
                        parentID: entry.parentID,
                        childIDs: entry.childIDs,
                        sender: entry.message?.personEmail ?? "(unknown sender)",
                        body: entry.message?.text ?? entry.message?.markdown ?? (entry.isDeletedTombstone ? "(message deleted)" : "(parent message unavailable)"),
                        created: entry.effectiveCreated,
                        mentionedPeople: entry.message?.mentionedPeople ?? [],
                        mentionedGroups: entry.message?.mentionedGroups ?? [],
                        isPlaceholderParent: entry.isPlaceholderParent,
                        isDeletedTombstone: entry.isDeletedTombstone
                    )
                },
                isRefreshing: snapshot.isRefreshing,
                isLoadingNextPage: snapshot.isLoadingNextPage,
                hasMore: snapshot.pagination.hasMore,
                lastErrorDescription: snapshot.lastError.map(String.init(describing:))
            )
        }
    }

    func refresh() async { await stream.refresh() }
    func loadNextPage() async { await stream.loadNextPage() }
    func cancel() {}
}
```

- [ ] **Step 2: Add AsyncStream map helper**

Create `Redwing/Account/AsyncStreamMapping.swift` so the SDK adapter can map SDK streams into app DTO streams deterministically:

```swift
import Foundation

extension AsyncStream {
    func map<Mapped>(_ transform: @escaping @Sendable (Element) -> Mapped) -> AsyncStream<Mapped> {
        AsyncStream<Mapped> { continuation in
            let task = Task {
                for await element in self {
                    continuation.yield(transform(element))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 3: Wire live adapter into the app**

Modify `Redwing/App/RedwingApp.swift` so `AppRootModel` is configured with the live adapter:

```swift
import SwiftUI

@main
struct RedwingApp: App {
    @StateObject private var rootModel: AppRootModel
    @State private var isShowingDiagnostics = false

    init() {
        let diagnostics = DiagnosticsStore()
        let model = AppRootModel(diagnostics: diagnostics)
        model.configure(clientProvider: WebexSDKAdapter(), currentUserID: "me")
        _rootModel = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup("Redwing") {
            rootView
                .frame(minWidth: 980, minHeight: 620)
                .sheet(isPresented: $isShowingDiagnostics) {
                    DiagnosticsPanelView(diagnostics: rootModel.diagnostics)
                }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Redwing", systemImage: "bolt.horizontal.circle") {
            if let feed = rootModel.attentionFeed {
                MenuBarView(feed: feed) {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else {
                Button("Open Redwing") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Divider()
                Text("Setup required")
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let session = rootModel.accountSession,
           let spaces = rootModel.spacesCoordinator,
           let messages = rootModel.messagesCoordinator,
           let attention = rootModel.attentionFeed {
            VStack(spacing: 0) {
                LaneSurfaceView(spaces: spaces, messages: messages)
                StatusBarView(
                    realtime: session.realtimeStatus,
                    token: session.tokenStatus,
                    spaces: spaces.status,
                    messages: messages.status,
                    attention: attention.status,
                    onShowDiagnostics: { isShowingDiagnostics = true }
                )
            }
            .task {
                await session.start()
                await spaces.start()
            }
        } else {
            SetupView { credentials in
                Task {
                    await rootModel.accountSession?.authorize(credentials: credentials)
                    await rootModel.spacesCoordinator?.start()
                }
            }
        }
    }
}
```

Update `SetupView` handler in `RedwingApp`:

```swift
SetupView { credentials in
    Task {
        await rootModel.accountSession?.authorize(credentials: credentials)
        await rootModel.spacesCoordinator?.start()
    }
}
```

- [ ] **Step 4: Build against SDK**

Run:

```bash
xcodebuild build \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds and resolves local `WebexSwiftSDK`.

- [ ] **Step 5: Commit SDK adapter**

Run:

```bash
git add Redwing/Account Redwing/App
git commit -m "feat: connect redwing to webex sdk"
```

## Task 13: Final Verification And Manual Smoke

**Files:**
- Modify as needed only for compile/test fixes discovered by verification.

- [ ] **Step 1: Run all tests**

Run:

```bash
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all Redwing unit tests pass.

- [ ] **Step 2: Run app build**

Run:

```bash
xcodebuild build \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS'
```

Expected: app target builds with local development signing.

- [ ] **Step 3: Run manual app smoke**

Launch from Xcode or with the built app. Verify:

- setup screen appears on first launch
- empty credentials show local validation errors
- OAuth button opens the browser
- successful auth starts shared realtime and Spaces loading
- Spaces lane shows skeletons before first snapshot
- selecting a space creates one shared message/thread stream
- standalone selected message keeps Thread lane hidden
- threaded selected message reveals Thread lane
- menu bar opens and shows attention feed empty state or attention items
- status bar indicators show WebSocket/token/stream state
- diagnostics panel opens, accumulates redacted session entries, and clears
- Dock/menu bar activation brings the app to the current desktop/display

- [ ] **Step 4: Check git state**

Run:

```bash
git status --short --branch
```

Expected: clean except intentionally ignored local files such as `.superpowers/`.

- [ ] **Step 5: Commit final verification fixes if any**

If verification required changes, commit them:

```bash
git add Redwing RedwingTests redwing.xcodeproj
git commit -m "fix: stabilize redwing foundation verification"
```

Expected: no commit is created if no fixes were needed.

## Self-Review

Spec coverage:

- Xcode app scaffold: Task 1
- local SDK v2.5.0 dependency: Tasks 1 and 12
- native setup screen: Tasks 3 and 10
- one active account: Task 5
- shared realtime connection: Tasks 5 and 12
- Spaces -> Messages -> conditional Threads lanes: Tasks 6, 7, 9, 10
- shared Messages/Threads stream: Task 7
- attention-only menu bar feed: Tasks 8 and 10
- thin status bar and diagnostics: Tasks 2 and 10
- skeleton loading: Tasks 6, 7, 9, 10
- focus-following window behavior: Task 11
- no message disk cache and no direct REST calls: enforced by architecture and Task 12 adapter boundary
- strict tests: Tasks 1 through 13

Placeholder scan: no forbidden placeholder markers or unspecified edge handling remains.

Type consistency: DTOs are defined in Task 4 before use by later coordinators. `SessionStatus`, `DiagnosticsStore`, and coordinator property names match their tests. `MessagesCoordinator` and `ThreadLanePolicy` use the same `MessageThreadEntryDTO` fields defined in Task 4.
