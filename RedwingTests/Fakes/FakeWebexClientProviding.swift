import Foundation
@testable import Redwing

private final class LockIsolated<Value>: @unchecked Sendable {
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

private struct FakeStreamState {
    var refreshCount = 0
    var loadNextPageCount = 0
    var isCancelled = false
}

final class FakeSpacesStream: SpacesStreamProviding {
    let probe = StreamProbe<SpaceSnapshot>()
    private let state = LockIsolated(FakeStreamState())

    private(set) var refreshCount: Int {
        get { state.withValue { $0.refreshCount } }
        set { state.withValue { $0.refreshCount = newValue } }
    }

    private(set) var loadNextPageCount: Int {
        get { state.withValue { $0.loadNextPageCount } }
        set { state.withValue { $0.loadNextPageCount = newValue } }
    }

    private(set) var isCancelled: Bool {
        get { state.withValue { $0.isCancelled } }
        set { state.withValue { $0.isCancelled = newValue } }
    }

    var snapshots: AsyncStream<SpaceSnapshot> { probe.stream }

    func refresh() async {
        state.withValue { $0.refreshCount += 1 }
    }

    func loadNextPage() async {
        state.withValue { $0.loadNextPageCount += 1 }
    }

    func cancel() {
        state.withValue { $0.isCancelled = true }
    }
}

final class FakeMessagesThreadStream: MessagesThreadStreamProviding {
    let probe = StreamProbe<MessageThreadSnapshotDTO>()
    private let state = LockIsolated(FakeStreamState())

    private(set) var refreshCount: Int {
        get { state.withValue { $0.refreshCount } }
        set { state.withValue { $0.refreshCount = newValue } }
    }

    private(set) var loadNextPageCount: Int {
        get { state.withValue { $0.loadNextPageCount } }
        set { state.withValue { $0.loadNextPageCount = newValue } }
    }

    private(set) var isCancelled: Bool {
        get { state.withValue { $0.isCancelled } }
        set { state.withValue { $0.isCancelled = newValue } }
    }

    var snapshots: AsyncStream<MessageThreadSnapshotDTO> { probe.stream }

    func refresh() async {
        state.withValue { $0.refreshCount += 1 }
    }

    func loadNextPage() async {
        state.withValue { $0.loadNextPageCount += 1 }
    }

    func cancel() {
        state.withValue { $0.isCancelled = true }
    }
}

private struct FakeWebexClientState {
    var account: WebexAccountSummary?
    var authorizeResult: Result<WebexAccountSummary, Error>?
    var spacesStream = FakeSpacesStream()
    var messagesStreamsBySpaceID: [String: FakeMessagesThreadStream] = [:]
    var didStartRealtime = false
    var didSignOut = false
}

final class FakeWebexClientProviding: WebexClientProviding {
    let realtimeProbe = StreamProbe<RealtimeStateDTO>()
    private let state = LockIsolated(FakeWebexClientState())

    var account: WebexAccountSummary? {
        get { state.withValue { $0.account } }
        set { state.withValue { $0.account = newValue } }
    }

    var authorizeResult: Result<WebexAccountSummary, Error>? {
        get { state.withValue { $0.authorizeResult } }
        set { state.withValue { $0.authorizeResult = newValue } }
    }

    var spacesStream: FakeSpacesStream {
        get { state.withValue { $0.spacesStream } }
        set { state.withValue { $0.spacesStream = newValue } }
    }

    var messagesStreamsBySpaceID: [String: FakeMessagesThreadStream] {
        get { state.withValue { $0.messagesStreamsBySpaceID } }
        set { state.withValue { $0.messagesStreamsBySpaceID = newValue } }
    }

    private(set) var didStartRealtime: Bool {
        get { state.withValue { $0.didStartRealtime } }
        set { state.withValue { $0.didStartRealtime = newValue } }
    }

    private(set) var didSignOut: Bool {
        get { state.withValue { $0.didSignOut } }
        set { state.withValue { $0.didSignOut = newValue } }
    }

    func existingAccount() async throws -> WebexAccountSummary? {
        account
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        try state.withValue { state in
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
        state.withValue { $0.didStartRealtime = true }
        return realtimeProbe.stream
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        spacesStream
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        state.withValue { state in
            if let stream = state.messagesStreamsBySpaceID[spaceID] {
                return stream
            }
            let stream = FakeMessagesThreadStream()
            state.messagesStreamsBySpaceID[spaceID] = stream
            return stream
        }
    }

    func signOut() async {
        state.withValue { $0.didSignOut = true }
    }
}
