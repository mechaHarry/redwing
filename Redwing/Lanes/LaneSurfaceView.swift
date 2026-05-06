import SwiftUI

struct LaneSurfaceView: View {
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator

    var body: some View {
        GeometryReader { geometry in
            let layout = LaneLayoutModel(
                threadVisible: messages.isThreadLaneVisible,
                focusedLane: messages.isThreadLaneVisible ? .thread : .messages
            )

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    spacesLane(width: layout.width(for: .spaces, totalWidth: geometry.size.width))
                    Divider()
                    messagesLane(width: layout.width(for: .messages, totalWidth: geometry.size.width))

                    if messages.isThreadLaneVisible {
                        Divider()
                        threadLane(width: layout.width(for: .thread, totalWidth: geometry.size.width))
                    }
                }
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func spacesLane(width: CGFloat) -> some View {
        List(spaces.rows) { row in
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                Button {
                    spaces.select(spaceID: row.id)
                    Task {
                        await messages.select(spaceID: row.id, spaceTitle: row.title)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .lineLimit(1)
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .frame(width: width)
    }

    private func messagesLane(width: CGFloat) -> some View {
        List(messages.messageRows) { row in
            messageRow(row) {
                messages.select(messageID: row.id)
            }
        }
        .listStyle(.inset)
        .frame(width: width)
    }

    private func threadLane(width: CGFloat) -> some View {
        List(messages.threadRows) { row in
            messageRow(row) {}
                .padding(.leading, CGFloat(row.depth) * 16)
        }
        .listStyle(.inset)
        .frame(width: width)
    }

    private func messageRow(_ row: MessageRowViewModel, action: @escaping () -> Void) -> some View {
        Group {
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                Button(action: action) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(row.sender)
                                .font(.headline)
                                .lineLimit(1)

                            if !row.detail.isEmpty {
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Text(row.body)
                            .foregroundStyle(row.isDeletedTombstone ? .secondary : .primary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
