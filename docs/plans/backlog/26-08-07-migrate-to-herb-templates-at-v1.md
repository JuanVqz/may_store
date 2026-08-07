# Migrate to `.html.herb` templates when ReActionView hits 1.0

## Trigger, not a date

Do not start this because time passed. Start it when **all** of these are true:

- `reactionview` is at `1.0` or later (it was `0.3.0` when Herb was adopted).
- `herb` is at `1.0` or later (it was `0.10.3`).
- The `intercept_erb` path has been running in development and CI for a few months with no rendering divergence from Erubi.
- The Herb changelog has stopped introducing rules and engine behavior in patch releases. `herb lint --upgrade` is the tell: if every bump still brings new default-off rules, the surface is still moving.

If any of those is false, close this and come back later. There is no deadline and nothing is broken today.

## What the migration actually is

Today `reactionview` sits in `:development, :test` and `intercept_erb = true` routes `.html.erb` through `Herb::Engine` in those environments only. Production renders through stock Erubi. The linter and the HTML validation are the whole benefit we take.

Going further means two separate decisions, and they are worth keeping separate:

### Step 1: gem to the root Gemfile

Move `reactionview` out of `:development, :test` so it loads in production, and delete the `return unless defined?(ReActionView)` guard in `config/initializers/reactionview.rb`.

Consequences to think through before doing it:

- `Herb::Engine` becomes the production render path for every `.html.erb`. Any divergence from Erubi becomes a customer-facing bug rather than a local one.
- `validation_mode` defaults to `:overlay` outside test. Decide explicitly what production should do with invalid HTML. `:none` is probably right for production; an overlay in front of a cashier is not.
- `herb`'s native extension ships in the production bundle.
- The dev-tools JS assets are already gated on `Rails.env.development?` inside the railtie, so they will not leak into production. Verified in `lib/reactionview/railtie.rb`, but re-check at 1.0.

A useful halfway house: gem at root, `config.intercept_erb = !Rails.env.production?`. That keeps `.html.herb` viable everywhere while leaving production on Erubi.

### Step 2: rename templates to `.html.herb`

Only worth doing after step 1, because `.html.herb` files cannot render at all without the gem loaded. Herb registers the `:herb` template handler unconditionally, so the rename is mechanical:

```sh
git ls-files 'app/views/**/*.html.erb' | while read -r f; do
  git mv "$f" "${f%.html.erb}.html.herb"
done
```

Then check what breaks:

- `.herb.yml` `files.include` already lists `**/*.herb` and `**/*.html.herb`, so the linter follows the rename with no config change.
- Turbo Stream templates are `.turbo_stream.erb`, not `.html.erb`. They are a separate format and the rename does not apply.
- Grep for hardcoded template names before renaming. As of this writing there are no `render template:` or `render file:` calls in `app/`, so verify that is still true rather than assuming it.
- **Check Tailwind content detection.** This app has no `tailwind.config.js`; `app/assets/tailwind/application.css` is just `@import "tailwindcss"` plus the engine build, so Tailwind 4 auto-detects sources. Confirm it picks up `.html.herb` and that no class disappears from the build, because a missed glob fails silently as unstyled markup rather than an error. If it does not, add an explicit `@source` directive.
- Rails generators still emit `.html.erb`. Either accept the mix or override the generator templates.

## Is it worth it at all?

Be honest at decision time. The linter and HTML validation are already ours without either step. What `.html.herb` adds is access to Herb-only engine features, whatever those are at 1.0, and dropping the `intercept_erb` interception in favor of a real format. If the 1.0 release notes do not name a feature this app wants, the answer is "no, stay on `.html.erb`" and that is a fine outcome. Adopting a file extension is not a goal.

## Done when

Either the templates are renamed and the whole suite plus a manual pass over the register and kitchen screens is clean, or this plan is closed with a note saying 1.0 shipped nothing we needed.
