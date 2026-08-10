# Session Lifecycle Follow-ups

## Status

Backlog, filed 2026-08-10 out of the review of `26-08-08-session-lifecycle-holes.md`.
Two holes that live next to the ones that plan closed, both left open because they are
product decisions rather than bugs.

## 1. A deactivated store keeps serving its sessions

`ApplicationController#set_current_store` resolves the tenant by subdomain only:

```ruby
Current.store = Store.find_by!(subdomain: request.subdomain)
```

`stores.active` (boolean, `default: true, null: false`, indexed) is never read. Verified
2026-08-10 on the branch: `store.update_column(:active, false)` then `POST /login` still
returns `302` with the session set, and every later request works.

Fizzy's equivalent checks `Current.account.active? && Current.user&.active?`.

Open questions before writing code:

- What does an inactive store mean? Suspended for non-payment, closed for the season,
  or soft-deleted-in-all-but-name?
- What does a request to one render? A `404` like an unknown subdomain hides the tenant
  but also locks the owner out of reactivating from the app.
- Does the admin area stay reachable so someone can flip it back?

Answer those first, then `set_current_store` gets the filter and an integration test.

## 2. A soft-deleted user's employee number stays burned

`Account#employee_number_unique_in_store` joins `users` with no `deleted_at` filter:

```ruby
existing = Account.joins(:user)
                  .where(users: { store_id: user.store_id })
                  .where(employee_number: employee_number)
                  .where.not(id: id)
```

Now that a soft-deleted user cannot log in, their `EMP-001` is still reserved forever, so
re-hiring or re-creating that employee fails validation with `:taken`.

Both readings are defensible: keeping the number reserved preserves the audit trail of
who `EMP-001` was on old orders; freeing it matches how a small cafe actually reuses
numbers. Decide, then either filter the validation by `deleted_at: nil` or leave it and
give the admin UI a clearer error than "ya está en uso".

## Related

- `docs/plans/done/26-08-08-session-lifecycle-holes.md`
- `docs/plans/backlog/26-08-08-admin-authorization.md`
