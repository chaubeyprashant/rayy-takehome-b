# NOTES

## Client
- Flutter (`client/flutter/`).
- `formatPaise` + `OrderSummary` per starter contract; demo shell in `lib/main.dart` for device runs.
- `flutter test`: all passing.

## Decisions
- **Rounding:** percentage discount in integer maths, half-up to a whole paisa, then capped by `cap_paise` and subtotal. Partner share half-up; RAYY gets the remainder so shares always sum to the discount.
- **Second code:** 409; first discount kept. Enforced with atomic update (`status=pending` and no discount yet) so concurrent applies yield one 200 and one 409 (tested).
- Other apply errors: unknown code 404, expired 422, non-pending order 409.
- **Webhook:** HMAC-SHA256 over raw body (constant-time) before parse; bad signature 401. Idempotent on `payment_id` (duplicate → 200 `duplicate`). Pending→paid is one atomic write that also requires `amount_paise == total_paise`. Amount mismatch or a second different payment on a paid order → 409 (logged), never silently accepted. Unknown order 404; non-`payment.succeeded` → 200 ignore.
- No multi-document transactions; single-document atomic updates only → `make test` / mongomock is enough.

## Settlement (partner splits can change next month)
- Snapshot on apply in `order.discount`: `code`, `percent_off_bps`, `cap_paise`, `amount_paise`, `partner_share_bps`, `rayy_share_bps`, `partner_amount_paise`, `rayy_amount_paise`, `applied_at`.
- Paid orders also store `paid_at` and `payment`.
- Settlement query: `status = "paid"`, `paid_at` in the month, group by `partner_id`, sum `discount.partner_amount_paise`. Never re-read live code config.
- Store cash amounts (not only bps) so rounding matches what the customer saw.
- Month boundary: `paid_at` in IST — confirm with finance.

## AI tool: what it got wrong
- First discount draft was read-then-write; concurrent codes could both win (`apply_4`). I required a conditional atomic update and a concurrency test.
- First webhook draft marked paid without matching charged amount to discounted `total_paise`; fixed the same way.

## Not yet trusted in production
- Code expiry is relative to process start (seed JSON), so “expired” is not stable across restarts.
- Idempotency lives on the order doc; no payments collection / unique index on `payment_id`.
- Concurrency tests use mongomock, not a real replica set.
- Amount-mismatch 409 can cause gateway retries; no alert/refund path yet.
- No webhook timestamp / replay window.
- Client is a local demo (no live API / localisation); `formatPaise` rejects negatives only.

## Time
- ~1h30 with AI assist: ~15m read + decisions, ~30m backend/tests, ~25m Flutter (incl. UI polish), ~10m NOTES/prompts, ~10m push/device run.
- Left undone on purpose: real-Mongo CI run, settlement HTTP endpoint (design only in NOTES).

## Prompts
- Readable history: `prompts/conversation.md`
- Raw session exports: `prompts/raw/`
