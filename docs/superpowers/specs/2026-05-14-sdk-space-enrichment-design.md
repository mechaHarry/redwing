# SDK Space Enrichment Design

## Goal

Consume `webex-swift-sdk` `v2.6.1` space enrichment snapshots in Redwing's
spaces-first UI without changing row layout, resetting skeleton state, or
causing list jitter as enriched fields arrive.

## Data Flow

Redwing continues to depend on the SDK only through `WebexSDKAdapter`. The SDK
owns REST enrichment, caching, retry/backoff, and snapshot refresh timing.
Redwing maps `WebexSpace.enriched.teamName` into its local `SpaceItem.teamName`
and `WebexSpace.enriched.spaceAvatar` into `SpaceItem.iconURL`.

## UI Projection

Spaces keep their existing stable row IDs. Initial skeleton rows remain until
the first real snapshot. Later enrichment snapshots update only row content for
the same spaces.

The team label priority is:

1. Enriched team name
2. Raw team ID
3. `Direct Message` when the space type is direct
4. `No team`

The row image remains fixed-size and continues using the current placeholder
until an enriched avatar URL is available and the image loads.

## Testing

Tests cover the SDK pin, adapter mapping of enriched team/avatar fields, and
coordinator row projection behavior when enrichment arrives after the base
snapshot.
