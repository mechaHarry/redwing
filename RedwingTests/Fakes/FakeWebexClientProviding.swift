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
