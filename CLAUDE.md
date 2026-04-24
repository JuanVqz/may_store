# MayStore

## Project

Multitenant order management system for food/beverage businesses (cafes, restaurants). Spanish-first UI.

## Documentation

All specs live in `docs/`. Read these before making architectural decisions:

- `README.md` — Overview, tech stack, key design decisions
- `models.md` — ER diagram, all models, status flows, code examples
- `wireframes.md` — All 14 screens with ASCII wireframes
- Seed data: `db/seeds.rb`
- Spanish locale: `config/locales/es.yml`

## Tech Stack

- Ruby 3.4 / Rails 8.1
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

## Plans

Implementation plans live in `plans/` with a kanban-style structure:

- `plans/backlog/` — Planned work, not yet started
- `plans/in_progress/` — Currently being worked on
- `plans/done/` — Completed plans (kept for reference)

Plan files are named `YY-MM-DD-plan-description.md` (e.g., `26-03-13-add-auth.md`). Before starting a task, check `plans/in_progress/` for active plans. Move plans between folders as work progresses.

- `plans/decisions/` — Architecture and design decisions with rationale (`YY-MM-DD-decision-description.md`). Decisions explain *why* we chose X over Y and remain relevant after plans are done.

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

See `docs/reference-patterns.md` for detailed patterns extracted from this codebase.

## Key Rules

- Never add co-author lines to commits
- No commits or PRs on weekends — all git operations paused Saturday/Sunday
- Role = default screen, not permissions. All roles can perform all item actions.
- No unique index on `line_item_components(line_item_id, component_id)` — duplicates allowed for multiple extras
- Order codes use `OrderCounter` table for atomic sequence generation
- `LineItem` auto-recalculates order total via callbacks
- Soft delete uses explicit scopes (`Product.active`), never `default_scope`
