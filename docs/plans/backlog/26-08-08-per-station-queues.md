# Per-Station Queues (Cocina / Barra as separate screens)

## Status

Backlog. Deliberately **not** built yet. The kitchen queue currently splits each
order into station columns on one screen (shipped 2026-08-08). This plan records
the alternative we considered, and why we deferred it, so we do not re-litigate it
from scratch.

## What exists today

- `categories.station` is a string enum, `kitchen` (default) or `bar`, set per
  category in `Admin::CategoriesController`. See `app/models/category.rb`.
- `kitchen/index.html.erb` groups an order's items by
  `item.product.category.station` and renders one column per station that has
  items: two columns from `md:` up, stacked sections on phones.
- One route, one screen, one Turbo channel (`store_<id>_kitchen`). Everyone who
  works the pass sees every station.

## The idea

Give each station its own screen and its own sidebar entry, so a barista sees only
`Barra` and a cook sees only `Cocina`:

- `/kitchen/bar`, `/kitchen/kitchen` (or `/stations/:station`).
- Sidebar renders one entry per station **that the store actually uses**, derived
  from `Current.store.categories.active.distinct.pluck(:station)`, so a store with
  only kitchen categories never sees a Barra link.
- Per-station broadcast channels so a bar item's state change does not re-render
  the kitchen screen.
- Probably a per-user default station, the way `role` already picks a default
  screen.

## Why we deferred it

- **It splits the order.** The strongest thing about the current card is that
  "Mesa 1" appears once with everything that table is waiting on. Per-station
  screens mean nobody sees the whole order, and coordinating "the crepa is ready,
  where's the cappuccino" needs a second screen.
- **Two stations do not need it.** The value only appears at four or five
  stations, or when the stations are physically far enough apart that a shared
  screen is genuinely unreadable. Neither is true yet.
- **`Ordenes del Dia` already covers the whole-order view**, so the "where do I
  see everything for this table" answer exists, but it is an extra hop.
- **Sidebar churn.** A dynamic, store-dependent nav is a bigger change than it
  looks: it touches the layout, the role-to-default-screen mapping, and every
  navigation test.

## Triggers to revisit

Build this when any of these becomes true:

1. A store defines more than two stations, or the columns stop fitting a tablet.
2. Stations are in separate physical rooms and the shared screen is unusable.
3. Broadcast noise becomes a real problem, one station's traffic constantly
   re-rendering another's screen.

## Sketch, if we do build it

- Keep `/kitchen` as the combined view. Add per-station screens **alongside** it,
  never instead of it, so the whole-order view survives.
- `Category.stations` stays the source of truth. Do not add a `Station` model
  until a station needs attributes of its own (printer, display name, sort order).
- Broadcast to `store_<id>_station_<station>` and keep the combined channel, or
  have the combined screen subscribe to every station channel.
- A per-user `default_station` on `users`, alongside `role`.

## Related

- `docs/references/turbo-streams.md` for the channel layout.
- `docs/plans/backlog/26-03-17-audio-beep-notifications.md`, which would need to
  know which station a new item belongs to.
