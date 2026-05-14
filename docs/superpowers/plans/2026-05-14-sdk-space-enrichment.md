# SDK Space Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire SDK `v2.6.1` space enrichment into Redwing's spaces list.

**Architecture:** Keep SDK-specific types inside `WebexSDKAdapter`, add minimal local DTO fields, and project them through `SpacesCoordinator` into the existing row model. SwiftUI layout remains unchanged.

**Tech Stack:** macOS SwiftUI, Xcode project, XCTest, tagged `webex-swift-sdk` package.

---

### Task 1: Pin SDK 2.6.1

**Files:**
- Modify: `redwing.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Test: `RedwingTests/ReleaseScriptTests.swift`

- [x] Write the failing test by changing the release guard to expect `version = 2.6.1;`.
- [x] Run the targeted release guard test and confirm it fails while the project remains pinned to `2.5.1`.
- [x] Update the project package pin and README current SDK version to `2.6.1`.
- [x] Run the targeted release guard test and confirm Xcode resolves `webex-swift-sdk @ 2.6.1`.

### Task 2: Map Enriched Space Fields

**Files:**
- Modify: `Redwing/Account/WebexClientProviding.swift`
- Modify: `Redwing/Account/WebexSDKAdapter.swift`
- Test: `RedwingTests/WebexSDKAdapterTests.swift`

- [x] Add a failing adapter test that expects `WebexSpace.enriched.teamName` to map to `SpaceItem.teamName`.
- [x] Add a failing adapter test that expects `WebexSpace.enriched.spaceAvatar` to map to `SpaceItem.iconURL`.
- [x] Add a failing adapter assertion that non-web avatar URLs are not exposed to the UI.
- [x] Add `teamName` to `SpaceItem` with a default nil initializer value.
- [x] Map `space.enriched.teamName` through `nonEmpty`.
- [x] Map `space.enriched.spaceAvatar` through a trimmed `http` or `https` URL.
- [x] Run the targeted adapter test.

### Task 3: Project Stable Enriched Rows

**Files:**
- Modify: `Redwing/Spaces/SpacesCoordinator.swift`
- Test: `RedwingTests/SpacesCoordinatorTests.swift`

- [x] Add a failing coordinator test that applies a base snapshot, then an enriched snapshot for the same IDs.
- [x] Assert row IDs remain stable, skeleton state stays false, team name replaces raw ID, direct spaces show `Direct Message`, and avatar URLs fill in later.
- [x] Implement a `teamLabel(for:)` helper with priority: enriched team name, raw team ID, `Direct Message` for direct spaces, `No team`.
- [x] Run the targeted coordinator test.

### Task 4: Verify and Commit

**Files:**
- All changed files

- [x] Run `git diff --check`.
- [x] Run targeted adapter, coordinator, and release guard tests.
- [x] Run the full Xcode test suite.
- [ ] Stage only intended files.
- [ ] Create a signed conventional commit.
