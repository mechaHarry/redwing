# Space and Message Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only, live Messages card that opens beside Spaces in an animated one-third/two-thirds Liquid Glass layout while preserving independent tab and scroll state.

**Architecture:** Keep `MessagesCoordinator` as the message-stream owner, add scene-owned navigation state for tab and scroll restoration, and compose focused Spaces and Messages cards inside one `GlassEffectContainer`. Use an exact weighted layout model and stable glass identities so opening and closing morphs cards without recreating coordinators or disturbing Teams and People state.

**Tech Stack:** Swift 5, SwiftUI for macOS 26, Combine, WebexSwiftSDK 2.7.1, XCTest, Xcode project targets.

---

## File Structure

- Create `Redwing/App/SessionNavigationState.swift`: scene-scoped selected tab and per-view indexed scroll anchors.
- Create `Redwing/Lanes/SpacesMessagesLayout.swift`: pure width calculation for closed and `1:2` states.
- Create `Redwing/Lanes/SpacesMessagesSurface.swift`: shared glass container and animated Spaces/Messages composition.
- Create `Redwing/Messages/MessagesSurfaceView.swift`: faded header, read-only timeline, loading/error/footer states, and message scroll restoration.
- Modify `Redwing/Messages/MessagesCoordinator.swift`: explicit close/retry, pagination state, and one-shot initial scroll requests.
- Modify `Redwing/Lanes/LaneSurfaceView.swift`: make the Spaces card callback-driven, selected-row aware, and scroll-restorable; add scroll bindings to Teams and People.
- Modify `Redwing/App/RedwingApp.swift`: inject `MessagesCoordinator`, own `SessionNavigationState`, and remove tab identity resets.
- Modify `redwing.xcodeproj/project.pbxproj`: register all new source and test files.
- Create `RedwingTests/SessionNavigationStateTests.swift`, `RedwingTests/SpacesMessagesLayoutTests.swift`, and `RedwingTests/SpacesMessagesIntegrationTests.swift`.
- Modify `RedwingTests/MessagesCoordinatorTests.swift` and `RedwingTests/SceneConfigurationTests.swift`.

### Task 1: Make the Messages Coordinator Closable and Restoration-Safe

**Files:**
- Modify: `Redwing/Messages/MessagesCoordinator.swift:10`
- Modify: `RedwingTests/MessagesCoordinatorTests.swift:5`

- [ ] **Step 1: Write failing lifecycle, pagination, and one-shot scroll tests**

Add these tests to `MessagesCoordinatorTests`:

```swift
func testCloseCancelsStreamAndClearsOpenSpacePresentation() async throws {
    let fake = FakeWebexClientProviding()
    let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
    let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

    await coordinator.select(spaceID: "space-1", spaceTitle: "General")
    let stream = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
    coordinator.close()

    XCTAssertTrue(stream.isCancelled)
    XCTAssertNil(coordinator.selectedSpaceID)
    XCTAssertNil(coordinator.selectedSpaceTitle)
    XCTAssertNil(coordinator.selectedMessageID)
    XCTAssertEqual(coordinator.messageRows, [])
    XCTAssertEqual(coordinator.status, .idle)
}

func testRetryReplacesFailedStreamForCurrentSpace() async throws {
    let fake = FakeWebexClientProviding()
    let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
    let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())

    await coordinator.select(spaceID: "space-1", spaceTitle: "General")
    let first = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])
    first.probe.yield(MessageThreadSnapshotDTO(
        topLevelMessageIDs: [], entriesByID: [:], isRefreshing: false,
        isLoadingNextPage: false, hasMore: false,
        lastErrorDescription: "offline"
    ))
    await waitUntil { coordinator.status == .failed("Messages refresh failed") }

    await coordinator.retry()
    let replacement = try XCTUnwrap(fake.messagesStreamsBySpaceID["space-1"])

    XCTAssertTrue(first.isCancelled)
    XCTAssertFalse(replacement === first)
    XCTAssertEqual(replacement.refreshCount, 1)
}

func testRealtimeSnapshotDoesNotReplaceInitialScrollRequest() {
    let coordinator = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())
    coordinator.apply(snapshot: snapshot(ids: ["older", "newest"]))
    let initialRequest = coordinator.messageScrollRequest

    coordinator.apply(snapshot: snapshot(ids: ["older", "newest", "later"]))

    XCTAssertEqual(coordinator.messageScrollRequest?.id, initialRequest?.id)
    XCTAssertEqual(coordinator.messageScrollRequest?.targetID, "newest")
}

func testMessagesFooterAndGuardedPaginationFollowSnapshotState() async {
    let fake = FakeWebexClientProviding()
    let session = AccountSession(clientProvider: fake, diagnostics: DiagnosticsStore())
    let coordinator = MessagesCoordinator(session: session, diagnostics: DiagnosticsStore())
    await coordinator.select(spaceID: "space-1")

    coordinator.apply(snapshot: snapshot(ids: ["one"], hasMore: true))
    XCTAssertEqual(coordinator.footerState, .searching)
    await coordinator.loadNextPageFromFooterIfNeeded()
    await coordinator.loadNextPageFromFooterIfNeeded()

    XCTAssertEqual(fake.messagesStreamsBySpaceID["space-1"]?.loadNextPageCount, 1)
}
```

Add this helper beside the existing `message(...)` helper:

```swift
private func snapshot(ids: [String], hasMore: Bool = false) -> MessageThreadSnapshotDTO {
    MessageThreadSnapshotDTO(
        topLevelMessageIDs: ids,
        entriesByID: Dictionary(uniqueKeysWithValues: ids.map { id in
            (id, message(id: id, body: id))
        }),
        isRefreshing: false,
        isLoadingNextPage: false,
        hasMore: hasMore,
        lastErrorDescription: nil
    )
}
```

Replace `testMessagesLaneIssuesNewScrollRequestWhenNewestTargetRepeats` with `testRealtimeSnapshotDoesNotReplaceInitialScrollRequest`; the former behavior conflicts with persisted user scroll position.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/MessagesCoordinatorTests \
  -derivedDataPath /private/tmp/redwing-messages-red CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `close`, `retry`, `selectedSpaceTitle`, `footerState`, and guarded pagination are missing, and realtime currently replaces the scroll request.

- [ ] **Step 3: Implement close, retry, pagination state, and one-shot initial scrolling**

In `MessagesCoordinator`, expose the title and loading state:

```swift
@Published private(set) var selectedSpaceTitle: String?
@Published private(set) var isLoadingNextPage = false

var footerState: LanePaginationFooterState? {
    guard !isShowingSkeletons, selectedSpaceID != nil else { return nil }
    return hasMore || isLoadingNextPage ? .searching : .allFound
}

private var isAwaitingInitialMessageScroll = true
```

Replace the existing private `selectedSpaceTitle` declaration with the published declaration above; do not leave both properties in the type.

Set `isAwaitingInitialMessageScroll = true` in `select`, set `isLoadingNextPage` from every snapshot, and only call `updateMessageScrollTarget` while the one-shot flag is true:

```swift
if isAwaitingInitialMessageScroll {
    updateMessageScrollTarget(rows: rows, snapshot: snapshot)
    isAwaitingInitialMessageScroll = false
}
```

Add lifecycle and pagination methods:

```swift
func close() {
    rememberSelectedMessageForCurrentSpace()
    _ = replaceStreamState()
    selectedSpaceID = nil
    selectedSpaceTitle = nil
    selectedMessageID = nil
    latestSnapshot = nil
    messageRows = []
    threadRows = []
    isThreadLaneVisible = false
    isShowingSkeletons = false
    hasMore = false
    isLoadingNextPage = false
    isAwaitingInitialMessageScroll = false
    setMessageScrollTarget(nil)
    setThreadScrollTarget(nil)
    status = .idle
}

func retry() async {
    guard let spaceID = selectedSpaceID else { return }
    let title = selectedSpaceTitle
    rememberSelectedMessageForCurrentSpace()
    selectedSpaceID = nil
    await select(spaceID: spaceID, spaceTitle: title)
}

func loadNextPageFromFooterIfNeeded() async {
    guard hasMore, !isLoadingNextPage, let stream else { return }
    isLoadingNextPage = true
    await stream.loadNextPage()
}
```

Keep the subscription task weak and keep both `task` and `stream` cancellation in `replaceStreamState` and `deinit`.

- [ ] **Step 4: Run the coordinator tests and verify GREEN**

Run the command from Step 2.

Expected: all `MessagesCoordinatorTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Redwing/Messages/MessagesCoordinator.swift RedwingTests/MessagesCoordinatorTests.swift
git commit -S -m "feat: close and restore message streams"
```

### Task 2: Add Scene-Scoped Navigation and Indexed Scroll Anchors

**Files:**
- Create: `Redwing/App/SessionNavigationState.swift`
- Create: `RedwingTests/SessionNavigationStateTests.swift`
- Modify: `redwing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing navigation-state tests**

Create `SessionNavigationStateTests.swift`:

```swift
import XCTest
@testable import Redwing

@MainActor
final class SessionNavigationStateTests: XCTestCase {
    func testEachTopLevelViewKeepsIndependentAnchor() {
        let state = SessionNavigationState()
        state.spacesScrollID = "space-8"
        state.teamsScrollID = "team-3"
        state.peopleScrollID = "person-2"
        state.selectedTab = .people
        state.selectedTab = .spaces

        XCTAssertEqual(state.spacesScrollID, "space-8")
        XCTAssertEqual(state.teamsScrollID, "team-3")
        XCTAssertEqual(state.peopleScrollID, "person-2")
    }

    func testMessageAnchorIsStoredPerSpace() {
        let state = SessionNavigationState()
        state.rememberMessageAnchor(spaceID: "a", id: "a-2", index: 1)
        state.rememberMessageAnchor(spaceID: "b", id: "b-1", index: 0)

        XCTAssertEqual(state.restoredMessageID(spaceID: "a", rowIDs: ["a-1", "a-2"]), "a-2")
        XCTAssertEqual(state.restoredMessageID(spaceID: "b", rowIDs: ["b-1"]), "b-1")
    }

    func testMissingMessageAnchorUsesClampedSavedIndexThenLatest() {
        let state = SessionNavigationState()
        state.rememberMessageAnchor(spaceID: "a", id: "removed", index: 4)

        XCTAssertEqual(state.restoredMessageID(spaceID: "a", rowIDs: ["one", "two"]), "two")
        XCTAssertNil(state.restoredMessageID(spaceID: "a", rowIDs: []))
    }
}
```

- [ ] **Step 2: Register the test file and run it to verify RED**

Add `SessionNavigationStateTests.swift` to the `RedwingTests` group and test Sources phase in `project.pbxproj`.

Run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/SessionNavigationStateTests \
  -derivedDataPath /private/tmp/redwing-navigation-red CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `SessionNavigationState` does not exist.

- [ ] **Step 3: Implement the scene state**

Create `SessionNavigationState.swift`:

```swift
import Combine
import Foundation

struct IndexedScrollAnchor: Equatable {
    let id: String
    let index: Int
}

@MainActor
final class SessionNavigationState: ObservableObject {
    @Published var selectedTab: RedwingMainTab = .spaces
    @Published var spacesScrollID: String?
    @Published var teamsScrollID: String?
    @Published var peopleScrollID: String?

    private var messageAnchorsBySpaceID: [String: IndexedScrollAnchor] = [:]

    func rememberMessageAnchor(spaceID: String, id: String?, index: Int?) {
        guard let id, let index else { return }
        messageAnchorsBySpaceID[spaceID] = IndexedScrollAnchor(id: id, index: index)
    }

    func restoredMessageID(spaceID: String, rowIDs: [String]) -> String? {
        guard !rowIDs.isEmpty else { return nil }
        guard let anchor = messageAnchorsBySpaceID[spaceID] else { return nil }
        if rowIDs.contains(anchor.id) { return anchor.id }
        return rowIDs[min(max(anchor.index, 0), rowIDs.count - 1)]
    }
}
```

Move `RedwingMainTab` from `RedwingApp.swift` into this file unchanged so the state and tests share one definition. Add the production file to the `App` group and app Sources phase.

- [ ] **Step 4: Run the state tests and verify GREEN**

Run the command from Step 2.

Expected: all `SessionNavigationStateTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Redwing/App/SessionNavigationState.swift Redwing/App/RedwingApp.swift \
  RedwingTests/SessionNavigationStateTests.swift redwing.xcodeproj/project.pbxproj
git commit -S -m "feat: preserve per-view navigation state"
```

### Task 3: Define the Exact Closed and One-to-Two Layout

**Files:**
- Create: `Redwing/Lanes/SpacesMessagesLayout.swift`
- Create: `RedwingTests/SpacesMessagesLayoutTests.swift`
- Modify: `redwing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing width-model tests**

Create `SpacesMessagesLayoutTests.swift`:

```swift
import XCTest
@testable import Redwing

final class SpacesMessagesLayoutTests: XCTestCase {
    func testClosedLayoutGivesAllWidthToSpaces() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 900, isMessagesOpen: false)
        XCTAssertEqual(widths.spaces, 900, accuracy: 0.001)
        XCTAssertEqual(widths.messages, 0, accuracy: 0.001)
    }

    func testOpenLayoutUsesOneThirdTwoThirdsAfterSpacing() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 912, isMessagesOpen: true)
        XCTAssertEqual(widths.spaces, 300, accuracy: 0.001)
        XCTAssertEqual(widths.messages, 600, accuracy: 0.001)
        XCTAssertEqual(widths.spaces + SpacesMessagesLayout.spacing + widths.messages, 912, accuracy: 0.001)
    }

    func testOpenLayoutProtectsMinimumWidths() {
        let widths = SpacesMessagesLayout.widths(totalWidth: 652, isMessagesOpen: true)
        XCTAssertGreaterThanOrEqual(widths.spaces, SpacesMessagesLayout.minimumSpacesWidth)
        XCTAssertGreaterThanOrEqual(widths.messages, SpacesMessagesLayout.minimumMessagesWidth)
        XCTAssertEqual(widths.spaces + SpacesMessagesLayout.spacing + widths.messages, 652, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Register and run the tests to verify RED**

Add `SpacesMessagesLayout.swift` to the `Lanes` PBX group and Redwing Sources phase. Add `SpacesMessagesLayoutTests.swift` to the `RedwingTests` PBX group and test Sources phase.

Run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/SpacesMessagesLayoutTests \
  -derivedDataPath /private/tmp/redwing-layout-red CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `SpacesMessagesLayout` does not exist.

- [ ] **Step 3: Implement the pure layout model**

Create `SpacesMessagesLayout.swift`:

```swift
import CoreGraphics

enum SpacesMessagesLayout {
    static let spacing: CGFloat = 12
    static let minimumSpacesWidth: CGFloat = 220
    static let minimumMessagesWidth: CGFloat = 420

    struct Widths: Equatable {
        let spaces: CGFloat
        let messages: CGFloat
    }

    static func widths(totalWidth: CGFloat, isMessagesOpen: Bool) -> Widths {
        guard isMessagesOpen else {
            return Widths(spaces: max(totalWidth, 0), messages: 0)
        }

        let available = max(totalWidth - spacing, 0)
        let idealSpaces = available / 3
        let spaces = max(minimumSpacesWidth, min(idealSpaces, available - minimumMessagesWidth))
        return Widths(spaces: spaces, messages: max(available - spaces, minimumMessagesWidth))
    }
}
```

The app's minimum window width keeps normal operation above the combined minimum. The clamped branch exists for deterministic layout tests and defensive resizing.

- [ ] **Step 4: Run tests and verify GREEN**

Run the command from Step 2.

Expected: all `SpacesMessagesLayoutTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Redwing/Lanes/SpacesMessagesLayout.swift RedwingTests/SpacesMessagesLayoutTests.swift \
  redwing.xcodeproj/project.pbxproj
git commit -S -m "feat: model spaces message split"
```

### Task 4: Turn the Spaces Surface into a Selectable Restorable Card

**Files:**
- Modify: `Redwing/Lanes/LaneSurfaceView.swift:3-184`
- Modify: `RedwingTests/SceneConfigurationTests.swift:18-96`
- Create: `RedwingTests/SpacesMessagesIntegrationTests.swift`
- Modify: `redwing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing source and selection-contract tests**

Add to `SceneConfigurationTests`:

```swift
func testSpacesCardExposesSelectionAndScrollBindings() throws {
    let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
    XCTAssertTrue(source.contains("let onSelectSpace: (SpaceRowViewModel) -> Void"))
    XCTAssertTrue(source.contains("@Binding var scrollAnchorID: String?"))
    XCTAssertTrue(source.contains(".scrollPosition(id: $scrollAnchorID"))
    XCTAssertTrue(source.contains("spaces.selectedSpaceID == row.id"))
}
```

Create `SpacesMessagesIntegrationTests.swift` with a pure selection assertion:

```swift
import XCTest
@testable import Redwing

@MainActor
final class SpacesMessagesIntegrationTests: XCTestCase {
    func testSelectingSpaceStoresIDBeforeOpeningMessages() async {
        let spaces = SpacesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let messages = MessagesCoordinator(session: nil, diagnostics: DiagnosticsStore())
        let row = SpaceRowViewModel(
            id: "space-1", title: "General", teamLabel: nil,
            createdLabel: "", lastActivityLabel: "",
            avatarState: .groupPlaceholder, isSkeleton: false
        )

        spaces.select(spaceID: row.id)
        await messages.select(spaceID: row.id, spaceTitle: row.title)

        XCTAssertEqual(spaces.selectedSpaceID, "space-1")
        XCTAssertEqual(messages.selectedSpaceID, "space-1")
        XCTAssertEqual(messages.selectedSpaceTitle, "General")
    }
}
```

- [ ] **Step 2: Register and run focused tests to verify RED**

Add the integration test file to the test group and Sources phase.

Run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/SpacesMessagesIntegrationTests \
  -only-testing:RedwingTests/SceneConfigurationTests/testSpacesCardExposesSelectionAndScrollBindings \
  -derivedDataPath /private/tmp/redwing-spaces-card-red CODE_SIGNING_ALLOWED=NO
```

Expected: source-contract test FAIL because the callback, binding, selected treatment, and scroll position are missing.

- [ ] **Step 3: Refactor `LaneSurfaceView` into the Spaces card contract**

Change its input to:

```swift
struct LaneSurfaceView: View {
    @ObservedObject var spaces: SpacesCoordinator
    @Binding var scrollAnchorID: String?
    let onSelectSpace: (SpaceRowViewModel) -> Void
```

Make each row call `onSelectSpace(row)`. Mark the lazy stack as a scroll target and bind the visible anchor:

```swift
Apply `.scrollTargetLayout()` immediately after the existing `LazyVStack` content and before its `.padding(18)`. Apply `.scrollPosition(id: $scrollAnchorID, anchor: .top)` to the enclosing vertical `ScrollView`.
```

Pass `isSelected: spaces.selectedSpaceID == row.id` into `SpaceGlassRow`. Add a restrained selection bubble without changing row dimensions:

```swift
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
```

Remove the internal `GlassEffectContainer` and outer `.padding(20)` from `LaneSurfaceView`; the new parent surface owns shared glass sampling and outer spacing. Keep the pane's `glassEffect`, clipping, row glass, skeletons, and pagination intact.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: both focused tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Redwing/Lanes/LaneSurfaceView.swift RedwingTests/SceneConfigurationTests.swift \
  RedwingTests/SpacesMessagesIntegrationTests.swift redwing.xcodeproj/project.pbxproj
git commit -S -m "feat: select spaces in restorable card"
```

### Task 5: Build the Read-Only Messages Card

**Files:**
- Create: `Redwing/Messages/MessagesSurfaceView.swift`
- Modify: `RedwingTests/SceneConfigurationTests.swift`
- Modify: `redwing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing Messages-card source tests**

Add a `messagesSurfaceViewSourceURL()` helper and these tests:

```swift
func testMessagesCardHasNativeGlassHeaderAndReadOnlyTimeline() throws {
    let source = try String(contentsOf: messagesSurfaceViewSourceURL(), encoding: .utf8)
    XCTAssertTrue(source.contains("struct MessagesSurfaceView"))
    XCTAssertTrue(source.contains("Image(systemName: \"xmark\")"))
    XCTAssertTrue(source.contains(".help(\"Close Messages\")"))
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
```

- [ ] **Step 2: Run tests to verify RED**

Register `MessagesSurfaceView.swift` in the Messages group and app Sources phase, then run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/SceneConfigurationTests/testMessagesCardHasNativeGlassHeaderAndReadOnlyTimeline \
  -only-testing:RedwingTests/SceneConfigurationTests/testMessagesCardRestoresScrollAndPaginates \
  -only-testing:RedwingTests/SceneConfigurationTests/testMessagesRenderUntrustedContentAsTextOnly \
  -derivedDataPath /private/tmp/redwing-messages-view-red CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the new view source is empty or missing its required behavior.

- [ ] **Step 3: Implement `MessagesSurfaceView`**

Implement the complete card in `MessagesSurfaceView.swift`:

```swift
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
            Divider().opacity(0.45)
            content
        }
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
            Button(action: onClose) { Image(systemName: "xmark") }
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
                    Task { await messages.retry() }
                }
                .buttonStyle(.glassProminent)
            }
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
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }

                    if let footerState = messages.footerState {
                        LanePaginationFooter(state: footerState)
                            .onAppear {
                                Task { await messages.loadNextPageFromFooterIfNeeded() }
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(16)
            }
            .scrollPosition(id: $visibleMessageID, anchor: .center)
            .animation(.easeInOut(duration: 0.22), value: messages.messageRows)
            .onAppear { restoreVisibleMessage(rowIDs: rowIDs) }
            .onChange(of: messages.selectedSpaceID) { _, _ in
                visibleMessageID = nil
                restoreVisibleMessage(rowIDs: messages.messageRows.map(\.id))
            }
            .onChange(of: visibleMessageID) { _, id in
                rememberVisibleMessage(id: id)
            }
            .onChange(of: rowIDs) { _, newIDs in
                guard let visibleMessageID, !newIDs.contains(visibleMessageID) else { return }
                restoreVisibleMessage(rowIDs: newIDs)
            }
            .onReceive(messages.$messageScrollRequest.compactMap { $0 }) { request in
                scroll(proxy, to: request.targetID)
            }
        }
    }

    private func restoreVisibleMessage(rowIDs: [String]) {
        guard let spaceID = messages.selectedSpaceID else { return }
        if let restored = navigation.restoredMessageID(spaceID: spaceID, rowIDs: rowIDs) {
            visibleMessageID = restored
        }
    }

    private func rememberVisibleMessage(id: String?) {
        guard let spaceID = messages.selectedSpaceID,
              let id,
              let index = messages.messageRows.firstIndex(where: { $0.id == id }) else {
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
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        Group {
            if row.isSkeleton {
                SkeletonRowView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.sender)
                            .font(.headline)
                            .lineLimit(1)
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(row.body)
                        .textSelection(.enabled)
                        .foregroundStyle(row.isDeletedTombstone ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .glassEffect(.regular, in: shape)
    }
}
```

Rows render untrusted message content through SwiftUI `Text` only. Do not add an HTML renderer, web view, external-resource loader, composer, or send action.

- [ ] **Step 4: Run focused source tests and the coordinator suite**

Run the command from Step 2, then:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/MessagesCoordinatorTests \
  -derivedDataPath /private/tmp/redwing-messages-green CODE_SIGNING_ALLOWED=NO
```

Expected: all selected tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Redwing/Messages/MessagesSurfaceView.swift RedwingTests/SceneConfigurationTests.swift \
  redwing.xcodeproj/project.pbxproj
git commit -S -m "feat: render read only message card"
```

### Task 6: Compose Shared Glass Cards and Preserve Every Tab

**Files:**
- Create: `Redwing/Lanes/SpacesMessagesSurface.swift`
- Modify: `Redwing/App/RedwingApp.swift:79-283`
- Modify: `Redwing/Lanes/LaneSurfaceView.swift:46-122`
- Modify: `RedwingTests/SceneConfigurationTests.swift`
- Modify: `RedwingTests/SmokeTests.swift`
- Modify: `redwing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing composition and root-wiring tests**

Add source helpers and tests:

```swift
func testSpacesMessagesSurfaceUsesSharedGlassAndStableIdentities() throws {
    let source = try String(contentsOf: spacesMessagesSurfaceSourceURL(), encoding: .utf8)
    XCTAssertTrue(source.contains("GlassEffectContainer(spacing: SpacesMessagesLayout.spacing)"))
    XCTAssertTrue(source.contains("glassEffectID(\"spaces-card\""))
    XCTAssertTrue(source.contains("glassEffectID(\"messages-card\""))
    XCTAssertTrue(source.contains("SpacesMessagesLayout.widths"))
    XCTAssertTrue(source.contains(".spring("))
}

func testSessionShellInjectsMessagesAndDoesNotResetTabIdentity() throws {
    let source = try String(contentsOf: redwingAppSourceURL(), encoding: .utf8)
    XCTAssertTrue(source.contains("let messages = rootModel.messagesCoordinator"))
    XCTAssertTrue(source.contains("@StateObject private var navigation = SessionNavigationState()"))
    XCTAssertTrue(source.contains("SpacesMessagesSurface("))
    XCTAssertFalse(source.contains(".id(selectedTab)"))
}

func testTeamsAndPeopleExposeIndependentScrollBindings() throws {
    let source = try String(contentsOf: laneSurfaceViewSourceURL(), encoding: .utf8)
    XCTAssertTrue(source.contains("TeamsLaneSurfaceView"))
    XCTAssertTrue(source.contains("@Binding var scrollAnchorID: String?"))
    XCTAssertTrue(source.contains("PeopleHierarchyView"))
    XCTAssertTrue(source.contains(".scrollTargetLayout()"))
}
```

Update `SmokeTests.testConfigureCreatesSessionCoordinatorsAndAttentionFeed` to unwrap and assert `messagesCoordinator` alongside the other coordinators.

- [ ] **Step 2: Register the surface and run focused tests to verify RED**

Add `SpacesMessagesSurface.swift` to the Lanes group and app Sources phase.

Run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -only-testing:RedwingTests/SceneConfigurationTests \
  -only-testing:RedwingTests/SmokeTests/testConfigureCreatesSessionCoordinatorsAndAttentionFeed \
  -derivedDataPath /private/tmp/redwing-shell-red CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the shared surface, coordinator injection, scene state, and scroll bindings are missing.

- [ ] **Step 3: Implement `SpacesMessagesSurface`**

Create the shared composition:

```swift
import SwiftUI

struct SpacesMessagesSurface: View {
    @ObservedObject var spaces: SpacesCoordinator
    @ObservedObject var messages: MessagesCoordinator
    @ObservedObject var navigation: SessionNavigationState
    @Namespace private var glassNamespace

    var body: some View {
        GeometryReader { geometry in
            let open = messages.selectedSpaceID != nil
            let widths = SpacesMessagesLayout.widths(
                totalWidth: geometry.size.width - 40,
                isMessagesOpen: open
            )

            GlassEffectContainer(spacing: SpacesMessagesLayout.spacing) {
                HStack(spacing: SpacesMessagesLayout.spacing) {
                    LaneSurfaceView(
                        spaces: spaces,
                        scrollAnchorID: $navigation.spacesScrollID,
                        onSelectSpace: openSpace
                    )
                    .frame(width: widths.spaces)
                    .glassEffectID("spaces-card", in: glassNamespace)

                    if open {
                        MessagesSurfaceView(
                            messages: messages,
                            navigation: navigation,
                            onClose: closeMessages
                        )
                        .frame(width: widths.messages)
                        .glassEffectID("messages-card", in: glassNamespace)
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: open)
            }
            .padding(20)
        }
    }

    private func openSpace(_ row: SpaceRowViewModel) {
        spaces.select(spaceID: row.id)
        Task { await messages.select(spaceID: row.id, spaceTitle: row.title) }
    }

    private func closeMessages() {
        messages.close()
    }
}
```

Do not clear `spaces.selectedSpaceID` on close; it remains a remembered selection while the open-card state is owned by `messages.selectedSpaceID`. The selected bubble may remain visible after close, and reopening it starts from its remembered message anchor.

- [ ] **Step 4: Wire the scene and tab-local state**

In `RedwingRootView`, unwrap `rootModel.messagesCoordinator` and pass it to `RedwingSessionView`.

In `RedwingSessionView`:

```swift
@ObservedObject var messages: MessagesCoordinator
@StateObject private var navigation = SessionNavigationState()
```

Bind the sidebar to `$navigation.selectedTab`. Replace `LaneSurfaceView` with `SpacesMessagesSurface`. Pass `$navigation.teamsScrollID` and `$navigation.peopleScrollID` into their views. Remove `.id(selectedTab)` so switching tabs does not deliberately reset local identity.

In `TeamsLaneSurfaceView` and `PeopleHierarchyView`, add `@Binding var scrollAnchorID: String?`, mark their stack as `.scrollTargetLayout()`, and bind `.scrollPosition(id: $scrollAnchorID, anchor: .top)`.

- [ ] **Step 5: Run focused and full tests**

Run the command from Step 2. Then run:

```bash
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/redwing-space-message-full CODE_SIGNING_ALLOWED=NO
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Redwing/App/RedwingApp.swift Redwing/Lanes/LaneSurfaceView.swift \
  Redwing/Lanes/SpacesMessagesSurface.swift RedwingTests/SceneConfigurationTests.swift \
  RedwingTests/SmokeTests.swift redwing.xcodeproj/project.pbxproj
git commit -S -m "feat: animate spaces and messages split"
```

### Task 7: Verify Build, Runtime Layout, Restoration, and Cleanup

**Files:**
- Modify only if verification finds a defect in files already listed above.

- [ ] **Step 1: Run project and package consistency checks**

```bash
git diff --check
xcodebuild -list -project redwing.xcodeproj
xcodebuild test -project redwing.xcodeproj -scheme Redwing -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/redwing-space-message-final CODE_SIGNING_ALLOWED=NO
```

Expected: no whitespace errors, the `Redwing` scheme is listed, and the full test suite reports `** TEST SUCCEEDED **`.

- [ ] **Step 2: Build a local Debug app**

```bash
xcodebuild build -project redwing.xcodeproj -scheme Redwing -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /private/tmp/redwing-space-message-run
```

Expected: `** BUILD SUCCEEDED **` and the app exists at `/private/tmp/redwing-space-message-run/Build/Products/Debug/Redwing.app`.

- [ ] **Step 3: Launch one app instance and perform the visual checklist**

Quit any existing Redwing process, then open the built `.app`. Verify:

1. One window opens.
2. Spaces is full width before opening a space.
3. Selecting a row animates to an exact visual `1:2` split without clipping or jitter.
4. The selected row remains highlighted.
5. The Messages card appears immediately with wave skeletons, then fades to content.
6. The header title is correct and the close icon has a tooltip.
7. Closing returns Spaces to full width and leaves no retained message updates.
8. Reopening restores the remembered message position.
9. Switching to Teams and People and back preserves every view's selection and scroll position.
10. A realtime snapshot updates the message timeline without jumping an intentionally scrolled timeline.
11. Bottom pagination displays `Searching for more...` and eventually `All found!`.
12. Narrowing the window to its minimum does not overlap or truncate card controls.

- [ ] **Step 4: Inspect runtime warnings and stream lifetime**

Use the macOS unified log for the Redwing process and verify there are no SwiftUI constraint loops, task-retention warnings, unredacted SDK failures, or repeated stream creation while switching tabs. Close Messages and confirm the fake lifecycle tests already prove stream cancellation; do not add persistent debug logging solely for this check.

- [ ] **Step 5: Final signed commit if verification required fixes**

If any verification fixes were needed:

```bash
git add Redwing RedwingTests redwing.xcodeproj/project.pbxproj
git commit -S -m "fix: stabilize spaces message restoration"
```

If no fixes were needed, do not create an empty commit.

## Deferred Work Guard

Do not implement thread rendering in this plan. Preserve the existing thread data in `MessagesCoordinator`, but do not expose selection as a nested card yet. The next plan will implement the approved one-fifth/four-fifths outer ratio, equal inner Messages/Thread split, pinned root-message header, and edge tether with top/bottom directional clamping.
