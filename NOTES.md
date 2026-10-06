# NOTES

## Client
Flutter (`client/flutter/`). `flutter test`: 8 passing.

## Decisions
- **Rounding:** percentage discount is computed in integer maths and rounded half-up to a whole paisa, then capped by `cap_paise` and by the subtotal. Partner share is rounded half-up; RAYY gets the remainder, so the two always sum exactly to the discount.
- **Second code:** rejected with 409; the first discount stays. Enforced by an atomic conditional update (`status=pending AND discount=null`), so two concurrent requests give exactly one 200 and one 409 (tested).
- Other statuses: unknown code 404, expired 422, non-pending order 409.
- **Webhook:** HMAC-SHA256 checked over the raw body (constant-time) before parsing; bad signature 401. Idempotent on `payment_id` (duplicate delivery returns 200 `duplicate`). The pending->paid update is one atomic write that also requires `amount_paise == total_paise`, so concurrent duplicates cannot double-apply. Amount mismatch or a second different payment on a paid order returns 409 and is logged for a human, never silently accepted. Unknown order 404; non-`payment.succeeded` events are ignored with 200.
- No transactions are used; each operation is a single-document atomic update, so `make test` on the in-memory Mongo is sufficient.

## Settlement (partner splits change monthly)
- Each order stores a **snapshot** in `order.discount`: `code`, `percent_off_bps`, `cap_paise`, `amount_paise`, `partner_share_bps`, `rayy_share_bps`, `partner_amount_paise`, `rayy_amount_paise`, `applied_at`. The split is copied at apply time, so a changed ratio never rewrites history.
- Paid orders also store `paid_at` and `payment`.
- The settlement query reads only the orders: `status = "paid"`, `paid_at` in the month, grouped by `partner_id`, summing `discount.partner_amount_paise`. It never reads current code config.
- Cash amounts are stored (not recomputed from bps), so rounding stays identical to what was shown to the customer.
- Month boundary choice (`paid_at`, in IST) is an assumption to confirm with finance.

## AI tool: what it got wrong
- My first draft of the discount path did read-then-write (check no discount, then update), which lets two simultaneous codes both succeed (the `apply_4` fixture). I moved the guard into a conditional atomic update and added a concurrency test. Similarly the webhook initially marked paid without checking the charged amount against the discounted total.

## Not yet trusted in production
- Codes load from a JSON file with expiry relative to process start (seed behaviour), so "expired" is not stable across restarts.
- Idempotency relies on the order document; no separate payments collection or unique index on `payment_id` (a payment id reused across orders is not detected).
- Concurrency tests run on mongomock, which is not truly concurrent; needs a run against a real replica set.
- A 409 on amount mismatch makes the gateway retry; there is no alerting/refund flow.
- Webhook has no timestamp/replay window. Client has no real API wiring or localisation; `formatPaise` rejects negatives only.

## Time
About 1h15 in total with AI assistance: ~15 min reading the starter and deciding semantics, ~30 min backend and tests, ~20 min Flutter, ~10 min notes. Not done: real-Mongo run, settlement endpoint (only described).
