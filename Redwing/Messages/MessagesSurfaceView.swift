import Combine
import SwiftUI

struct MessageScrollArbiter {
    enum Resolution: Equatable {
        case restore(id: String, consuming: LaneScrollRequest.ID?)
        case scroll(id: String, requestID: LaneScrollRequest.ID)
        case consume(requestID: LaneScrollRequest.ID)
        case none
    }

    static func resolve(
        currentSpaceID: String?,
        realRowIDs: [String],
        restoredID: String?,
        request: LaneScrollRequest?
    ) -> Resolution {
        if let request, request.spaceID != currentSpaceID {
            return .consume(requestID: request.id)
        }

        guard !realRowIDs.isEmpty else {
            return .none
        }

        if let restoredID, realRowIDs.contains(restoredID) {
            return .restore(id: restoredID, consuming: request?.id)
        }

        guard let request else {
            return .none
        }

        guard realRowIDs.contains(request.targetID) else {
            return .consume(requestID: request.id)
        }

        return .scroll(id: request.targetID, requestID: request.id)
    }
}

@MainActor
final class MessageScrollRequestExecutor {
    private var task: Task<Void, Never>?

    func submitAfterMutation(_ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            await Task.yield()

            guard !Task.isCancelled else {
                return
            }

            action()
        }
    }

    func submit(
        isCurrent: @escaping @MainActor () -> Bool,
        action: @escaping @MainActor () -> Void,
        acknowledge: @escaping @MainActor () -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            await Task.yield()

            guard !Task.isCancelled else {
                return
            }

            guard isCurrent() else {
                guard !Task.isCancelled else {
                    return
                }
                acknowledge()
                return
            }

            action()
            await Task.yield()

            guard !Task.isCancelled else {
                return
            }

            acknowledge()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
struct MessagesSurfaceView: View {
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var navigation: SessionNavigationState
    let onClose: () -> Void

    @State private var visibleMessageID: String?
    @State private var scrollExecutor = MessageScrollRequestExecutor()

    var body: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        VStack(spacing: 0) {
            header
            Divider()
                .opacity(0.45)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(paneShape)
        .glassEffect(.regular, in: paneShape)
        .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .leading)))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(messages.selectedSpaceTitle ?? "Messages")
                .font(.headline)
                .lineLimit(1)
                .contentTransition(.opacity)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Close Messages")
            .accessibilityLabel("Close Messages")
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.45)
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .failed = messages.status {
            ContentUnavailableView {
                Label("Messages unavailable", systemImage: "exclamationmark.bubble")
            } description: {
                Text("The message timeline could not be refreshed.")
            } actions: {
                Button("Retry") {
                    Task {
                        await messages.retry()
                    }
                }
                .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            timeline
        }
    }

    private var timeline: some View {
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 10) {
                    ForEach(messages.messageRows) { row in
                        MessageTimelineRow(row: row)
                            .id(row.id)
                            .transition(.opacity)
                    }

                    if let footerState = messages.footerState {
                        LanePaginationFooter(state: footerState)
                            .onAppear {
                                Task {
                                    await messages.loadNextPageFromFooterIfNeeded()
                                }
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(16)
            }
            .scrollPosition(id: $visibleMessageID, anchor: .center)
            .onAppear {
                resolveScrollDestination(proxy: proxy, request: messages.messageScrollRequest)
            }
            .onChange(of: messages.selectedSpaceID) { _, _ in
                visibleMessageID = nil
                resolveScrollDestination(proxy: proxy, request: messages.messageScrollRequest)
            }
            .onChange(of: visibleMessageID) { _, id in
                rememberVisibleMessage(id: id)
            }
            .onChange(of: messages.messageRows.map(\.id)) { _, _ in
                resolveScrollDestination(proxy: proxy, request: messages.messageScrollRequest)
            }
            .onReceive(messages.$messageScrollRequest.compactMap { $0 }) { publishedRequest in
                scrollExecutor.submitAfterMutation {
                    guard let storedRequest = messages.messageScrollRequest,
                          storedRequest.id == publishedRequest.id else {
                        return
                    }

                    resolveScrollDestination(proxy: proxy, request: storedRequest)
                }
            }
            .onDisappear {
                scrollExecutor.cancel()
            }
        }
    }

    private func resolveScrollDestination(
        proxy: ScrollViewProxy,
        request: LaneScrollRequest?
    ) {
        let realRowIDs = messages.isShowingSkeletons ? [] : messages.messageRows.map(\.id)
        let restoredID = messages.selectedSpaceID.flatMap {
            navigation.restoredMessageID(spaceID: $0, rowIDs: realRowIDs)
        }
        let resolution = MessageScrollArbiter.resolve(
            currentSpaceID: messages.selectedSpaceID,
            realRowIDs: realRowIDs,
            restoredID: restoredID,
            request: request
        )

        switch resolution {
        case .restore(let id, let requestID):
            scrollExecutor.cancel()
            if visibleMessageID != id {
                visibleMessageID = id
            }
            if let requestID {
                messages.acknowledgeMessageScrollRequest(id: requestID)
            }
        case .scroll(let id, let requestID):
            scroll(proxy, to: id, requestID: requestID)
        case .consume(let requestID):
            scrollExecutor.cancel()
            messages.acknowledgeMessageScrollRequest(id: requestID)
        case .none:
            break
        }
    }

    private func rememberVisibleMessage(id: String?) {
        guard let spaceID = messages.selectedSpaceID,
              let id,
              let index = messages.messageRows.firstIndex(where: { $0.id == id }),
              !messages.messageRows[index].isSkeleton else {
            return
        }

        navigation.rememberMessageAnchor(spaceID: spaceID, id: id, index: index)
    }

    private func scroll(
        _ proxy: ScrollViewProxy,
        to targetID: String,
        requestID: LaneScrollRequest.ID
    ) {
        scrollExecutor.submit(
            isCurrent: {
                guard let request = messages.messageScrollRequest else {
                    return false
                }

                return request.id == requestID
                    && request.spaceID == messages.selectedSpaceID
                    && request.targetID == targetID
                    && messages.messageRows.contains(where: {
                        !$0.isSkeleton && $0.id == targetID
                    })
            },
            action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(targetID, anchor: .bottom)
                }
            },
            acknowledge: {
                messages.acknowledgeMessageScrollRequest(id: requestID)
            }
        )
    }
}

private struct MessageTimelineRow: View {
    let row: MessageRowViewModel

    var body: some View {
        let rowShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        Group {
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.sender)
                            .font(.headline)
                            .lineLimit(1)
                            .contentTransition(.opacity)

                        Spacer(minLength: 0)

                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }

                    Text(row.body)
                        .foregroundStyle(row.isDeletedTombstone ? .secondary : .primary)
                        .strikethrough(row.isDeletedTombstone)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                }
                .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .glassEffect(.regular, in: rowShape)
    }
}
