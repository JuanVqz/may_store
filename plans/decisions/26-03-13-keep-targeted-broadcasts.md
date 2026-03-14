# Decision: Keep Targeted Turbo Stream Broadcasts

**Date:** 2026-03-13
**Context:** Single-page order flow refactor

## Options Considered

### A. Turbo Morph Refreshes (rejected for now)

- `broadcasts_refreshes` on models + `<meta name="turbo-refresh-method" content="morph">` in views
- Simpler code: no custom broadcast methods, no target IDs, no broadcast-specific partials
- Automatic state preservation (scroll, focus, open accordions)
- Higher server load: every connected client re-fetches the full page on each change
- Can be scoped per-page (meta tags only in specific views), so it wouldn't affect the rest of the app

### B. Targeted Turbo Stream Broadcasts (chosen)

- Current approach: models broadcast specific partials to specific DOM targets via ActionCable
- Already implemented and tested for Order, LineItem, and Table updates
- Lower server load: only renders the small partial that changed
- More code to maintain: custom broadcast methods, target IDs, partial sync

## Decision

**Keep targeted broadcasts.** The current infrastructure works and is already tested. Morph is a future option that can be adopted per-page without a full rewrite — no need to switch now.

## Revisit When

- The single-page order flow has many interactive elements that lose state on broadcast replaces
- Maintaining broadcast methods and target IDs becomes a pain point
- We add more real-time views (e.g., kitchen queue) and the broadcast boilerplate grows
