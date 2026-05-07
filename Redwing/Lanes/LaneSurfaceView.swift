import SwiftUI

struct LaneSurfaceView: View {
    @ObservedObject var spaces: SpacesCoordinator

    var body: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        GlassEffectContainer {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(spaces.rows) { row in
                        SpaceGlassRow(row: row) {
                            spaces.select(spaceID: row.id)
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(paneShape)
            .glassEffect(.regular, in: paneShape)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SpaceGlassRow: View {
    let row: SpaceRowViewModel
    let action: () -> Void

    var body: some View {
        let rowShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Group {
            if row.isSkeleton {
                SkeletonRowView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button(action: action) {
                    HStack(spacing: 14) {
                        SpaceIconView(iconURL: row.iconURL)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.headline)
                                .lineLimit(1)

                            Text(row.teamLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .contentShape(rowShape)
        .glassEffect(.regular.interactive(), in: rowShape)
    }
}

private struct SpaceIconView: View {
    let iconURL: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 44, height: 44)

            if let iconURL {
                AsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
