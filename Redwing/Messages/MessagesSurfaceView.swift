import Combine
import SwiftUI

struct MessagesSurfaceView: View {
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var navigation: SessionNavigationState
    let onClose: () -> Void

    @State private var visibleMessageID: String?

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
        let rowIDs = messages.messageRows.map(\.id)

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
            .animation(.easeInOut(duration: 0.22), value: messages.messageRows)
            .animation(.easeInOut(duration: 0.2), value: messages.footerState)
            .onAppear {
                restoreVisibleMessage(rowIDs: rowIDs)
            }
            .onChange(of: messages.selectedSpaceID) { _, _ in
                visibleMessageID = nil
                restoreVisibleMessage(rowIDs: messages.messageRows.map(\.id))
            }
            .onChange(of: visibleMessageID) { _, id in
                rememberVisibleMessage(id: id)
            }
            .onChange(of: rowIDs) { _, newIDs in
                guard let visibleMessageID, !newIDs.contains(visibleMessageID) else {
                    return
                }
                restoreVisibleMessage(rowIDs: newIDs)
            }
            .onReceive(messages.$messageScrollRequest.compactMap { $0 }) { request in
                scroll(proxy, to: request.targetID)
            }
        }
    }

    private func restoreVisibleMessage(rowIDs: [String]) {
        guard let spaceID = messages.selectedSpaceID else {
            return
        }

        if let restored = navigation.restoredMessageID(spaceID: spaceID, rowIDs: rowIDs) {
            visibleMessageID = restored
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

    private func scroll(_ proxy: ScrollViewProxy, to targetID: String) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        }
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
        .animation(.easeInOut(duration: 0.2), value: row)
    }
}
