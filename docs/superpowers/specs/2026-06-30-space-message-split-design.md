# Space and Message Split Design

## Goal

Restore read-only space and direct-message contents without disturbing the newer Spaces, Teams, and People shell. Opening a space changes the Spaces surface from a full-width card into the left third of an animated two-card layout. The selected space's messages materialize in the remaining two thirds.

This phase deliberately excludes composing messages and opening threads. It must establish a stable message card and persistent per-view navigation state before thread presentation is added.

## Approved Interaction

The Spaces tab has two phase-one states:

1. With no open space, the Spaces card occupies the full available content width.
2. With an open space, the Spaces card occupies one third and a Messages card occupies two thirds.

Selecting a space opens its message stream. Selecting another space keeps the split open and replaces the Messages card's contents in place. The selected space row remains visibly active.

The Messages card has a restrained, faded glass header containing the space title and an icon-only close button. The button has a tooltip and accessibility label. Closing is the only action that collapses the Messages card and returns Spaces to full width.

Switching to Teams or People suspends the Spaces view instead of resetting it. Returning to Spaces restores the same selected space, `1:2` split, message selection, loaded snapshot, and scroll position.

## Layout and Animation

Use an animated weighted `HStack`, not `NavigationSplitView` or `HSplitView`. The exact ratios and materialization behavior are product requirements rather than user-resizable navigation columns.

The Spaces and Messages cards live in one `GlassEffectContainer`. Each card receives a stable `glassEffectID` in a shared namespace so the system can produce coherent glass morphing. Opening and closing uses a short spring animation:

- Opening contracts Spaces from full width to one third while Messages fades, scales slightly, and materializes into two-thirds width.
- Closing reverses the transition and expands Spaces to full width.
- Switching spaces does not remove the Messages card. Only its header and timeline content transition.

Minimum widths protect both cards in narrow windows. The requested ratio applies after spacing is removed from the available width. The existing minimum app window width remains the lower supported boundary.

## Components and Ownership

`RedwingSessionView` continues to own the long-lived coordinators and passes `MessagesCoordinator` into the Spaces tab.

`SpacesMessagesSurface` owns the high-level visual composition only. It observes Spaces selection and decides whether to render one card or the `1:2` split.

`LaneSurfaceView` remains responsible for the Spaces card, including its list, skeletons, selection highlight, and pagination. Its selection callback supplies both the space identifier and title.

`MessagesSurfaceView` is a new read-only card responsible for the faded header, close action, loading/error content, timeline, scroll restoration, and pagination presentation.

`MessagesCoordinator` remains the data owner. Its existing stream-generation checks, snapshot mapping, selected-message persistence, realtime updates, and scroll targets are reused. It gains an explicit close operation that cancels the active stream and clears open-space presentation state without affecting other tabs.

UI state stays isolated from SDK data. No SwiftUI view calls the SDK directly.

## Message Timeline

The Messages card appears immediately after selection with stable skeleton rows and the existing wave animation. Snapshot content fades into place without changing the outer card dimensions.

The timeline is a lazy vertical scroll surface. Each read-only row shows sender, the message body already selected by the established markdown-then-HTML-then-text SDK mapping, and timestamp. No composer or send action is present.

On a space's first open, the timeline restores that space's remembered message anchor when one exists; otherwise it starts at the latest message. Returning from another top-level tab must not issue a new scroll-to-latest request. New realtime snapshots update data without overriding an intentional user scroll position.

The saved anchor records both message ID and its last visible index. If that ID no longer exists, restoration uses the row at the clamped saved index; if no rows exist at that index, it uses the latest message. Pagination uses the established `Searching for more...` and `All found!` footer states.

## Persistent View State

Every top-level view has independent scene-scoped presentation state:

- Spaces: list scroll anchor, selected/open space, and whether the Messages card is open.
- Messages: selected space, selected/focused message, timeline scroll anchor, loaded snapshot, and existing per-space remembered selection.
- Teams: list scroll anchor and selected team.
- People: hierarchy scroll anchor.
- Main shell: selected top-level tab.

Tab switching hides and reveals surfaces without recreating coordinators, restarting streams, clearing selections, or forcing scroll requests. The active message stream continues updating while Spaces is hidden. Restoration prioritizes the saved user anchor over newly arrived content.

This state is scene-scoped rather than a global application preference. Its ownership remains local to the main scene and is not migrated into process-wide storage.

## Realtime, Cancellation, and Errors

The open message stream continues to consume snapshot updates from the SDK. Updates animate into existing rows and do not collapse or recreate the Messages card.

Rapidly switching or closing spaces cancels the prior stream. Existing generation checks prevent stale snapshots from replacing the currently selected space.

Initial and pagination failures remain inside the Messages card. User-facing text is generic and includes a retry action where recovery is possible. Redacted technical details continue to flow to diagnostics. Failure never exposes credentials or raw SDK errors and never collapses the split automatically.

## Deferred Thread Design

Thread presentation is explicitly outside phase one, but its approved geometry constrains the layout architecture:

- Opening a thread changes the outer ratio to one-fifth Spaces and four-fifths Messages.
- The larger Messages container divides its inner content equally between the main message timeline and a nested Thread glass card.
- The Thread card independently scrolls replies.
- The original root message remains pinned as a floating glass header at the top of the Thread card even when replies scroll.
- An edge tether visually connects the selected root row to the Thread card.
- While the root row is visible, the tether aligns directly with it.
- When the root is above or below the message viewport, the tether clamps to the corresponding top or bottom edge and shows an upward or downward direction indicator.
- Closing the nested Thread card restores the phase-one `1:2` layout without closing the selected space.

## Testing

Strict tests cover:

- Full-width Spaces changing to and from the exact `1:2` layout.
- Animated insertion and removal of the Messages card with shared glass identities.
- Selecting a space opening the matching message stream with identifier and title.
- Switching spaces while keeping the Messages card present.
- Closing the card cancelling its stream and restoring full-width Spaces.
- Selected-row presentation.
- Skeleton-to-content transitions.
- Initial latest-message positioning and remembered-position restoration.
- Returning from Teams or People without losing any tab's selection or scroll anchor.
- Hidden-view realtime updates without forced scrolling on restoration.
- Pagination footer states and next-page requests.
- Stale-stream rejection and generic error/retry presentation.
- Stream task cancellation and coordinator release after close, guarding against retained subscriptions.
- Untrusted message content remaining data-only, with no executable HTML or external resource loading.
- No composer or send control in phase one.

The full existing test suite must remain green. A local Debug build is launched for a visual pass over open, close, space switching, tab restoration, narrow-window constraints, skeleton transitions, and realtime updates.

## Success Criteria

The phase is complete when a user can open any space or direct message, read its live message timeline in a stable animated `1:2` glass layout, switch among all top-level views without losing browsing position, and explicitly close the Messages card to return to the full-width Spaces list.
