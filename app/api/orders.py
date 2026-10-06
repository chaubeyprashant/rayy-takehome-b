from fastapi import APIRouter, HTTPException

from app.models import Order
from pydantic import BaseModel

from app.services import discounts as discounts_service
from app.services import orders as orders_service

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("", response_model=list[Order])
async def list_orders(limit: int = 50) -> list[Order]:
    return await orders_service.list_orders(limit)


@router.get("/{order_id}", response_model=Order)
async def get_order(order_id: str) -> Order:
    try:
        return await orders_service.get_order(order_id)
    except orders_service.OrderNotFound:
        raise HTTPException(status_code=404, detail="order not found")


class ApplyDiscountRequest(BaseModel):
    code: str


@router.post("/{order_id}/apply-discount", response_model=Order)
async def apply_discount(order_id: str, body: ApplyDiscountRequest) -> Order:
    try:
        return await discounts_service.apply_discount(order_id, body.code)
    except discounts_service.OrderNotFound:
        raise HTTPException(status_code=404, detail="order not found")
    except discounts_service.UnknownCode:
        raise HTTPException(status_code=404, detail="unknown discount code")
    except discounts_service.ExpiredCode:
        raise HTTPException(status_code=422, detail="discount code expired")
    except discounts_service.OrderNotDiscountable:
        raise HTTPException(status_code=409, detail="order is not open for discounts")
    except discounts_service.DiscountAlreadyApplied:
        raise HTTPException(status_code=409, detail="order already has a discount")
