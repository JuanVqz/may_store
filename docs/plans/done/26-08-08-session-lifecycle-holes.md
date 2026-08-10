# Session Lifecycle Holes

## Status

Done 2026-08-08. All three holes closed in `ApplicationController#set_current_user` and
`SessionsController#create`, covered by `test/integration/session_lifecycle_test.rb`.
Confirmed the tests are real: reverting the two controller changes fails 3 of the 5.

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

## The fix

One scope change in each place, plus clearing a session that no longer resolves so a
stale cookie does not re-check the database on every request forever.

```ruby
def set_current_user
  return unless session[:user_id]

  Current.user = Current.store.users.active.find_by(id: session[:user_id])
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
- [x] Integration test: a session cannot carry across stores.
- [x] Full suite + herb lint + rubocop green.

## Result

- 207 unit/integration + 95 system tests green, rubocop and herb lint clean.
- The admin authorization hole is untouched and still open, by design. See
  `docs/plans/backlog/26-08-08-admin-authorization.md`.

## Notes

- `Store#users` exists (`has_many :users`), and `User` includes `SoftDeletable`, so
  `Current.store.users.active` needs no new code.
- Fizzy solves the same problem in `app/controllers/concerns/authorization.rb` with
  `ensure_can_access_account`, checking `Current.account.active? && Current.user&.active?`.
  We are inlining it in `ApplicationController` for now; when the admin authorization
  work lands, both belong in one `Authorization` concern.
