# Decision: Targeted Broadcasts → Turbo Morph

**Date:** 2026-03-13 (original), **Updated:** 2026-03-18

## Original Decision (2026-03-13)

Keep targeted Turbo Stream broadcasts (manual `broadcast_replace_to`/`broadcast_append_to`/`broadcast_remove_to`). The infrastructure worked and was tested.

## Reversal (2026-03-18)

**Switched to Turbo Morph.** The targeted broadcast approach became untenable as real-time views grew.

### Why we switched

Adding the kitchen queue revealed the cost of targeted broadcasts:
- 5+ broadcast methods across 2 models (~70 lines of broadcast code)
- Stale data bugs from in-memory associations in broadcast callbacks
- Double broadcasts causing DOM flicker
- Every new real-time feature (queue count, empty state, readiness progress, takeouts) required new broadcast methods and DOM target coordination
- Actions triggered from one view (kitchen) sent turbo_stream responses targeting DOM elements that only existed on another view (order show)

### What morph gives us

- **4 lines replace ~70**: each model has one `broadcast_refreshes` method broadcasting `broadcast_refresh_to` to its channels
- **No stale data**: morph re-renders the full page with fresh data from the server
- **No DOM target coordination**: no need to match partial names, target IDs, or broadcast actions
- **Free features**: queue count, empty state, readiness progress all "just work" because the page re-renders
- **Actions use redirects**: `ready`, `deliver`, `cancel` just `redirect_back` — morph handles all page updates across all connected clients

### Tradeoff accepted

- Higher server load per update (full page re-render vs small partial)
- At cafe/restaurant scale this is negligible
- Audio beep notifications need a different approach (deferred to backlog)
