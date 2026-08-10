# Session Lifecycle Holes

## Status

Done 2026-08-08, extended 2026-08-10 after review. Five holes closed in
`ApplicationController#set_current_user` and `SessionsController#create`, covered by
`test/integration/session_lifecycle_test.rb`. Confirmed every test is real by mutation:
each fix, reverted on its own, fails the test that guards it.

## The problems

### 1. A soft-deleted user can still log in

`SessionsController#create`:

```ruby
account = Account.joins(:user)
                 .where(users: { store_id: Current.store.id })
                 .find_by(employee_number: params[:employee_number])
```

No `deleted_at IS NULL` filter. Verified 2026-08-08: `user.soft_delete!` then
`POST /login` with their credentials returned `302` to root with `session[:user_id]`
set to the deleted user's id.

### 2. An existing session survives deletion

`ApplicationController#set_current_user`:

```ruby
Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
```

No active scope, so a user soft-deleted mid-shift keeps working until they log out.

### 3. The session is not scoped to the store

Same line: the lookup is global. Login scopes by store, but nothing re-checks it on
subsequent requests. Not exploitable today, because Rails session cookies are host-only
and `cafe.localhost` cookies are never sent to `pizza.localhost`. It becomes a live
cross-tenant hole the moment anyone sets `domain: :all` on the session cookie, which is
the conventional thing to do in a subdomain app. Fix it now while it is one line.

### 4. The `active` column was never read

Found in review 2026-08-10. `users.active` (boolean, `default: true, null: false`) is a
separate thing from `deleted_at`, and `SoftDeletable`'s `scope :active` only means
`deleted_at: nil`. So `Current.store.users.active` *read* as "honors the active flag"
while checking nothing of the kind. Verified: `user.update_column(:active, false)` then
`POST /login` returned `302` with the session set, and the mid-session check passed them
through too. Both lookups now spell out `where(active: true, deleted_at: nil)` instead of
using the misleading scope name.

### 5. Login did not rotate the session id

Also found in review. `session[:user_id] = account.user_id` reused whatever session id
the request arrived with. That is session fixation, and it matters under exactly the
`domain: :all` cookie this plan already reasons about: a sibling subdomain can plant a
session cookie and then own the session the victim logs in to. `reset_session` before the
assignment, one line.

## The fix

One scope change in each place, plus clearing a session that no longer resolves so a
stale cookie does not re-check the database on every request forever.

```ruby
def set_current_user
  return unless session[:user_id]

  Current.user = Current.store.users.where(active: true, deleted_at: nil).find_by(id: session[:user_id])
  session.delete(:user_id) unless Current.user
end
```

and at login, scope the account lookup to active users of the store.

`Current.store` is already set by an earlier `before_action`, so the ordering works.

Deliberately **not** doing here:
- No `Authorization` concern yet, that is `docs/plans/backlog/26-08-08-admin-authorization.md`.
- No login rate limiting, that is its own change.

## Steps

- [x] Scope the login account lookup to `active` users of the current store.
- [x] Scope `set_current_user` to `Current.store.users.active`, and clear a session that
      no longer resolves.
- [x] Integration test: a soft-deleted user cannot log in.
- [x] Integration test: an in-flight session dies when the user is soft-deleted.
- [x] Integration test: a session cannot carry across stores. Reworked 2026-08-10: the
      first version was vacuous, because the cookie jar honors cookie domains and never
      sent the `cafe-delicias` cookie to `mi-cafe`, so the request was unauthenticated no
      matter what `set_current_user` did. It now replays the raw `Set-Cookie` pair against
      the other host, and fails if the store scope is removed.
- [x] Scope both lookups to `active: true` as well as `deleted_at: nil`, and cover a
      deactivated user at login and mid-session.
- [x] `reset_session` at login, with a test that the session id changes.
- [x] Full suite + herb lint + rubocop green.

## Result

- Measured 2026-08-10 with the review additions in: 207 unit/integration tests green
  (8 of them in this file), rubocop clean, system tests green in CI.
- The admin authorization hole is untouched and still open, by design. See
  `docs/plans/backlog/26-08-08-admin-authorization.md`.

## Notes

- `Store#users` exists (`has_many :users`), so the scoped lookup needs no new code. The
  `active` scope from `SoftDeletable` is deliberately *not* used here: it only means
  `deleted_at: nil`, and the auth lookups need the `active` column too.
- Two sibling holes came out of the review and stayed out of this change, because both
  are product decisions: a deactivated *store* still serves its sessions, and a
  soft-deleted user's employee number stays reserved forever. Filed as
  `docs/plans/backlog/26-08-10-session-lifecycle-follow-ups.md`.
- Fizzy solves the same problem in `app/controllers/concerns/authorization.rb` with
  `ensure_can_access_account`, checking `Current.account.active? && Current.user&.active?`.
  We are inlining it in `ApplicationController` for now; when the admin authorization
  work lands, both belong in one `Authorization` concern.
