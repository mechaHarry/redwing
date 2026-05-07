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
        XCTAssertTrue(laneSurfaceSource.contains("Image(systemName: \"circle\")"))
        XCTAssertFalse(laneSurfaceSource.contains("@ObservedObject var messages"))
        XCTAssertFalse(laneSurfaceSource.contains("messagesLane"))
        XCTAssertFalse(laneSurfaceSource.contains("threadLane"))
    }

    private func redwingAppSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/App/RedwingApp.swift")
    }

    private func laneSurfaceViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Redwing/Lanes/LaneSurfaceView.swift")
    }
}
