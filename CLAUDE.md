# MayStore

## Project

Multitenant order management system for food/beverage businesses (cafes, restaurants). Spanish-first UI.

## Documentation

All specs live in `docs/`. Read these before making architectural decisions:

- `docs/README.md` — Overview, tech stack, key design decisions
- `docs/references/models.md` — ER diagram, all models, status flows, code examples
- `docs/references/wireframes.md` — All 14 screens with ASCII wireframes
- `docs/references/turbo-streams.md` — Broadcast channels and Turbo Stream architecture
- `docs/references/reference-patterns.md` — Patterns extracted from the Fizzy codebase
- Root `README.md` — What the app does, with screenshots. Public-facing.
- Seed data: `db/seeds.rb`
- Spanish locale: `config/locales/es.yml`

## Tech Stack

- Ruby 4.0 / Rails 8.1
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Minitest (default)
- No external gems for: money (PriceCents concern), soft delete (SoftDeletable concern), auth (has_secure_password)

## Conventions

- **37signals Rails conventions**: `Current` for request state, `normalizes`, explicit scopes (no `default_scope`)
- **I18n**: All user-facing text from locale files. Default locale: `:es`
- **Multitenancy**: Subdomain-based, scoped by `Current.store`
- **Money**: Integer cents columns, `PriceCents` concern for helpers
- **Enums**: String-backed Rails enums, no lookup tables
- **Tests**: Minitest + fixtures. Test models, critical flows, and edge cases.

## Running the App Locally

The store is resolved from the subdomain, so plain `localhost:3000` returns "store not found". Use a subdomain host:

```
http://cafe.localhost:3000    # Cafe Delicias
http://pizza.localhost:3000   # Pizzeria Don Mario
```

`lvh.me` does NOT work: Rails' default `tld_length` of 1 parses `cafe.lvh.me` as the subdomain `cafe.lvh`, which matches no store.

Seeded logins use an employee number, not an email. Password is `password123` for all of them: `EMP-001` (waiter), `KIT-001` (kitchen), `ADM-001` (admin).

## Testing Gaps

`test/system/` is empty, so nothing exercises rendered views end to end. Controller tests use fixtures that often lack the interesting rows (for example, no fixture order has an `extra` line item component, which is why a crash in the bill view went unnoticed). When touching a view, either boot the app and load the page or add fixtures that cover the branch.

## Plans

Implementation plans live in `docs/plans/` with a kanban-style structure:

- `docs/plans/backlog/` — Planned work, not yet started
- `docs/plans/in_progress/` — Currently being worked on
- `docs/plans/done/` — Completed plans (kept for reference)

Plan files are named `YY-MM-DD-plan-description.md` (e.g., `26-03-13-add-auth.md`). Before starting a task, check `docs/plans/in_progress/` for active plans. Move plans between folders as work progresses.

- `docs/plans/decisions/` — Architecture and design decisions with rationale (`YY-MM-DD-decision-description.md`). Decisions explain *why* we chose X over Y and remain relevant after plans are done.

## Git Integration

When merging worktree branches into main, use squash merge (`git merge --squash`) or rebase — never regular merge commits. This keeps history linear with one commit per feature.

## Worktrees

Use git worktrees for all feature work. Worktrees live in `.worktrees/` (repo root, not `.claude/worktrees/`).

Branch naming convention: `{type}/{short_description}` using snake_case:
- `feature/kitchen_queue` — new functionality
- `fix/deliver_broadcast_stale_data` — bug fix
- `chore/update_turbo_rails` — dependency updates, config changes
- `maintenance/refactor_broadcasts_to_morph` — refactoring, cleanup

Create with:
```bash
git worktree add .worktrees/feature/kitchen_queue -b feature/kitchen_queue
```

Remove when done (after merge):
```bash
git worktree remove .worktrees/feature/kitchen_queue
```

## Migrations

Not in production yet — when a migration needs changes, rollback (`rails db:rollback`), edit the existing migration file, and re-run (`rails db:migrate`). Do NOT create a new migration to alter a table that hasn't shipped.

## Reference Codebase

`/Users/juan/code/mine/fizzy` — Production Rails app using Hotwire Native. Use as reference for:
- Controller concerns pattern (slim ApplicationController, modular concerns)
- Model concerns by behavior (Closeable, Assignable, etc.)
- Turbo Morph broadcasts (`broadcasts_refreshes`, `broadcast_refresh_to`)
- CSS platform separation (`native.css`, `ios.css`, `android.css` with `@layer`)
- Bridge controllers for Turbo Native (`@hotwired/hotwire-native-bridge`)
- Test patterns (`Turbo::Broadcastable::TestHelper`, fixture organization)

See `docs/references/reference-patterns.md` for detailed patterns extracted from this codebase.

## Dependencies

Dependabot runs weekly on Monday and groups bumps into one PR per ecosystem (bundler minor/patch, and all github-actions). Major bundler bumps still arrive as individual PRs so they get a real review.

## Key Rules

- Never add co-author lines to commits
- No commits or PRs on weekends — all git operations paused Saturday/Sunday
- Role = default screen, not permissions. All roles can perform all item actions.
- No unique index on `line_item_components(line_item_id, component_id)` — duplicates allowed for multiple extras
- Order codes use `OrderCounter` table for atomic sequence generation
- `LineItem` auto-recalculates order total via callbacks
- Soft delete uses explicit scopes (`Product.active`), never `default_scope`
