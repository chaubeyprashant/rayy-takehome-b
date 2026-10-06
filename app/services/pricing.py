"""Pure money maths for discounts. Integer paise and basis points only."""

from dataclasses import dataclass

from app.models import DiscountCode

BPS = 10000


@dataclass(frozen=True)
class DiscountBreakdown:
    amount_paise: int
    partner_amount_paise: int
    rayy_amount_paise: int


def _round_half_up_div(numerator: int, denominator: int) -> int:
    return (numerator * 2 + denominator) // (denominator * 2)


def compute_discount(subtotal_paise: int, code: DiscountCode) -> DiscountBreakdown:
    """Percentage of the subtotal, rounded half-up to a whole paisa, then capped
    (and never above the subtotal). The partner share is rounded half-up and RAYY
    gets the remainder, so the two always add up to the discount exactly."""
    raw = _round_half_up_div(subtotal_paise * code.percent_off_bps, BPS)
    amount = min(raw, code.cap_paise, subtotal_paise)
    partner = _round_half_up_div(amount * code.partner_share_bps, BPS)
    return DiscountBreakdown(amount, partner, amount - partner)
