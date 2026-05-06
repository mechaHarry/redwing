import Combine
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

    private let session: AccountSession?
    private let diagnostics: DiagnosticsStore
    private let attentionFeed: AttentionFeedStore?
    private var stream: MessagesThreadStreamProviding?
    private var task: Task<Void, Never>?
    private var latestSnapshot: MessageThreadSnapshotDTO?
    private var selectedSpaceTitle: String?
    private var generation = 0

    init(
        session: AccountSession?,
        diagnostics: DiagnosticsStore,
        attentionFeed: AttentionFeedStore? = nil
    ) {
        self.session = session
        self.diagnostics = diagnostics
        self.attentionFeed = attentionFeed
    }

    deinit {
        task?.cancel()
        stream?.cancel()
    }

    func select(spaceID: String, spaceTitle: String? = nil) async {
        guard selectedSpaceID != spaceID else {
            selectedSpaceTitle = spaceTitle ?? selectedSpaceTitle
            return
        }

        let generation = replaceStreamState()
        selectedSpaceID = spaceID
        selectedSpaceTitle = spaceTitle ?? spaceID
        selectedMessageID = nil
        latestSnapshot = nil
        threadRows = []
        isThreadLaneVisible = false
        isShowingSkeletons = true
        messageRows = (0..<Self.skeletonRowCount).map(MessageRowViewModel.skeleton)
        hasMore = false
        status = .refreshing

        guard let session else {
            status = .failed("Messages unavailable")
            return
        }

        do {
            let stream = try await session.makeMessagesThreadStream(spaceID: spaceID)
            guard isCurrent(generation) else {
                stream.cancel()
                return
            }

            self.stream = stream
            status = .refreshing
            subscribe(to: stream, generation: generation)
            await stream.refresh()
        } catch {
            guard isCurrent(generation) else { return }
            status = .failed("Messages unavailable")
            diagnostics.append(source: .messages, severity: .error, message: "Messages stream failed", detail: String(describing: error))
        }
    }

    func apply(snapshot: MessageThreadSnapshotDTO) {
        apply(snapshot: snapshot, generation: generation)
    }

    func select(messageID: String) {
        selectedMessageID = messageID
        rebuildThreadRows()
    }

    func loadNextPage() async {
        await stream?.loadNextPage()
    }

    private func apply(snapshot: MessageThreadSnapshotDTO, generation: Int) {
        guard isCurrent(generation) else { return }

        latestSnapshot = snapshot
        hasMore = snapshot.hasMore
        if let selectedSpaceID {
            attentionFeed?.apply(
                snapshot: snapshot,
                spaceID: selectedSpaceID,
                spaceTitle: selectedSpaceTitle ?? selectedSpaceID
            )
        }
        status = snapshot.lastErrorDescription.map { _ in SessionStatus.failed("Messages refresh failed") } ?? (snapshot.isRefreshing ? .refreshing : .connected)
        if let error = snapshot.lastErrorDescription {
            diagnostics.append(source: .messages, severity: .error, message: "Messages refresh failed", detail: error)
        }

        let rows = snapshot.topLevelMessageIDs.compactMap { id in
            snapshot.entriesByID[id].map { row(from: $0, depth: 0) }
        }

        guard !rows.isEmpty else {
            messageRows = snapshot.isRefreshing ? messageRows : []
            isShowingSkeletons = snapshot.isRefreshing
            rebuildThreadRows()
            return
        }

        messageRows = rows
        isShowingSkeletons = false
        rebuildThreadRows()
    }

    private func subscribe(to stream: MessagesThreadStreamProviding, generation: Int) {
        task?.cancel()
        task = Task { [weak self] in
            for await snapshot in stream.snapshots {
                self?.apply(snapshot: snapshot, generation: generation)
            }
        }
    }

    private func rebuildThreadRows() {
        guard let selectedMessageID,
              let snapshot = latestSnapshot,
              let selectedEntry = snapshot.entriesByID[selectedMessageID],
              ThreadLanePolicy.shouldShowThreadLane(for: selectedEntry)
        else {
            threadRows = []
            isThreadLaneVisible = false
            return
        }

        isThreadLaneVisible = true
        threadRows = walkThread(from: rootMessageID(for: selectedEntry, in: snapshot), in: snapshot, depth: 0, visited: [])
    }

    private func rootMessageID(for entry: MessageThreadEntryDTO, in snapshot: MessageThreadSnapshotDTO) -> String {
        var current = entry
        var visited: Set<String> = [entry.id]

        while let parentID = current.parentID,
              !visited.contains(parentID),
              let parent = snapshot.entriesByID[parentID] {
            visited.insert(parentID)
            current = parent
        }

        return current.id
    }

    private func walkThread(
        from id: String,
        in snapshot: MessageThreadSnapshotDTO,
        depth: Int,
        visited: Set<String>
    ) -> [MessageRowViewModel] {
        guard !visited.contains(id), let entry = snapshot.entriesByID[id] else {
            return []
        }

        let visited = visited.union([id])
        var rows = [row(from: entry, depth: depth)]
        for childID in entry.childIDs {
            rows.append(contentsOf: walkThread(from: childID, in: snapshot, depth: depth + 1, visited: visited))
        }
        return rows
    }

    private func row(from entry: MessageThreadEntryDTO, depth: Int) -> MessageRowViewModel {
        MessageRowViewModel(
            id: entry.id,
            sender: entry.sender,
            body: entry.body,
            detail: entry.created.map { "Sent \($0.formatted(date: .omitted, time: .shortened))" } ?? "",
            depth: depth,
            isSkeleton: false,
            isPlaceholderParent: entry.isPlaceholderParent,
            isDeletedTombstone: entry.isDeletedTombstone
        )
    }

    private func replaceStreamState() -> Int {
        generation += 1
        task?.cancel()
        task = nil
        stream?.cancel()
        stream = nil
        return generation
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation
    }
}
