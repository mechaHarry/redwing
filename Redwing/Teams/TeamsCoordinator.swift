import Combine
import Foundation

@MainActor
final class TeamsCoordinator: ObservableObject {
    static let skeletonRowCount = 8

    @Published private(set) var rows: [TeamRowViewModel] = (0..<skeletonRowCount).map(TeamRowViewModel.skeleton)
    @Published private(set) var selectedTeamID: String?
    @Published private(set) var status: SessionStatus = .idle
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var isShowingSkeletons = true

    var footerState: LanePaginationFooterState? {
        guard !isShowingSkeletons else {
            return nil
        }

        return hasMore || isLoadingNextPage ? .searching : .allFound
    }

    private let session: AccountSession?
    private let diagnostics: DiagnosticsStore
    private var stream: TeamsStreamProviding?
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
            let stream = try await session.makeTeamsStream()
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
            status = .failed("Teams unavailable")
            diagnostics.append(source: .spaces, severity: .error, message: "Teams stream failed", detail: String(describing: error))
        }
    }

    func apply(snapshot: TeamSnapshot) {
        apply(snapshot: snapshot, generation: generation)
    }

    func select(teamID: String) {
        selectedTeamID = teamID
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

    func loadNextPageFromFooterIfNeeded() async {
        guard hasMore,
              !isLoadingNextPage,
              let stream else {
            return
        }

        isLoadingNextPage = true
        await stream.loadNextPage()
    }

    private func apply(snapshot: TeamSnapshot, generation: Int) {
        guard isCurrent(generation) else { return }

        hasMore = snapshot.hasMore
        isLoadingNextPage = snapshot.isLoadingNextPage
        status = snapshot.lastErrorDescription.map { _ in SessionStatus.failed("Teams refresh failed") } ?? (snapshot.isRefreshing ? .refreshing : .connected)
        if let error = snapshot.lastErrorDescription {
            diagnostics.append(source: .spaces, severity: .error, message: "Teams refresh failed", detail: error)
        }

        guard !snapshot.teams.isEmpty else {
            rows = snapshot.isRefreshing ? rows : []
            isShowingSkeletons = snapshot.isRefreshing
            return
        }

        rows = snapshot.teams.map { team in
            TeamRowViewModel(
                id: team.id,
                name: team.name,
                creatorLabel: Self.creatorLabel(for: team),
                createdLabel: Self.dateLabel(prefix: "Created", date: team.created),
                isSkeleton: false
            )
        }
        isShowingSkeletons = false
    }

    private func subscribe(to stream: TeamsStreamProviding, generation: Int) {
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

    private static func creatorLabel(for team: TeamItem) -> String {
        guard let creatorID = nonEmpty(team.creatorID) else {
            return "Creator unknown"
        }

        return "Creator \(creatorID)"
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
