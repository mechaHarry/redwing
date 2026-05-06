import SwiftUI

struct MenuBarView: View {
    @ObservedObject var attentionFeed: AttentionFeedStore

    let openWindow: () -> Void

    var body: some View {
        Button("Open Redwing") {
            openWindow()
        }

        Divider()

        if attentionFeed.items.isEmpty {
            Text("No attention items")
        } else {
            ForEach(attentionFeed.items.prefix(8)) { item in
                Button {
                    openWindow()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.sender)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(shortBody(item.body))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 240, alignment: .leading)
                }
            }
        }
    }

    private func shortBody(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 48 else {
            return trimmed
        }

        let index = trimmed.index(trimmed.startIndex, offsetBy: 48)
        return String(trimmed[..<index]) + "..."
    }
}
