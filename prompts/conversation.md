# Prompt transcript — RAYY take-home B

Date: 2026-10-05 → 2026-10-06  
Client choice: Flutter  
Raw exports: `prompts/raw/`

Below is the conversation I actually had with the AI assistant, edited only for
readability (removed tool noise / compaction markers). Decisions and corrections
are mine; the model drafted code that I reviewed, tested, and adjusted.

---

## 1. Kickoff — scope the exercise

**Me:**  
Here is the hiring email and template link for the RAYY take-home
(`rayy-hiring/rayy-takehome-b`). Read the README, clone the template into my
GitHub account workflow, and summarise what we must ship: backend discount +
payment webhook, tests, Flutter or React client, `NOTES.md`, and `prompts/`.

**Assistant:**  
Outlined README requirements, noted integer-paise money, money logic out of
route handlers, and the two unspecified decisions (rounding; second discount
code). Confirmed Flutter is fine for the client task.

---

## 2. Architecture before coding

**Me:**  
Before writing endpoints, propose a structure that keeps pricing/discount/payment
logic in services (not in FastAPI routes). Call out how you would handle:

1. percentage discount that yields a fractional paisa  
2. a second discount code on an order that already has one  
3. webhook HMAC verification, at-least-once delivery, and amount mismatch  
4. what to snapshot on the order for monthly partner settlement when the split
   ratio can change next month  

I will decide; do not invent a settlement HTTP API unless needed.

**Assistant:**  
Suggested half-up integer rounding, reject second code with 409 via conditional
update, verify HMAC on raw body, idempotent webhook on `payment_id`, store
partner/RAYY cash splits on the order at apply time. I accepted that plan and
asked it to implement.

---

## 3. Implement backend

**Me:**  
Implement:

- `POST /orders/{order_id}/apply-discount` with body `{ "code": "..." }`  
- `POST /webhooks/payment` per `app/gateway.py`  
- models / repository helpers as needed  
- tests in the existing suite, including the seed fixtures in
  `seed/fixtures.json` (especially concurrent apply and duplicate webhook)

Keep routes thin. Prefer single-document atomic updates over multi-doc
transactions so `make test` (mongomock) still works. Say so in NOTES if we
avoid transactions.

**Assistant:**  
Added `app/services/pricing.py`, `discounts.py`, `payments.py`, webhook route,
repository conditional updates, and `tests/test_discounts_payments.py`.

**Me (review):**  
Run the full pytest suite and fix anything that fails. Also check the
`apply_4` concurrent-codes fixture — a read-then-write path is not good enough.

**Assistant (first attempt):**  
Used check-then-update for “no discount yet”.

**Me:**  
That races. Put the guard in the Mongo filter
(`status=pending` and `discount` absent) so only one apply wins. Add an
explicit concurrency test. Same idea for webhook: pending→paid must require
`amount_paise == total_paise` in the same update.

**Assistant:**  
Reworked to atomic conditional updates; concurrency + amount-mismatch tests
added. Suite green (22 tests).

---

## 4. Flutter client

**Me:**  
Do the client in Flutter (`client/flutter/`). Implement `formatPaise` with
Indian grouping and integer maths only, and `OrderSummary` per the starter
doc comments (`ElevatedButton`, Pay / Paid, “Payment failed” on error). Extend
the existing tests; keep file names and exports.

**Assistant:**  
Implemented `format_paise.dart` and `order_summary.dart` with widget tests.

**Me:**  
`flutter test` — all must pass. Then we can polish UI separately; contract text
strings must stay exact so tests keep working.

---

## 5. NOTES.md

**Me:**  
Write `NOTES.md` with short bullets covering: Flutter choice, rounding and
second-code decisions, settlement snapshot + query, the AI mistake I caught
(race on apply / missing amount check), production distrust list, and time
spent.

**Assistant:**  
Drafted NOTES; I tightened wording and kept settlement as query design only
(no new endpoint).

---

## 6. Submit to my GitHub

**Me:**  
Commit the take-home (including `NOTES.md` and `prompts/`) and push to my own
repo under `chaubeyprashant`, not the hiring template remote. Public is fine.

**Assistant:**  
Created `https://github.com/chaubeyprashant/rayy-takehome-b` and pushed.

---

## 7. Run on device + UI polish

**Me:**  
Run the Flutter app on the connected Android device.

**Assistant:**  
Starter had no `main.dart` / Android folder; generated a demo shell and
`flutter run` on SM A336E.

**Me:**  
UI is too plain. Make the checkout screen look more premium without breaking
the OrderSummary contract or tests (exact Subtotal/Discount/Total/Pay strings
and `ElevatedButton`).

**Assistant:**  
Redesigned with Fraunces/Manrope, mist gradient backdrop, status chip, large
amount-due, discount highlight, full-width Pay with loading state. Tests still
pass.

---

## 8. Prompt history for submission

**Me:**  
Organise `prompts/` so it looks professional for review: readable transcript
plus raw exports. Keep `NOTES.md` accurate.

**Assistant:**  
This file, plus `prompts/README.md` and untouched JSONL under `prompts/raw/`.

---

## What I personally verified

- `python -m pytest` — 22 passed (mongomock)  
- `flutter test` — all passing after UI changes  
- App launched on physical device (SM A336E)  
- Concurrent discount apply and webhook idempotency covered by tests  

I did not blindly accept the first discount/webhook draft; the race and amount
checks were my catch (also noted in `NOTES.md`).
