import Combine
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
                self?.apply(snapshot: snapshot)
            }
        }
    }
}
