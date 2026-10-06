"""Handle payment-gateway webhooks (at-least-once delivery, signed bodies)."""

import hashlib
import hmac
import json
import logging
from datetime import datetime, timezone

from app.config import settings
from app.repositories import orders as orders_repo
from app.services.orders import OrderNotFound, get_order

log = logging.getLogger(__name__)


class InvalidSignature(Exception):
    pass


class InvalidPayload(Exception):
    pass


class PaymentConflict(Exception):
    """Webhook is valid but cannot be applied; needs human attention."""


def verify_signature(raw_body: bytes, signature: str | None) -> None:
    if not signature:
        raise InvalidSignature("missing signature")
    expected = hmac.new(settings.gateway_webhook_secret.encode(), raw_body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature.strip()):
        raise InvalidSignature("bad signature")


def parse_event(raw_body: bytes) -> dict:
    try:
        data = json.loads(raw_body)
    except ValueError as exc:
        raise InvalidPayload("not json") from exc
    if not isinstance(data, dict):
        raise InvalidPayload("not an object")
    amount = data.get("amount_paise")
    if (
        not isinstance(data.get("event"), str)
        or not isinstance(data.get("payment_id"), str)
        or not data["payment_id"]
        or not isinstance(data.get("order_id"), str)
        or not isinstance(amount, int)
        or isinstance(amount, bool)
        or amount < 0
    ):
        raise InvalidPayload("missing or malformed fields")
    return data


async def handle_payment_webhook(raw_body: bytes, signature: str | None) -> str:
    """Returns 'paid', 'duplicate' or 'ignored'. Raises on anything unacceptable."""
    verify_signature(raw_body, signature)
    event = parse_event(raw_body)
    if event["event"] != "payment.succeeded":
        return "ignored"

    order_id, payment_id, amount = event["order_id"], event["payment_id"], event["amount_paise"]
    order = await get_order(order_id)  # raises OrderNotFound

    if order.status == "paid":
        return _already_paid(order, payment_id, amount)

    payment = {
        "payment_id": payment_id,
        "amount_paise": amount,
        "received_at": datetime.now(timezone.utc),
    }
    # Atomic: only transitions pending -> paid if amount equals the current total.
    if await orders_repo.mark_paid(order_id, amount, payment, payment["received_at"]):
        return "paid"

    fresh = await get_order(order_id)
    if fresh.status == "paid":  # concurrent delivery of the same event won
        return _already_paid(fresh, payment_id, amount)
    log.error("payment amount mismatch order=%s payment=%s charged=%s total=%s",
              order_id, payment_id, amount, fresh.total_paise)
    raise PaymentConflict("amount does not match order total")


def _already_paid(order, payment_id: str, amount: int) -> str:
    if order.payment and order.payment.payment_id == payment_id:
        return "duplicate"
    log.error("second payment for paid order=%s payment=%s", order.order_id, payment_id)
    raise PaymentConflict("order already paid by a different payment")


__all__ = ["handle_payment_webhook", "InvalidSignature", "InvalidPayload", "PaymentConflict", "OrderNotFound"]
