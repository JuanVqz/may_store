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

## Testing

Three layers, and the rule is to test at the lowest level that can actually catch the bug:

- **Model tests** for business rules.
- **Integration tests** (`test/controllers/`, `test/integration/`) for status codes, redirects, server-rendered HTML, auth boundaries, and tenant scoping. Fast and deterministic, but blind to JavaScript.
- **System tests** (`test/system/`) for anything needing a real browser: Stimulus, Turbo Streams, confirm dialogs, multi-screen flows.

System tests browse a subdomain host, because the store resolves from the subdomain. `ApplicationSystemTestCase` starts Chrome with `--host-resolver-rules=MAP * 127.0.0.1` so `cafe-delicias.example.com` reaches the Capybara server on any machine. Use the `visit_store` and `sign_in_waiter` / `sign_in_kitchen` / `sign_in_admin` helpers.

Two traps worth knowing:

- **Do not assert flash text in a system test.** Flash renders through the toaster component, which auto-dismisses after five seconds, so the assertion is racy under parallel load. Assert flash content in an integration test instead.
- **Wait for the UI before asserting the database.** After clicking, assert on visible text first, then check the record. Asserting `record.reload.status` straight after a click races the request.

Fixtures deliberately keep `mesa_2` free of orders so tests have a genuinely available table.

## View Layer (ReActionView / Herb)

`reactionview` (dev/test only) routes all `.html.erb` through `Herb::Engine`, so invalid HTML raises in tests and shows an overlay in development. Config: `config/initializers/reactionview.rb` (guarded with `defined?(ReActionView)` because the gem is absent in production) and `.herb.yml` (linter rules, version pin, `public/` excluded).

**Touched a view? Run the linter before committing.** It takes about a second over the whole app, so there is no reason to discover an offense from CI:

```
bundle exec herb lint          # all 100 rules, ~1s over 56 files
bundle exec herb lint --fix    # autocorrect what it can
bundle exec herb format <file> # formatter is disabled by default in .herb.yml
```

The same linter runs in CI as the `lint_views` job, and it fails the build on any error-severity offense. It shells out to `npx @herb-tools/linter`, so Node is required.

Because `intercept_erb` is on, malformed HTML also fails the **test** suite, not just the linter. A render failure in a test may be an HTML content-model error rather than a Ruby error, so read the message before hunting through the Ruby.

### Write it right the first time

Every item below is a rule that is on. These are the ones this codebase actually tripped over:

- **Never emit an attribute name, or a whole attribute, from ERB.** `<%= 'checked' if x %>` and `<%= 'data-controller="y"' if x %>` are both offenses. Put the ERB in the attribute *value* (`data-controller="<%= "y" if x %>"`) or use the Rails helper (`radio_button_tag`, `check_box_tag`).
- **Not a link? Not an `<a>`.** Anything that only fires a Stimulus action is `tag.button ... type: "button"`. `<a href="#">` is an offense, and the explicit `type` matters because a bare `<button>` inside a form submits it. `[data-component="button"]` styling is element-agnostic, so the swap is free.
- **Every `<input>` needs `autocomplete`.** Use a real token where one fits, `off` otherwise.
- **No block elements inside inline ones.** A `<div>` inside a `<label>` is invalid; use `<span class="block ...">`, which renders identically under Tailwind.
- **Every `<nav>` needs `aria-label`** (or `aria-labelledby`), from a locale key.
- **Never use `title=`, `accesskey=`, or `autofocus`**, and never nest interactive elements (`<button>` inside `<a>`).
- **New partial? Declare strict locals** before writing the body.

Deliberate exceptions go in `.herb.yml` as a rule-level `exclude:` with a comment explaining why, so they stay reviewable. Do not reach for one until the rule is actually wrong for the case.

**All 100 rules are on**, including the 15 Herb ships disabled, listed explicitly under `linter.rules` in `.herb.yml`. The only exception is `a11y-no-autofocus-attribute`, excluded for `orders/bill.html.erb` (the cashier register screen). When Herb adds rules, `herb lint --upgrade` bumps `version:` and disables the new ones, so review them and turn them on deliberately.

**Every partial declares strict locals.** A new partial needs a `<%# locals: (...) %>` line followed by a blank line, or `<%# locals: () %>` when it takes none. Optional locals get a default (`highlight: false`) instead of a `local_assigns[:highlight]` lookup. Missing and undeclared locals both raise at render time, including under `Herb::Engine`.

`herb:disable` comments are **line-scoped**: they only suppress offenses reported on their own line, and a multi-line tag anchors its offense to the line the tag opens on. When the offending element spans lines, scope the exception with a rule-level `exclude:` in `.herb.yml` instead, where it stays reviewable.

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
- Touched a view? Run `bundle exec herb lint` before committing, and never suppress a rule without a comment saying why. See "View Layer"
- Role = default screen, not permissions. All roles can perform all item actions.
- No unique index on `line_item_components(line_item_id, component_id)` — duplicates allowed for multiple extras
- Order codes use `OrderCounter` table for atomic sequence generation
- `LineItem` auto-recalculates order total via callbacks
- Soft delete uses explicit scopes (`Product.active`), never `default_scope`
