"""Apply a partner discount code to an order."""

from datetime import datetime, timezone

from app.models import Order
from app.repositories import discount_codes
from app.repositories import orders as orders_repo
from app.services import pricing
from app.services.orders import OrderNotFound, get_order


class UnknownCode(Exception):
    pass


class ExpiredCode(Exception):
    pass


class OrderNotDiscountable(Exception):
    """Order is not pending (e.g. already paid)."""


class DiscountAlreadyApplied(Exception):
    pass


async def apply_discount(order_id: str, code_str: str) -> Order:
    order = await get_order(order_id)  # raises OrderNotFound
    code = discount_codes.get_by_code(code_str.strip())
    if code is None:
        raise UnknownCode(code_str)
    now = datetime.now(timezone.utc)
    if code.expires_at <= now:
        raise ExpiredCode(code.code)
    if order.status != "pending":
        raise OrderNotDiscountable(order_id)
    if order.discount is not None:
        raise DiscountAlreadyApplied(order_id)

    breakdown = pricing.compute_discount(order.subtotal_paise, code)
    snapshot = {
        "code": code.code,
        "percent_off_bps": code.percent_off_bps,
        "cap_paise": code.cap_paise,
        "amount_paise": breakdown.amount_paise,
        "partner_share_bps": code.partner_share_bps,
        "rayy_share_bps": code.rayy_share_bps,
        "partner_amount_paise": breakdown.partner_amount_paise,
        "rayy_amount_paise": breakdown.rayy_amount_paise,
        "applied_at": now,
    }
    new_total = order.subtotal_paise - breakdown.amount_paise
    # The conditional update is the real guard: concurrent requests can pass the
    # checks above, but only one wins the write.
    if not await orders_repo.apply_discount(order_id, snapshot, new_total):
        fresh = await get_order(order_id)
        if fresh.discount is not None:
            raise DiscountAlreadyApplied(order_id)
        raise OrderNotDiscountable(order_id)
    return await get_order(order_id)


__all__ = [
    "apply_discount",
    "UnknownCode",
    "ExpiredCode",
    "OrderNotDiscountable",
    "DiscountAlreadyApplied",
    "OrderNotFound",
]
