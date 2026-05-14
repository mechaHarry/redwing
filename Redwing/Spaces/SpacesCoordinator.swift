import Combine
import Foundation

@MainActor
final class SpacesCoordinator: ObservableObject {
    static let skeletonRowCount = 8

    @Published private(set) var rows: [SpaceRowViewModel] = (0..<skeletonRowCount).map(SpaceRowViewModel.skeleton)
    @Published private(set) var selectedSpaceID: String?
    @Published private(set) var status: SessionStatus = .idle
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var isShowingSkeletons = true

    private let session: AccountSession?
    private let diagnostics: DiagnosticsStore
    private var stream: SpacesStreamProviding?
    private var task: Task<Void, Never>?
    private var generation = 0

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
        let generation = replaceStreamState()
        do {
            let stream = try await session.makeSpacesStream()
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
            status = .failed("Spaces unavailable")
            diagnostics.append(source: .spaces, severity: .error, message: "Spaces stream failed", detail: String(describing: error))
        }
    }

    func apply(snapshot: SpaceSnapshot) {
        apply(snapshot: snapshot, generation: generation)
    }

    func select(spaceID: String) {
        selectedSpaceID = spaceID
    }

    func loadNextPage() async {
        await stream?.loadNextPage()
    }

    func loadNextPageIfNeeded(visibleRowID: String) async {
        guard rows.last?.id == visibleRowID,
              hasMore,
              !isLoadingNextPage,
              let stream else {
            return
        }

        isLoadingNextPage = true
        await stream.loadNextPage()
    }

    private func apply(snapshot: SpaceSnapshot, generation: Int) {
        guard isCurrent(generation) else { return }

        hasMore = snapshot.hasMore
        isLoadingNextPage = snapshot.isLoadingNextPage
        status = snapshot.lastErrorDescription.map { _ in SessionStatus.failed("Spaces refresh failed") } ?? (snapshot.isRefreshing ? .refreshing : .connected)
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
                teamLabel: Self.teamLabel(for: space),
                typeLabel: Self.typeLabel(for: space.type),
                createdLabel: Self.dateLabel(prefix: "Created", date: space.created),
                lastActivityLabel: Self.dateLabel(prefix: "Last active", date: space.lastActivity),
                iconURL: space.iconURL,
                isSkeleton: false
            )
        }
        isShowingSkeletons = false
    }

    private func subscribe(to stream: SpacesStreamProviding, generation: Int) {
        task?.cancel()
        task = Task { [weak self] in
            for await snapshot in stream.snapshots {
                self?.apply(snapshot: snapshot, generation: generation)
            }
        }
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

    private static func teamLabel(for space: SpaceItem) -> String {
        if let teamName = nonEmpty(space.teamName) {
            return teamName
        }

        if let teamID = nonEmpty(space.teamID) {
            return teamID
        }

        if space.type == .direct {
            return "Direct Message"
        }

        return "No team"
    }

    private static func typeLabel(for type: SpaceTypeDTO?) -> String {
        switch type {
        case .direct:
            return "Direct"
        case .group:
            return "Group"
        case .unknown(let value):
            return value.isEmpty ? "Unknown" : "Unknown: \(value)"
        case nil:
            return "Unknown"
        }
    }

    private static func dateLabel(prefix: String, date: Date?) -> String {
        guard let date else {
            return "\(prefix) unknown"
        }

        return "\(prefix) \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
