# Closed orders are terminal (no reopen)

## Decision

Once an order transitions to `closed`, it cannot be reopened. Terminal state.

## Why

- Matches status flow diagram (CLOSED has no outgoing transitions).
- Simpler state machine, no versioning on payments.
- Cleaner audit trail for cash closing (Corte de Caja) reports.
- Real-world mistakes (wrong method, extra item) are rare before cash closing; can be handled by admin adjustment or a new order.

## Alternatives considered

- **Reopen allowed before cash closing**: flexible but muddies audit, needs payment versioning.
- **Admin void + reopen with log**: viable later if real usage shows need. Would add `voided_at` or `PaymentAdjustment` model.

## Revisit when

Users report friction in real operation. Add explicit admin action (void + reopen) with logging at that point, not before.
