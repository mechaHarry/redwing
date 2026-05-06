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
