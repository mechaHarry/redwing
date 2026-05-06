import AppKit
import Foundation
import WebexSwiftSDK

actor WebexSDKAdapter: WebexClientProviding {
    private static let keychainService = "com.mechaharry.redwing.webex"

    private let registry: WebexClientRegistry
    private let openAuthorizationURL: @Sendable (URL) async throws -> Void

    private var client: WebexClient?
    private var activeAccountID: WebexAccountID?
    private var realtimeConnection: WebexRealtimeConnection?

    init(
        registry: WebexClientRegistry = WebexClientRegistry(
            store: KeychainWebexStore(service: keychainService)
        ),
        openAuthorizationURL: @escaping @Sendable (URL) async throws -> Void = { url in
            try await WebexSDKAdapter.openAuthorizationURLInWorkspace(url)
        }
    ) {
        self.registry = registry
        self.openAuthorizationURL = openAuthorizationURL
    }

    func existingAccount() async throws -> WebexAccountSummary? {
        guard let account = try await registry.listAccounts().first else {
            return nil
        }

        let loadedClient = try await registry.client(for: account.id)
        let summary = try await accountSummary(for: account, client: loadedClient, grantedScopes: [])
        client = loadedClient
        activeAccountID = account.id
        return summary
    }

    func authorize(credentials: SetupCredentials) async throws -> WebexAccountSummary {
        try SetupValidation.validate(credentials)

        let configuration = try Self.configuration(from: credentials)
        let authorized = try await registry.authorizeAndAddAccount(
            configuration: configuration,
            openAuthorizationURL: openAuthorizationURL
        )

        do {
            let summary = try await accountSummary(
                for: authorized.account,
                client: authorized.client,
                grantedScopes: configuration.scopes
            )
            client = authorized.client
            activeAccountID = authorized.account.id
            return summary
        } catch {
            try? await registry.removeAccount(authorized.account.id)
            throw error
        }
    }

    func startRealtime() async -> AsyncStream<RealtimeStateDTO> {
        cancelRealtime()

        guard let client else {
            return AsyncStream { continuation in
                continuation.yield(.failed("No active Webex account"))
                continuation.finish()
            }
        }

        let connection = client.realtime.connect()
        realtimeConnection = connection
        return connection.states.mapped { state in
            Self.mapRealtimeState(state)
        }
    }

    func makeSpacesStream() async throws -> SpacesStreamProviding {
        guard let client else {
            throw WebexSDKError.network("No active Webex account")
        }

        let stream = client.spaces.stream(
            params: ListSpacesParams(sortBy: .lastActivity, max: 40),
            pageLimit: 3
        )
        return WebexSDKSpacesStreamAdapter(stream: stream, triggers: realtimeConnection?.triggers)
    }

    func makeMessagesThreadStream(spaceID: String) async throws -> MessagesThreadStreamProviding {
        guard let client else {
            throw WebexSDKError.network("No active Webex account")
        }

        let stream = client.messages.threadedStream(
            params: ListMessagesParams(roomID: spaceID, max: 50),
            pageLimit: 2
        )
        return WebexSDKMessagesThreadStreamAdapter(
            stream: stream,
            spaceID: spaceID,
            triggers: realtimeConnection?.triggers
        )
    }

    func signOut() async throws {
        let accountID = activeAccountID
        cancelRealtime()

        guard let accountID else {
            client = nil
            return
        }

        try await registry.removeAccount(accountID)
        client = nil
        activeAccountID = nil
    }

    private func cancelRealtime() {
        realtimeConnection?.cancel()
        realtimeConnection = nil
    }

    private static func configuration(from credentials: SetupCredentials) throws -> WebexIntegrationConfiguration {
        guard let redirectURI = URL(string: credentials.redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SetupValidation.ValidationError.invalidRedirectURI
        }

        return WebexIntegrationConfiguration(
            clientID: credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: credentials.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
            redirectURI: redirectURI,
            scopes: credentials.scopes
        )
    }

    private static func openAuthorizationURLInWorkspace(_ url: URL) async throws {
        try await MainActor.run {
            guard NSWorkspace.shared.open(url) else {
                throw WebexSDKError.network("Authorization URL could not be opened")
            }
        }
    }

    private func accountSummary(
        for record: WebexAccountRecord,
        client: WebexClient,
        grantedScopes: [String]
    ) async throws -> WebexAccountSummary {
        do {
            let person = try await client.people.me()
            return Self.mapCurrentPerson(person, grantedScopes: grantedScopes)
        } catch {
            return try Self.mapAccountAfterCurrentPersonLookupFailure(
                record,
                grantedScopes: grantedScopes
            )
        }
    }

    static func mapAccount(
        _ record: WebexAccountRecord,
        grantedScopes: [String] = []
    ) -> WebexAccountSummary {
        WebexAccountSummary(
            id: record.metadata.webexUserID ?? record.id.rawValue,
            displayName: record.metadata.displayName
                ?? record.metadata.email
                ?? record.metadata.webexUserID
                ?? "Webex Account",
            grantedScopes: grantedScopes
        )
    }

    static func mapAccountAfterCurrentPersonLookupFailure(
        _ record: WebexAccountRecord,
        grantedScopes: [String] = []
    ) throws -> WebexAccountSummary {
        guard record.metadata.webexUserID != nil else {
            throw WebexSDKError.network("Current Webex profile could not be loaded")
        }

        return mapAccount(record, grantedScopes: grantedScopes)
    }

    static func mapCurrentPerson(
        _ person: WebexPerson,
        grantedScopes: [String] = []
    ) -> WebexAccountSummary {
        WebexAccountSummary(
            id: person.id,
            displayName: nonEmpty(person.displayName)
                ?? person.emails.compactMap { nonEmpty($0) }.first
                ?? person.id,
            grantedScopes: grantedScopes
        )
    }

    static func mapRealtimeState(_ state: WebexRealtimeConnectionState) -> RealtimeStateDTO {
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
            return .failed(redacted(String(describing: error)))
        }
    }

    static func mapSpaceSnapshot(_ snapshot: WebexStreamSnapshot<WebexSpace>) -> SpaceSnapshot {
        SpaceSnapshot(
            spaces: snapshot.items.map { space in
                SpaceItem(
                    id: space.id,
                    title: nonEmpty(space.title) ?? "Untitled Space",
                    lastActivity: space.lastActivity
                )
            },
            isRefreshing: snapshot.isRefreshing,
            isLoadingNextPage: snapshot.isLoadingNextPage,
            hasMore: snapshot.pagination.hasMore,
            lastErrorDescription: snapshot.lastError.map { redacted(String(describing: $0)) }
        )
    }

    static func mapMessageThreadSnapshot(_ snapshot: WebexMessageThreadSnapshot) -> MessageThreadSnapshotDTO {
        MessageThreadSnapshotDTO(
            topLevelMessageIDs: snapshot.topLevelMessageIDs,
            entriesByID: snapshot.threadEntryByID.mapValues(mapMessageThreadEntry),
            isRefreshing: snapshot.isRefreshing,
            isLoadingNextPage: snapshot.isLoadingNextPage,
            hasMore: snapshot.pagination.hasMore,
            lastErrorDescription: snapshot.lastError.map { redacted(String(describing: $0)) }
        )
    }

    private static func mapMessageThreadEntry(_ entry: WebexMessageThreadEntry) -> MessageThreadEntryDTO {
        let message = entry.message
        return MessageThreadEntryDTO(
            id: entry.id,
            parentID: entry.parentID,
            childIDs: entry.childIDs,
            sender: nonEmpty(message?.personEmail) ?? nonEmpty(message?.personID) ?? "Unknown sender",
            body: nonEmpty(message?.text) ?? nonEmpty(message?.markdown) ?? nonEmpty(message?.html) ?? "",
            created: entry.effectiveCreated,
            mentionedPeople: message?.mentionedPeople ?? [],
            mentionedGroups: message?.mentionedGroups ?? [],
            isPlaceholderParent: entry.isPlaceholderParent,
            isDeletedTombstone: entry.isDeletedTombstone
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func redacted(_ value: String) -> String {
        var redacted = value
        let patterns = [
            (#"(?i)\b(client_secret|access_token|refresh_token|id_token|code_verifier)\b\s*[:=]\s*[^&\s,;]+"#, "$1=[redacted]"),
            (#"(?i)\bAuthorization\b\s*[:=]\s*[^\r\n,;]+"#, "Authorization=[redacted]"),
            (#"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+"#, "Bearer [redacted]")
        ]

        for (pattern, replacement) in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(location: 0, length: (redacted as NSString).length)
            redacted = expression.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: replacement
            )
        }

        return redacted
    }
}

final class WebexSDKSpacesStreamAdapter: SpacesStreamProviding {
    private let stream: SpacesStream
    private let triggerTask: Task<Void, Never>?

    var snapshots: AsyncStream<SpaceSnapshot> {
        stream.snapshots.mapped { snapshot in
            WebexSDKAdapter.mapSpaceSnapshot(snapshot)
        }
    }

    init(stream: SpacesStream, triggers: AsyncStream<WebexStreamTrigger>?) {
        self.stream = stream
        self.triggerTask = triggers.map { triggers in
            stream.refreshOnTriggers(triggers) { trigger in
                Self.shouldRefresh(for: trigger)
            }
        }
    }

    deinit {
        cancel()
    }

    func refresh() async {
        await stream.refresh()
    }

    func loadNextPage() async {
        await stream.loadNextPage()
    }

    func cancel() {
        triggerTask?.cancel()
    }

    static func shouldRefresh(for trigger: WebexStreamTrigger) -> Bool {
        trigger.resource == WebexRealtimeResource.spaces.rawValue
    }
}

final class WebexSDKMessagesThreadStreamAdapter: MessagesThreadStreamProviding {
    private let stream: MessagesThreadStream
    private let spaceID: String
    private let triggerTask: Task<Void, Never>?

    var snapshots: AsyncStream<MessageThreadSnapshotDTO> {
        stream.snapshots.mapped { snapshot in
            WebexSDKAdapter.mapMessageThreadSnapshot(snapshot)
        }
    }

    init(
        stream: MessagesThreadStream,
        spaceID: String,
        triggers: AsyncStream<WebexStreamTrigger>?
    ) {
        self.stream = stream
        self.spaceID = spaceID
        self.triggerTask = triggers.map { triggers in
            stream.refreshOnTriggers(triggers) { trigger in
                Self.shouldRefresh(for: trigger, spaceID: spaceID)
            }
        }
    }

    deinit {
        cancel()
    }

    func refresh() async {
        await stream.refresh()
    }

    func loadNextPage() async {
        await stream.loadNextPage()
    }

    func cancel() {
        triggerTask?.cancel()
    }

    static func shouldRefresh(for trigger: WebexStreamTrigger, spaceID: String) -> Bool {
        trigger.resource == WebexRealtimeResource.messages.rawValue && trigger.roomID == spaceID
    }
}
