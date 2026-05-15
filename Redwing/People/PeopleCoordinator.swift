import Combine
import Foundation

@MainActor
final class PeopleCoordinator: ObservableObject {
    static let skeletonNodeCount = 3

    @Published private(set) var nodes: [PersonNodeViewModel] = (0..<skeletonNodeCount).map(PersonNodeViewModel.skeleton)
    @Published private(set) var status: SessionStatus = .idle
    @Published private(set) var isShowingSkeletons = true

    private let session: AccountSession?
    private let diagnostics: DiagnosticsStore
    private var task: Task<Void, Never>?
    private var generation = 0

    init(session: AccountSession?, diagnostics: DiagnosticsStore) {
        self.session = session
        self.diagnostics = diagnostics
    }

    deinit {
        task?.cancel()
    }

    func start() async {
        guard let session else { return }
        generation += 1
        let generation = generation
        task?.cancel()
        status = .refreshing
        isShowingSkeletons = true
        nodes = (0..<Self.skeletonNodeCount).map(PersonNodeViewModel.skeleton)

        do {
            let chain = try await session.loadManagerChain()
            guard isCurrent(generation) else { return }
            apply(chain: chain)
        } catch {
            guard isCurrent(generation) else { return }
            status = .failed("People unavailable")
            diagnostics.append(source: .auth, severity: .error, message: "People manager chain failed", detail: String(describing: error))
        }
    }

    func apply(chain: [PersonItem]) {
        nodes = chain.reversed().map { person in
            PersonNodeViewModel(
                id: person.id,
                name: person.displayName,
                subtitle: Self.subtitle(for: person),
                avatarState: person.avatarURL.map(SpaceAvatarState.remote) ?? .directPlaceholder,
                isSkeleton: false
            )
        }
        status = .connected
        isShowingSkeletons = false
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation
    }

    private static func subtitle(for person: PersonItem) -> String? {
        [nonEmpty(person.title), nonEmpty(person.department)]
            .compactMap { $0 }
            .joined(separator: " - ")
            .nilIfEmpty
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
