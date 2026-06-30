import XCTest

final class SceneConfigurationTests: XCTestCase {
    func testMainSceneUsesSingleWindowInsteadOfWindowGroup() throws {
        let redwingAppSource = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)

        XCTAssertTrue(redwingAppSource.contains("Window(\"Redwing\", id: RedwingWindowID.main)"))
        XCTAssertFalse(redwingAppSource.contains("WindowGroup(\"Redwing\", id: RedwingWindowID.main)"))
    }

    func testAppDelegateHandlesDockReopenForCurrentDesktopFocus() throws {
        let redwingAppSource = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)

        XCTAssertTrue(redwingAppSource.contains("@NSApplicationDelegateAdaptor(RedwingAppDelegate.self)"))
        XCTAssertTrue(redwingAppSource.contains("applicationShouldHandleReopen"))
    }

    func testLaneSurfaceIsSpacesOnlyGlassPane() throws {
        let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let spacesSurfaceSource = try sourceRegion(
            in: source,
            startingAt: "struct LaneSurfaceView",
            endingAt: "struct TeamsLaneSurfaceView"
        )

        XCTAssertTrue(spacesSurfaceSource.contains("ScrollView(.vertical)"))
        XCTAssertTrue(spacesSurfaceSource.contains("LazyVStack"))
        XCTAssertFalse(spacesSurfaceSource.contains("GlassEffectContainer"))
        XCTAssertTrue(spacesSurfaceSource.contains("glassEffect"))
        XCTAssertTrue(spacesSurfaceSource.contains(".clipShape(paneShape)"))
        XCTAssertFalse(spacesSurfaceSource.contains(".padding(20)"))
        XCTAssertFalse(spacesSurfaceSource.contains(".scrollClipDisabled()"))
        XCTAssertTrue(source.contains("placeholderImage(systemName: \"person.fill\")"))
        XCTAssertTrue(source.contains("placeholderImage(systemName: \"person.3.fill\")"))
        XCTAssertTrue(source.contains("ProgressView()"))
        XCTAssertFalse(source.contains("@ObservedObject var messages"))
        XCTAssertFalse(source.contains("messagesLane"))
        XCTAssertFalse(source.contains("threadLane"))
    }

    func testSpacesCardExposesSelectionAndScrollBindings() throws {
        let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let laneSurfaceSource = try sourceRegion(
            in: source,
            startingAt: "struct LaneSurfaceView",
            endingAt: "struct TeamsLaneSurfaceView"
        )

        XCTAssertTrue(laneSurfaceSource.contains("@Binding var scrollAnchorID: String?"))
        XCTAssertTrue(laneSurfaceSource.contains("let onSelectSpace: (SpaceRowViewModel) -> Void"))
        XCTAssertTrue(laneSurfaceSource.contains("onSelectSpace(row)"))
        XCTAssertTrue(laneSurfaceSource.contains(".scrollTargetLayout()"))
        XCTAssertTrue(laneSurfaceSource.contains(".scrollPosition(id: $scrollAnchorID, anchor: .top)"))
        XCTAssertTrue(laneSurfaceSource.contains("spaces.selectedSpaceID == row.id"))
    }

    func testSpacesMessagesSurfaceUsesOneSharedGlassComposition() throws {
        let source = try String(contentsOf: spacesMessagesSurfaceSourceURL(), encoding: .utf8)

        XCTAssertEqual(source.occurrences(of: "GlassEffectContainer"), 1)
        XCTAssertTrue(
            source.contains(
                "GlassEffectContainer(spacing: SpacesMessagesLayout.preferredSpacing)"
            )
        )
        XCTAssertTrue(source.contains("@Namespace private var glassNamespace"))
        XCTAssertTrue(source.contains("let contentWidth = geometry.size.width - 40"))
        XCTAssertTrue(source.contains("let isMessagesOpen = messages.selectedSpaceID != nil"))
        XCTAssertTrue(source.contains("SpacesMessagesLayout.widths("))
        XCTAssertTrue(source.contains("totalWidth: contentWidth"))
        XCTAssertTrue(source.contains("isMessagesOpen: isMessagesOpen"))
        XCTAssertTrue(source.contains("HStack(spacing: widths.effectiveSpacing)"))
        XCTAssertTrue(source.contains(".padding(20)"))
    }

    func testSpacesMessagesSurfaceUsesStableCardsLayoutWidthsAndSpring() throws {
        let source = try String(contentsOf: spacesMessagesSurfaceSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("LaneSurfaceView("))
        XCTAssertTrue(source.contains("scrollAnchorID: $navigation.spacesScrollID"))
        XCTAssertTrue(source.contains(".frame(width: widths.spaces)"))
        XCTAssertTrue(source.contains(".glassEffectID(\"spaces-card\", in: glassNamespace)"))
        XCTAssertTrue(source.contains("if isMessagesOpen"))
        XCTAssertTrue(source.contains("MessagesSurfaceView("))
        XCTAssertTrue(source.contains("navigation: navigation"))
        XCTAssertTrue(source.contains(".frame(width: widths.messages)"))
        XCTAssertTrue(source.contains(".glassEffectID(\"messages-card\", in: glassNamespace)"))
        XCTAssertTrue(source.contains(".animation(.spring"))
        XCTAssertTrue(source.contains("value: isMessagesOpen"))
    }

    func testSpacesMessagesSurfaceDelegatesOpeningOrderAndCloseBehavior() throws {
        let source = try String(contentsOf: spacesMessagesSurfaceSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("SpaceOpeningAction("))
        XCTAssertTrue(source.contains("selectSpace: spaces.select(spaceID:)"))
        XCTAssertTrue(source.contains("selectMessages: messages.select(spaceID:spaceTitle:)"))
        XCTAssertTrue(source.contains("Task { @MainActor in"))
        XCTAssertTrue(source.contains("await openSpace(row)"))
        XCTAssertTrue(source.contains("onClose: messages.close"))
        XCTAssertFalse(source.contains("spaces.select(spaceID: nil)"))
        XCTAssertFalse(source.contains("Task.detached"))
    }

    func testSessionRootInjectsMessagesAndOwnsPersistentNavigation() throws {
        let source = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)
        let rootSource = try sourceRegion(
            in: source,
            startingAt: "private struct RedwingRootView",
            endingAt: "private struct SessionSidebarView"
        )
        let sessionSource = try sourceRegion(
            in: source,
            startingAt: "private struct RedwingSessionView",
            endingAt: "    private func start() async"
        )

        XCTAssertTrue(rootSource.contains("let messages = rootModel.messagesCoordinator"))
        XCTAssertTrue(rootSource.contains("messages: messages"))
        XCTAssertTrue(sessionSource.contains("@ObservedObject var messages: MessagesCoordinator"))
        XCTAssertTrue(
            sessionSource.contains(
                "@StateObject private var navigation = SessionNavigationState()"
            )
        )
        XCTAssertTrue(
            sessionSource.contains("SessionSidebarView(selection: $navigation.selectedTab)")
        )
        XCTAssertTrue(sessionSource.contains("switch navigation.selectedTab"))
        XCTAssertTrue(sessionSource.contains("SpacesMessagesSurface("))
        XCTAssertTrue(sessionSource.contains("messages: messages"))
        XCTAssertTrue(sessionSource.contains("navigation: navigation"))
        XCTAssertFalse(sessionSource.contains("@State private var selectedTab"))
        XCTAssertFalse(containsTabDerivedIdentityReset(in: sessionSource))
    }

    func testTabDerivedIdentityResetDetectionIsPrecise() {
        XCTAssertTrue(containsTabDerivedIdentityReset(in: ".id(selectedTab)"))
        XCTAssertTrue(
            containsTabDerivedIdentityReset(in: ".id(navigation.selectedTab)")
        )
        XCTAssertTrue(
            containsTabDerivedIdentityReset(in: ".id( navigation . selectedTab )")
        )
        XCTAssertTrue(
            containsTabDerivedIdentityReset(in: ".id(navigation.selectedTab.rawValue)")
        )
        XCTAssertFalse(containsTabDerivedIdentityReset(in: ".id(\"spaces-card\")"))
        XCTAssertFalse(containsTabDerivedIdentityReset(in: ".id(message.id)"))
    }

    func testSpacesMessagesSurfaceDoesNotRenderDeferredThreadUI() throws {
        let source = try String(contentsOf: spacesMessagesSurfaceSourceURL(), encoding: .utf8)

        XCTAssertFalse(source.localizedCaseInsensitiveContains("thread"))
    }

    func testTeamsAndPeopleSurfacesBindIndependentScrollPositions() throws {
        let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let teamsSource = try sourceRegion(
            in: source,
            startingAt: "struct TeamsLaneSurfaceView",
            endingAt: "struct PeopleHierarchyView"
        )
        let peopleSource = try sourceRegion(
            in: source,
            startingAt: "struct PeopleHierarchyView",
            endingAt: "private struct SpaceGlassRow"
        )

        for scopedSource in [teamsSource, peopleSource] {
            XCTAssertTrue(scopedSource.contains("@Binding var scrollAnchorID: String?"))
            XCTAssertTrue(scopedSource.contains(".scrollTargetLayout()"))
            XCTAssertTrue(
                scopedSource.contains(".scrollPosition(id: $scrollAnchorID, anchor: .top)")
            )
        }

        let appSource = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)
        XCTAssertTrue(appSource.contains("scrollAnchorID: $navigation.teamsScrollID"))
        XCTAssertTrue(appSource.contains("scrollAnchorID: $navigation.peopleScrollID"))
    }

    func testLaneSurfaceHasNoTemporaryCompatibilityInitializer() throws {
        let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let laneSurfaceSource = try sourceRegion(
            in: source,
            startingAt: "struct LaneSurfaceView",
            endingAt: "struct TeamsLaneSurfaceView"
        )

        XCTAssertFalse(laneSurfaceSource.contains("init(spaces: SpacesCoordinator)"))
        XCTAssertFalse(laneSurfaceSource.contains(".constant(nil)"))
    }

    func testSpacesMessagesSurfaceIsRegisteredExactlyOnce() throws {
        let project = try String(contentsOf: projectFileURL(), encoding: .utf8)

        XCTAssertEqual(
            project.occurrences(of: "SpacesMessagesSurface.swift in Sources"),
            2
        )
        XCTAssertEqual(
            project.occurrences(of: "/* SpacesMessagesSurface.swift */"),
            3
        )
    }

    func testSessionShellUsesGlassSidebarTabs() throws {
        let redwingAppSource = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)
        let sessionNavigationStateSource = try String(
            contentsOf: sessionNavigationStateSourceURL(),
            encoding: .utf8
        )

        XCTAssertTrue(sessionNavigationStateSource.contains("enum RedwingMainTab"))
        XCTAssertTrue(redwingAppSource.contains("SessionSidebarView"))
        XCTAssertTrue(redwingAppSource.contains("glassEffect(.regular"))
    }

    func testSpaceRowsOwnIndividualGlassSurfaces() throws {
        let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let spaceGlassRowSource = try sourceRegion(
            in: source,
            startingAt: "private struct SpaceGlassRow",
            endingAt: "private struct TeamGlassRow"
        )

        XCTAssertTrue(spaceGlassRowSource.contains("private struct SpaceGlassRow"))
        XCTAssertTrue(spaceGlassRowSource.contains("let rowShape = RoundedRectangle"))
        XCTAssertTrue(spaceGlassRowSource.contains(".frame(maxWidth: .infinity, minHeight:"))
        XCTAssertTrue(spaceGlassRowSource.contains(".contentShape(rowShape)"))
        XCTAssertTrue(spaceGlassRowSource.contains(".glassEffect(.regular.interactive(), in: rowShape)"))
        XCTAssertTrue(spaceGlassRowSource.contains("Color.primary.opacity(0.18)"))
        XCTAssertTrue(spaceGlassRowSource.contains("Color.accentColor.opacity(0.70)"))
        XCTAssertTrue(spaceGlassRowSource.contains("lineWidth: isSelected ? 1.5 : 1"))
        XCTAssertTrue(spaceGlassRowSource.contains("rowShape.fill(Color.accentColor.opacity(0.10))"))
        XCTAssertTrue(
            spaceGlassRowSource.contains(
                ".accessibilityAddTraits(isSelected ? .isSelected : [])"
            )
        )
    }

    func testSpaceRowsRenderOnlyTeamContextAndDateMetadata() throws {
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(laneSurfaceSource.contains("if let teamLabel = row.teamLabel"))
        XCTAssertTrue(laneSurfaceSource.contains("Text(teamLabel)"))
        XCTAssertTrue(laneSurfaceSource.contains("Text(row.createdLabel)"))
        XCTAssertTrue(laneSurfaceSource.contains("Text(row.lastActivityLabel)"))
        XCTAssertFalse(laneSurfaceSource.contains("Text(row.typeLabel)"))
    }

    func testSpaceRowsTriggerPaginationWhenBottomRowAppears() throws {
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(laneSurfaceSource.contains(".onAppear"))
        XCTAssertTrue(laneSurfaceSource.contains("loadNextPageIfNeeded(visibleRowID: row.id)"))
    }

    func testLaneSurfacesShowAnimatedSkeletonsAndPaginationFooter() throws {
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
        let skeletonSource = try String(contentsOf: skeletonViewsSourceURL(), encoding: .utf8)

        XCTAssertTrue(skeletonSource.contains("SkeletonWaveModifier"))
        XCTAssertTrue(skeletonSource.contains("LinearGradient"))
        XCTAssertTrue(laneSurfaceSource.contains("LanePaginationFooter"))
        XCTAssertTrue(laneSurfaceSource.contains("Searching for more..."))
        XCTAssertTrue(laneSurfaceSource.contains("All found!"))
        XCTAssertTrue(laneSurfaceSource.contains("BirdLoadingIndicator"))
        XCTAssertTrue(laneSurfaceSource.contains("BirdNestIndicator"))
    }

    func testSpaceRowsAnimateSnapshotDrivenContentChanges() throws {
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(laneSurfaceSource.contains(".transition("))
        XCTAssertTrue(laneSurfaceSource.contains(".animation(.easeInOut"))
        XCTAssertTrue(laneSurfaceSource.contains("value: spaces.rows"))
        XCTAssertTrue(laneSurfaceSource.contains("value: row"))
        XCTAssertTrue(laneSurfaceSource.contains(".id(avatarState)"))
    }

    func testMessagesCardHasNativeGlassHeaderAndReadOnlyTimeline() throws {
        let source = try String(contentsOf: messagesSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("struct MessagesSurfaceView"))
        XCTAssertTrue(source.contains("messages.selectedSpaceTitle ?? \"Messages\""))
        XCTAssertTrue(source.contains("frame(height: 46)"))
        XCTAssertTrue(source.contains("Image(systemName: \"xmark\")"))
        XCTAssertTrue(source.contains(".buttonStyle(.glass)"))
        XCTAssertTrue(source.contains(".buttonBorderShape(.circle)"))
        XCTAssertTrue(source.contains(".help(\"Close Messages\")"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Close Messages\")"))
        XCTAssertTrue(source.contains("Text(row.sender)"))
        XCTAssertTrue(source.contains("Text(row.body)"))
        XCTAssertTrue(source.contains("Text(row.detail)"))
        XCTAssertTrue(source.contains("SkeletonRowView"))
        XCTAssertFalse(source.localizedCaseInsensitiveContains("composer"))
        XCTAssertFalse(source.contains("TextEditor"))
    }

    func testMessagesCardRestoresScrollAndPaginates() throws {
        let source = try String(contentsOf: messagesSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("ScrollViewReader"))
        XCTAssertTrue(source.contains("messageScrollRequest"))
        XCTAssertTrue(source.contains("scrollExecutor.submitAfterMutation"))
        XCTAssertTrue(source.contains("rememberMessageAnchor"))
        XCTAssertTrue(source.contains("LanePaginationFooter"))
        XCTAssertTrue(source.contains("loadNextPageFromFooterIfNeeded"))
    }

    func testMessagesRenderUntrustedContentAsTextOnly() throws {
        let source = try String(contentsOf: messagesSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("Text(row.body)"))
        XCTAssertFalse(source.contains("WKWebView"))
        XCTAssertFalse(source.contains("NSAttributedString.DocumentType.html"))
    }

    func testMessagesTimelineAvoidsGeometryDrivenImplicitAnimation() throws {
        let source = try String(contentsOf: messagesSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains(".transition(.opacity)"))
        XCTAssertTrue(source.contains("withAnimation(.easeInOut"))
        XCTAssertTrue(
            source.contains("@State private var scrollExecutor = MessageScrollRequestExecutor()")
        )
        XCTAssertTrue(source.contains(".onDisappear"))
        XCTAssertTrue(source.contains("scrollExecutor.cancel()"))
        XCTAssertFalse(source.contains("value: messages.messageRows"))
        XCTAssertFalse(source.contains("value: row"))
    }

    private func redwingAppSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/App/RedwingApp.swift")
    }

    private func sessionNavigationStateSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/App/SessionNavigationState.swift")
    }

    private func laneSurfaceViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Lanes/LaneSurfaceView.swift")
    }

    private func messagesSurfaceViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Messages/MessagesSurfaceView.swift")
    }

    private func spacesMessagesSurfaceSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Lanes/SpacesMessagesSurface.swift")
    }

    private func projectFileURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("redwing.xcodeproj/project.pbxproj")
    }

    private func skeletonViewsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Lanes/SkeletonViews.swift")
    }

    private func sourceRegion(
        in source: String,
        startingAt startMarker: String,
        endingAt endMarker: String
    ) throws -> String {
        let startRange = try XCTUnwrap(source.range(of: startMarker))
        let suffix = source[startRange.lowerBound...]
        let endRange = try XCTUnwrap(suffix.range(of: endMarker))
        return String(suffix[..<endRange.lowerBound])
    }
}

private extension String {
    func occurrences(of value: String) -> Int {
        components(separatedBy: value).count - 1
    }
}

private func containsTabDerivedIdentityReset(in source: String) -> Bool {
    source.range(
        of: #"\.id\s*\([^)]*\bselectedTab\b[^)]*\)"#,
        options: .regularExpression
    ) != nil
}
