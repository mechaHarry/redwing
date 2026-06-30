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
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(laneSurfaceSource.contains("ScrollView(.vertical)"))
        XCTAssertTrue(laneSurfaceSource.contains("LazyVStack"))
        XCTAssertTrue(laneSurfaceSource.contains("GlassEffectContainer"))
        XCTAssertTrue(laneSurfaceSource.contains("glassEffect"))
        XCTAssertTrue(laneSurfaceSource.contains(".clipShape(paneShape)"))
        XCTAssertFalse(laneSurfaceSource.contains(".scrollClipDisabled()"))
        XCTAssertTrue(laneSurfaceSource.contains("placeholderImage(systemName: \"person.fill\")"))
        XCTAssertTrue(laneSurfaceSource.contains("placeholderImage(systemName: \"person.3.fill\")"))
        XCTAssertTrue(laneSurfaceSource.contains("ProgressView()"))
        XCTAssertFalse(laneSurfaceSource.contains("@ObservedObject var messages"))
        XCTAssertFalse(laneSurfaceSource.contains("messagesLane"))
        XCTAssertFalse(laneSurfaceSource.contains("threadLane"))
    }

    func testSessionShellUsesGlassSidebarTabs() throws {
        let redwingAppSource = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)
        let sessionNavigationStateSource = try String(
            contentsOf: sessionNavigationStateSourceURL(),
            encoding: .utf8
        )

        XCTAssertTrue(sessionNavigationStateSource.contains("enum RedwingMainTab"))
        XCTAssertTrue(redwingAppSource.contains("SessionSidebarView"))
        XCTAssertTrue(redwingAppSource.contains("Spaces"))
        XCTAssertTrue(redwingAppSource.contains("Teams"))
        XCTAssertTrue(redwingAppSource.contains("People"))
        XCTAssertTrue(redwingAppSource.contains("glassEffect(.regular"))
    }

    func testSpaceRowsOwnIndividualGlassSurfaces() throws {
        let laneSurfaceSource = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(laneSurfaceSource.contains("private struct SpaceGlassRow"))
        XCTAssertTrue(laneSurfaceSource.contains("let rowShape = RoundedRectangle"))
        XCTAssertTrue(laneSurfaceSource.contains(".frame(maxWidth: .infinity, minHeight:"))
        XCTAssertTrue(laneSurfaceSource.contains(".contentShape(rowShape)"))
        XCTAssertTrue(laneSurfaceSource.contains(".glassEffect(.regular.interactive(), in: rowShape)"))
        XCTAssertTrue(laneSurfaceSource.contains(".strokeBorder(Color.primary.opacity"))
        XCTAssertTrue(laneSurfaceSource.contains("lineWidth: 1"))
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

    private func skeletonViewsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Lanes/SkeletonViews.swift")
    }
}
