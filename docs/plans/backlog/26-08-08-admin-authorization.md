# Admin Authorization

## Status

Backlog. Not urgent: the app is not in production and every current user is trusted
staff. It becomes urgent the day a real store with real waiters logs in.

## The problem

`Admin::BaseController` does not authorize anything:

```ruby
class Admin::BaseController < ApplicationController
  include Pagy::Method

  before_action :require_authentication   # ApplicationController already ran this
end
```

Verified 2026-08-08: signed in as `EMP-001` (waiter role), `DELETE /admin/products/:id`
returned `302` to the admin index and set `deleted_at` on the product. Every waiter
can delete the catalog, categories, spots, and payment methods.

The existing admin controller tests sign in as `EMP-001` and assert success, so the
suite currently encodes the hole as intended behavior. Those tests must move to
`ADM-001` as part of this work, which is the main reason it is not a five-minute fix.

## The rule to settle first

`CLAUDE.md` says:

> Role = default screen, not permissions. All roles can perform all item actions.

That is right for **item actions** (kitchen and waiters both mark items ready, cancel,
deliver) and should stay. It is wrong when read as a blanket statement, which is how
`/admin` ended up open. The rule needs to become two rules:

- **Item and order actions**: any authenticated user of the store. Unchanged.
- **Administration (catalog, spots, payment methods, users)**: `admin` role only.

Write this as a decision doc in `docs/plans/decisions/` before touching code, since it
amends a rule in `CLAUDE.md`.

## Gem or homegrown?

**Recommendation: homegrown, a single `Authorization` controller concern.**

The reference codebase already does exactly this. `fizzy/app/controllers/concerns/authorization.rb`
is ~40 lines and carries the whole app:

```ruby
module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: :authenticated_account_access?
  end

  private
    def ensure_admin
      head :forbidden unless Current.user.admin?
    end
    # ...
end
```

Options considered:

| Option | Version | Fit |
|---|---|---|
| Homegrown concern | n/a | One binary distinction (admin vs not) over five controllers. A `before_action :ensure_admin` in `Admin::BaseController` is the entire feature. Matches the project's stated "no external gems for auth" stance and the Fizzy pattern. |
| `pundit` | 2.5.2 | Policy-per-resource. Real value when authorization is per-record and conditional. Here every rule is "is this user an admin", so it buys a `app/policies/` directory and a `authorize` call per action to express one boolean. |
| `action_policy` | 0.7.6 | Better than Pundit at scale (scoping, caching, explicit policy lookup). Same objection: we do not have the complexity that justifies it. |
| `cancancan` | 3.6.1 | Central `Ability` class. Worst fit: it wants to own resource loading, which fights the explicit controllers this codebase prefers. |

Revisit a gem if per-record rules appear, e.g. "a waiter may only cancel items on
orders they opened", or "store managers can edit the catalog but not users". Until
then a gem adds a dependency and a directory to express `user.admin?`.

## Plan

1. Decision doc in `docs/plans/decisions/` splitting the "role = default screen" rule
   into item actions vs administration. Update `CLAUDE.md` to match.
2. Add `app/controllers/concerns/authorization.rb` with `ensure_admin`, modeled on
   Fizzy's. `head :forbidden` for the API-ish case, redirect with a flash for HTML.
3. `before_action :ensure_admin` in `Admin::BaseController`, and drop the duplicated
   `require_authentication` while there.
4. Update the five admin controller tests to sign in as `ADM-001`.
5. Add a test per admin controller asserting a waiter gets `:forbidden`, so the hole
   cannot reopen silently.
6. Hide the "Administración" sidebar entry for non-admins (`app/views/layouts/application.html.erb`).
   Cosmetic, but a link that always 403s is worse than no link.

## Related

- `docs/plans/done/26-08-08-session-lifecycle-holes.md` landed first and put the
  store/active-user scoping inline in `ApplicationController#set_current_user`. Fizzy
  keeps that check and `ensure_admin` in one `Authorization` concern, so step 2 should
  move the existing scoping into the new concern rather than leaving it split.
