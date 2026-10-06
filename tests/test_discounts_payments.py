import asyncio
import json

import pytest

from app.gateway import SIGNATURE_HEADER, StubGateway
from app.models import DiscountCode
from app.services.pricing import compute_discount
from datetime import datetime, timezone


def _code(pct, cap, partner=7000):
    return DiscountCode(
        code="X", percent_off_bps=pct, cap_paise=cap,
        expires_at=datetime.now(timezone.utc),
        partner_share_bps=partner, rayy_share_bps=10000 - partner,
    )


def test_pricing_rounds_half_up_and_split_sums():
    # 12% of 29999 = 3599.88 -> 3600
    d = compute_discount(29999, _code(1200, 100000, 6500))
    assert d.amount_paise == 3600
    assert d.partner_amount_paise + d.rayy_amount_paise == 3600
    # exact half: 5% of 10 paise = 0.5 -> 1
    assert compute_discount(10, _code(500, 100000)).amount_paise == 1


def test_pricing_cap_and_never_above_subtotal():
    assert compute_discount(29999, _code(4000, 7500, 7500)).amount_paise == 7500
    assert compute_discount(50, _code(10000, 100000)).amount_paise == 50


async def test_apply_discount_records_snapshot(client):
    r = await client.post("/orders/ord_b_2002/apply-discount", json={"code": "BIG40"})
    assert r.status_code == 200
    body = r.json()
    assert body["total_paise"] == 29999 - 7500
    d = body["discount"]
    assert d["amount_paise"] == 7500
    assert d["partner_amount_paise"] == 5625 and d["rayy_amount_paise"] == 1875
    assert d["partner_share_bps"] == 7500
    assert (await client.get("/orders/ord_b_2002")).json()["total_paise"] == 22499


async def test_apply_discount_percentage(client):
    r = await client.post("/orders/ord_b_2001/apply-discount", json={"code": "FIT12"})
    assert r.json()["discount"]["amount_paise"] == 3600
    assert r.json()["total_paise"] == 26399


async def test_expired_unknown_and_missing_order(client):
    assert (await client.post("/orders/ord_b_2002/apply-discount", json={"code": "OLDFIT25"})).status_code == 422
    assert (await client.post("/orders/ord_b_2002/apply-discount", json={"code": "NOPE"})).status_code == 404
    assert (await client.post("/orders/ord_nope/apply-discount", json={"code": "FIT12"})).status_code == 404
    assert (await client.get("/orders/ord_b_2002")).json()["discount"] is None


async def test_second_code_rejected_sequential(client):
    assert (await client.post("/orders/ord_b_2004/apply-discount", json={"code": "FIT12"})).status_code == 200
    r = await client.post("/orders/ord_b_2004/apply-discount", json={"code": "HELLO8"})
    assert r.status_code == 409
    order = (await client.get("/orders/ord_b_2004")).json()
    assert order["discount"]["code"] == "FIT12" and order["total_paise"] == 29999 - 3600


async def test_second_code_rejected_concurrent(client):
    rs = await asyncio.gather(
        client.post("/orders/ord_b_2005/apply-discount", json={"code": "FIT12"}),
        client.post("/orders/ord_b_2005/apply-discount", json={"code": "HELLO8"}),
    )
    assert sorted(r.status_code for r in rs) == [200, 409]
    order = (await client.get("/orders/ord_b_2005")).json()
    assert order["total_paise"] == order["subtotal_paise"] - order["discount"]["amount_paise"]


async def test_cannot_discount_paid_order(client):
    await _deliver(client, "ord_b_2003", "pay_1", 64950)
    r = await client.post("/orders/ord_b_2003/apply-discount", json={"code": "FIT12"})
    assert r.status_code == 409


# ---- webhooks ----

async def _deliver(client, order_id, payment_id, amount, secret="whsec_test", sig=None):
    gw = StubGateway(webhook_secret=secret)
    headers, body = gw.deliveries({"payment_id": payment_id, "order_id": order_id, "amount_paise": amount})[0]
    if sig is not None:
        headers[SIGNATURE_HEADER] = sig
    return await client.post("/webhooks/payment", content=body, headers=headers)


async def test_webhook_marks_paid_and_is_idempotent(client):
    r1 = await _deliver(client, "ord_b_2003", "pay_b_8001", 64950)
    r2 = await _deliver(client, "ord_b_2003", "pay_b_8001", 64950)
    assert (r1.status_code, r1.json()["status"]) == (200, "paid")
    assert (r2.status_code, r2.json()["status"]) == (200, "duplicate")
    order = (await client.get("/orders/ord_b_2003")).json()
    assert order["status"] == "paid"
    assert order["payment"]["payment_id"] == "pay_b_8001" and order["paid_at"]


async def test_concurrent_duplicate_deliveries(client):
    rs = await asyncio.gather(*[_deliver(client, "ord_b_2004", "pay_c", 29999) for _ in range(5)])
    assert all(r.status_code == 200 for r in rs)
    assert sorted(r.json()["status"] for r in rs).count("paid") == 1


async def test_webhook_rejects_bad_signature(client):
    r = await _deliver(client, "ord_b_2003", "pay_x", 64950, secret="wrong")
    assert r.status_code == 401
    r = await _deliver(client, "ord_b_2003", "pay_x", 64950, sig="")
    assert r.status_code == 401
    assert (await client.get("/orders/ord_b_2003")).json()["status"] == "pending"


async def test_webhook_amount_must_match_discounted_total(client):
    await client.post("/orders/ord_b_2001/apply-discount", json={"code": "FIT12"})
    r = await _deliver(client, "ord_b_2001", "pay_full", 29999)  # charged undiscounted price
    assert r.status_code == 409
    assert (await client.get("/orders/ord_b_2001")).json()["status"] == "pending"
    r = await _deliver(client, "ord_b_2001", "pay_ok", 26399)
    assert r.status_code == 200
    assert (await client.get("/orders/ord_b_2001")).json()["status"] == "paid"


async def test_second_distinct_payment_conflicts(client):
    await _deliver(client, "ord_b_2003", "pay_a", 64950)
    r = await _deliver(client, "ord_b_2003", "pay_b", 64950)
    assert r.status_code == 409
    assert (await client.get("/orders/ord_b_2003")).json()["payment"]["payment_id"] == "pay_a"


async def test_webhook_unknown_order_and_malformed(client):
    assert (await _deliver(client, "ord_nope", "pay_z", 100)).status_code == 404
    body = b"not json"
    gw = StubGateway(webhook_secret="whsec_test")
    r = await client.post("/webhooks/payment", content=body, headers={SIGNATURE_HEADER: gw.sign(body)})
    assert r.status_code == 400
    body = json.dumps({"event": "payment.succeeded", "payment_id": "p", "order_id": "ord_b_2003", "amount_paise": 1.5}).encode()
    r = await client.post("/webhooks/payment", content=body, headers={SIGNATURE_HEADER: gw.sign(body)})
    assert r.status_code == 400
