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

enum SpaceTypeDTO: Equatable, Sendable {
    case direct
    case group
    case unknown(String)
}

struct SpacePartialResourceErrorDTO: Equatable, Sendable {
    let code: String
    let reason: String
}

struct SpaceItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let type: SpaceTypeDTO?
    let isLocked: Bool?
    let teamID: String?
    let teamName: String?
    let lastActivity: Date?
    let creatorID: String?
    let created: Date?
    let ownerID: String?
    let description: String?
    let isPublic: Bool?
    let isReadOnly: Bool?
    let isAnnouncementOnly: Bool?
    let classificationID: String?
    let madePublic: Date?
    let iconURL: URL?
    let errors: [String: SpacePartialResourceErrorDTO]?

    init(
        id: String,
        title: String,
        type: SpaceTypeDTO? = nil,
        isLocked: Bool? = nil,
        teamID: String? = nil,
        teamName: String? = nil,
        lastActivity: Date? = nil,
        creatorID: String? = nil,
        created: Date? = nil,
        ownerID: String? = nil,
        description: String? = nil,
        isPublic: Bool? = nil,
        isReadOnly: Bool? = nil,
        isAnnouncementOnly: Bool? = nil,
        classificationID: String? = nil,
        madePublic: Date? = nil,
        iconURL: URL? = nil,
        errors: [String: SpacePartialResourceErrorDTO]? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.isLocked = isLocked
        self.teamID = teamID
        self.teamName = teamName
        self.lastActivity = lastActivity
        self.creatorID = creatorID
        self.created = created
        self.ownerID = ownerID
        self.description = description
        self.isPublic = isPublic
        self.isReadOnly = isReadOnly
        self.isAnnouncementOnly = isAnnouncementOnly
        self.classificationID = classificationID
        self.madePublic = madePublic
        self.iconURL = iconURL
        self.errors = errors
    }
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
    func signOut() async throws
}
