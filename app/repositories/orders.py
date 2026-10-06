"""All database access for the ``orders`` collection."""

from app.db import ORDERS, get_db


def _to_order_dict(doc: dict) -> dict:
    doc = dict(doc)
    doc["order_id"] = doc.pop("_id")
    return doc


async def get(order_id: str) -> dict | None:
    doc = await get_db()[ORDERS].find_one({"_id": order_id})
    return _to_order_dict(doc) if doc else None


async def list_recent(limit: int = 50) -> list[dict]:
    cursor = get_db()[ORDERS].find({}).sort("created_at", -1).limit(limit)
    return [_to_order_dict(doc) async for doc in cursor]


async def apply_discount(order_id: str, discount: dict, new_total_paise: int) -> bool:
    """Atomically attach a discount to a pending order that has none yet.
    Returns False if the order is no longer eligible (lost a race / not pending)."""
    result = await get_db()[ORDERS].update_one(
        {"_id": order_id, "status": "pending", "discount": None},
        {"$set": {"discount": discount, "total_paise": new_total_paise}},
    )
    return result.modified_count == 1


async def mark_paid(order_id: str, amount_paise: int, payment: dict, paid_at) -> bool:
    """Atomically move a pending order to paid, only if the charged amount equals
    the order's current total. Returns False if nothing matched."""
    result = await get_db()[ORDERS].update_one(
        {"_id": order_id, "status": "pending", "total_paise": amount_paise},
        {"$set": {"status": "paid", "paid_at": paid_at, "payment": payment}},
    )
    return result.modified_count == 1
