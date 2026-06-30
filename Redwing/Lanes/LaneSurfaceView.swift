import SwiftUI

struct LaneSurfaceView: View {
    @ObservedObject var spaces: SpacesCoordinator
    @Binding var scrollAnchorID: String?
    let onSelectSpace: (SpaceRowViewModel) -> Void

    init(
        spaces: SpacesCoordinator,
        scrollAnchorID: Binding<String?>,
        onSelectSpace: @escaping (SpaceRowViewModel) -> Void
    ) {
        self.spaces = spaces
        _scrollAnchorID = scrollAnchorID
        self.onSelectSpace = onSelectSpace
    }

    init(spaces: SpacesCoordinator) {
        self.init(
            spaces: spaces,
            scrollAnchorID: .constant(nil),
            onSelectSpace: { spaces.select(spaceID: $0.id) }
        )
    }

    var body: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(spaces.rows) { row in
                    SpaceGlassRow(
                        row: row,
                        isSelected: spaces.selectedSpaceID == row.id
                    ) {
                        onSelectSpace(row)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .onAppear {
                        Task {
                            await spaces.loadNextPageIfNeeded(visibleRowID: row.id)
                        }
                    }
                }

                if let footerState = spaces.footerState {
                    LanePaginationFooter(state: footerState)
                        .onAppear {
                            Task {
                                await spaces.loadNextPageFromFooterIfNeeded()
                            }
                        }
                }
            }
            .scrollTargetLayout()
            .padding(18)
        }
        .scrollPosition(id: $scrollAnchorID, anchor: .top)
        .animation(.easeInOut(duration: 0.24), value: spaces.rows)
        .animation(.easeInOut(duration: 0.2), value: spaces.footerState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(paneShape)
        .glassEffect(.regular, in: paneShape)
    }
}

struct TeamsLaneSurfaceView: View {
    @ObservedObject var teams: TeamsCoordinator

    var body: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        GlassEffectContainer {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(teams.rows) { row in
                        TeamGlassRow(row: row) {
                            teams.select(teamID: row.id)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .onAppear {
                            Task {
                                await teams.loadNextPageIfNeeded(visibleRowID: row.id)
                            }
                        }
                    }

                    if let footerState = teams.footerState {
                        LanePaginationFooter(state: footerState)
                            .onAppear {
                                Task {
                                    await teams.loadNextPageFromFooterIfNeeded()
                                }
                            }
                    }
                }
                .padding(18)
            }
            .animation(.easeInOut(duration: 0.24), value: teams.rows)
            .animation(.easeInOut(duration: 0.2), value: teams.footerState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(paneShape)
            .glassEffect(.regular, in: paneShape)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PeopleHierarchyView: View {
    @ObservedObject var people: PeopleCoordinator

    var body: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        GlassEffectContainer {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(Array(people.nodes.enumerated()), id: \.element.id) { index, node in
                        PersonHierarchyNode(node: node)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                        if index < people.nodes.count - 1 {
                            Capsule()
                                .fill(.secondary.opacity(0.32))
                                .frame(width: 2, height: 34)
                                .padding(.vertical, 4)
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .animation(.easeInOut(duration: 0.24), value: people.nodes)
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
    let isSelected: Bool
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
                        SpaceIconView(avatarState: row.avatarState)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.headline)
                                .lineLimit(1)
                                .contentTransition(.opacity)

                            if let teamLabel = row.teamLabel {
                                Text(teamLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }

                            HStack(spacing: 8) {
                                Text(row.createdLabel)
                                Text(row.lastActivityLabel)
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
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
        .overlay {
            rowShape.strokeBorder(
                isSelected ? Color.accentColor.opacity(0.70) : Color.primary.opacity(0.18),
                lineWidth: isSelected ? 1.5 : 1
            )
        }
        .background {
            if isSelected {
                rowShape.fill(Color.accentColor.opacity(0.10))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: row)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct TeamGlassRow: View {
    let row: TeamRowViewModel
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
                        SpaceIconView(avatarState: .groupPlaceholder)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name)
                                .font(.headline)
                                .lineLimit(1)
                                .contentTransition(.opacity)

                            Text(row.creatorLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .contentTransition(.opacity)

                            Text(row.createdLabel)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
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
        .overlay {
            rowShape
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: row)
    }
}

private struct PersonHierarchyNode: View {
    let node: PersonNodeViewModel

    var body: some View {
        let rowShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        HStack(spacing: 14) {
            if node.isSkeleton {
                SkeletonRowView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SpaceIconView(avatarState: node.avatarState)

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.headline)
                        .lineLimit(1)
                        .contentTransition(.opacity)

                    if let subtitle = node.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360, alignment: .leading)
        .frame(minHeight: 84, alignment: .leading)
        .contentShape(rowShape)
        .glassEffect(.regular, in: rowShape)
        .overlay {
            rowShape
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: node)
    }
}

struct LanePaginationFooter: View {
    let state: LanePaginationFooterState

    var body: some View {
        VStack(spacing: 10) {
            switch state {
            case .searching:
                BirdLoadingIndicator()
                Text("Searching for more...")
            case .allFound:
                BirdNestIndicator()
                Text("All found!")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 96)
        .contentTransition(.opacity)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
    }
}

struct BirdLoadingIndicator: View {
    @State private var isDiving = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(.secondary.opacity(0.16 - Double(index) * 0.03))
                    .frame(width: 24 + CGFloat(index * 8), height: 2)
                    .offset(x: CGFloat(index * -8), y: CGFloat(index * 4))
            }

            Image(systemName: "bird.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .offset(x: isDiving ? 10 : -10, y: isDiving ? 6 : -6)
                .rotationEffect(.degrees(isDiving ? 10 : -8))
        }
        .frame(width: 72, height: 34)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                isDiving = true
            }
        }
    }
}

struct BirdNestIndicator: View {
    @State private var isChirping = false

    var body: some View {
        ZStack {
            Image(systemName: "basket.fill")
                .font(.title3)
                .foregroundStyle(.tertiary)
                .offset(y: 8)

            Image(systemName: "bird.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .offset(y: isChirping ? -3 : 1)

            Image(systemName: "ellipsis")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(x: 22, y: isChirping ? -14 : -9)
                .opacity(isChirping ? 1 : 0.35)
        }
        .frame(width: 72, height: 38)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                isChirping = true
            }
        }
    }
}

private struct SpaceIconView: View {
    let avatarState: SpaceAvatarState

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 44, height: 44)

            iconContent
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .id(avatarState)
        }
        .frame(width: 44, height: 44)
        .animation(.easeInOut(duration: 0.2), value: avatarState)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconContent: some View {
        switch avatarState {
        case .remote(let url):
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderImage(systemName: "person.fill")
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                @unknown default:
                    placeholderImage(systemName: "person.fill")
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .directPlaceholder:
            placeholderImage(systemName: "person.fill")

        case .groupPlaceholder:
            placeholderImage(systemName: "person.3.fill")
        }
    }

    private func placeholderImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}
