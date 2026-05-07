# Redwing macOS App Foundation Design

Date: 2026-05-05

## Purpose

Redwing is a native macOS client for Webex data. It should make the app a
smooth reflection of SDK-owned state instead of a place where UI code performs
REST orchestration. The first foundation creates the native app shell, setup
flow, account session, shared realtime connection, attention-oriented menu bar,
and horizontal Spaces -> Messages -> Threads experience.

The SDK baseline is `webex-swift-sdk` `v2.5.1` from:

- Package: `https://github.com/mechaHarry/webex-swift-sdk.git`

The SDK owns OAuth, token refresh, Keychain-backed credential storage,
authenticated REST transport, graceful retry/backoff, snapshot streams,
realtime triggers, and `MessagesThreadStream`.

## Scope

Redwing v1 is a native macOS Xcode app foundation, not a full Webex clone. It
includes:

- `redwing.xcodeproj`
- tagged remote Swift package dependency wiring to `webex-swift-sdk` `v2.5.1`
- local development signing and entitlements
- a native first-run setup screen
- one active Webex account
- one shared realtime WebSocket connection after auth
- a horizontal lane surface for Spaces -> Messages -> Threads
- menu bar plus Dock activation
- an attention-only menu bar feed
- a thin bottom status bar with diagnostics
- strict tests around each feature boundary

The first app is read-only. Sending, editing, and deleting Webex data are out
of scope for this foundation.

Also out of scope:

- multi-account routing
- global hotkey
- disk persistence of message/thread content
- Search
- Meetings
- Space Tabs
- Devices
- Teams
- Status Page
- custom Metal rendering beyond preserving architecture room for it

## Product Shape

The primary UI is a native macOS horizontal lane surface:

```text
Spaces -> Messages -> Threads
```

The first implementation uses a fluid horizontal rail. The layout model should
already represent lanes by identity, selection, focus weight, min width,
preferred width, visibility, and loading status. This lets a later iteration
compress inactive lanes horizontally and give the focused lane more room without
rewriting data ownership.

The Threads lane appears only when a selected/focused message has thread
structure worth showing. If a selected message is standalone, the Threads lane
stays hidden or collapsed so horizontal space remains focused on Spaces and
Messages.

## Architecture

Redwing should use explicit boundaries.

### `RedwingApp`

Owns app lifecycle, menu bar scene, main window scene, Dock/menu activation,
and focus-following window placement.

### `Setup`

Native SwiftUI/AppKit setup flow for:

- client ID
- client secret
- redirect URI
- requested scopes
- OAuth start
- granted-scope validation
- setup and auth error presentation

Secrets must go through SDK-backed Keychain storage. Non-secret app
preferences may live in app preferences.

### `AccountSession`

A single active-account coordinator. It creates or loads the SDK registry
account, owns the active `WebexClient`, starts and cancels the shared realtime
connection, exposes connection state, and provides stream factories to feature
coordinators.

This is the boundary between SDK infrastructure and app features.

### Data Coordination

Small coordinators should own:

- Spaces
- selected-space Messages
- selected-message Threads
- Attention Feed
- session Diagnostics

They subscribe to SDK snapshots, map SDK models into app view models, retain
selection/loading/error state, and keep the UI stable while data is not ready.

### Lane UI

Native SwiftUI views only. UI code observes app view models and never calls
Webex REST directly.

### Window Management

A narrow AppKit bridge handles "follow focus" behavior and keeps window logic
away from feature views.

## Data Flow

On launch, Redwing checks for a usable active account. If none exists, it shows
setup. If one exists, `AccountSession` builds a `WebexClient`, validates
granted scopes for the selected feature profile, starts one shared realtime
connection, and exposes connection status to the main window, menu bar, and
status bar.

Spaces use:

```swift
client.spaces.stream(
    params: .init(sortBy: .lastActivity, max: pageSize),
    pageLimit: pageLimit
)
```

Selecting a space creates or replaces one selected-space `MessagesThreadStream`:

```swift
client.messages.threadedStream(
    params: .init(roomID: selectedSpaceID, max: pageSize),
    pageLimit: pageLimit
)
```

The Messages lane and Threads lane share this same stream and the same
`WebexMessageThreadSnapshot`. Redwing must not create a second thread-specific
REST or stream path for the Thread lane.

The Messages lane renders message entries from the shared thread snapshot. When
the user selects a message, Redwing checks the selected entry in
`threadEntryByID`. The Thread lane appears only when the selected entry has
children, parent context, placeholder parent context, tombstone context, or
another meaningful thread relationship.

Realtime triggers refresh the appropriate streams through SDK
`refreshOnTriggers`, filtered by resource and room ID. Both Messages and
Threads update from the same snapshot revision, avoiding split state between
message list and thread detail.

The UI never calls REST directly. It observes app view models. Old snapshots
remain visible during refresh or pagination.

## Attention Feed

The menu bar defaults to an attention-only feed, not all recent messages.

The SDK does not expose a separate Webex notifications API in `v2.5.1`, so
Redwing owns an attention projection over loaded and realtime-refreshed message
data.

The first feed includes messages that:

- mention the current user through `mentionedPeople`
- include group mentions such as `all` through `mentionedGroups`

The feed should not fan out across every space in v1. It reflects the currently
watched/loaded spaces and messages, with clear empty and loading states. Global
all-space attention can be added later with explicit API load controls.

## Menu Bar And Activation

Redwing supports menu bar plus Dock activation in v1.

The menu bar is not just a launcher. It should show the attention feed by
default, with actions to:

- open or focus the main Redwing window
- jump to an attention item when enough context is loaded
- show setup/account state
- show connection health

Global hotkey support is deferred.

## Status Bar And Diagnostics

The main window includes a thin native bottom status bar. It has compact
sections with green, red, or yellow glowing indicators for:

- realtime WebSocket state
- access token/session validity
- active account/setup state
- selected Spaces stream state
- selected Messages/Threads stream state
- attention feed state

The status bar should stay quiet when healthy and become useful when something
is wrong. Each indicator needs a tooltip or accessible label with the current
state, such as connected, reconnecting, reauth required, refreshing, rate
limited, or last refresh failed.

The status bar includes a diagnostics button. Opening it reveals a session-only
diagnostics stream accumulated from:

- SDK connection states
- redacted SDK realtime diagnostic events
- setup/auth errors
- lane errors
- attention feed errors
- app coordinator state changes that help explain what is working or failing

Diagnostics entries include timestamp, source, severity, short message, and
optional redacted technical detail. Diagnostics are not persisted to disk and
can be cleared during the current session.

## Loading And Placeholders

Redwing should use skeleton inserts everywhere real data may arrive
asynchronously.

During first load, refresh, pagination, setup validation, and stream
replacement, each lane keeps a stable visual structure with native skeleton
rows sized like real content. Refreshes keep the last valid snapshot visible.
Pagination appends skeleton rows at the loading edge.

Selecting a space or message should not cause lane widths, row heights, or the
mouse target under the pointer to jump. Data may update, but the user's spatial
context should stay stable.

Skeletons are app-owned view models, not fake SDK data.

## Window Behavior

Redwing follows the user's current context. When invoked from the Dock or menu
bar, it should bring the main window to the current active desktop/display
instead of switching the user back to a previous macOS Space.

The AppKit bridge owns:

- discovering the active screen/window placement context
- showing the main window if it is closed or hidden
- repositioning the window into the current desktop/display when invoked
- keeping a stable default size for the lane surface
- preserving normal macOS window controls and native materials

Mouse interaction is primary in v1. Keyboard navigation should be anticipated
in the architecture but not overbuilt.

## Error Handling And Security

All Webex API traffic stays inside the SDK so Redwing inherits SDK retry,
backoff, `Retry-After`, cancellation, redaction, token refresh, Keychain
storage, and realtime reconnect behavior. Redwing should not add parallel
HTTP clients or custom retry loops for Webex data.

Setup errors should be user-facing and specific:

- missing credentials
- OAuth cancelled
- redirect failure
- missing granted realtime scopes
- Keychain entitlement/storage failure
- reauthorization required

Runtime data errors stay local to their lane, menu feed, or status bar while
the last valid snapshot remains visible.

Security requirements:

- Store client secret, refresh tokens, and account token records only through
  SDK/Keychain storage.
- Store only non-secret app preferences in app preferences.
- Do not log tokens, client secrets, OAuth callback URLs, WebSocket URLs, raw
  message bodies, or attachment URLs.
- Do not persist message/thread content to disk.
- Keep realtime diagnostics redacted and developer-oriented.
- Make all long-lived tasks cancellable when setup changes, account removal
  happens, the app quits, or a stream is replaced.
- Treat SDK placeholder parents and tombstones as data states. Do not infer
  deleted content unless the SDK marks a tombstone.

## Testing

Every feature requires strict tests. Tests should avoid live Webex dependencies
and use fakes around SDK-facing boundaries. Live Webex smoke tests remain in
the SDK repo.

Setup tests cover validation, non-secret preference storage, Keychain/SDK error
mapping, granted-scope handling, and reauth-required states.

`AccountSession` tests verify one active account, shared realtime startup and
cancellation, state transitions, and cleanup.

Stream coordinator tests verify Spaces snapshots, selected-space
`MessagesThreadStream` sharing, trigger filtering by room ID, loading states,
pagination flags, and snapshot retention during refresh errors.

Attention feed tests verify current-user mention detection, `all` group
mentions, no all-message fan-out, ordering, deduping, and session-only behavior.

Status bar and diagnostics tests verify indicator state mapping, redaction,
session accumulation, clear behavior, and no disk persistence.

Lane layout tests verify lane visibility, focus weights, min/preferred widths,
stable skeleton sizing, stable selected IDs, and Thread lane visibility only
for selected messages with thread structure.

Window bridge tests should isolate pure placement calculations where possible.
Manual verification covers actual macOS Space behavior because it is difficult
to unit test reliably.

UI tests or previews cover setup, empty/loading/error states, skeleton states,
and the main lane surface with fake data.

## Implementation Notes

The implementation plan should preserve these boundaries:

- build the Xcode project and app shell first
- introduce SDK-facing protocols/fakes before feature UI
- add setup and account session before data panes
- build Spaces, then shared Messages/Threads stream coordination
- add attention feed and menu bar after message data exists
- add bottom status bar and diagnostics early enough to support debugging
- verify with unit tests before live Webex smoke validation

No feature should bypass the SDK for Webex API calls.
