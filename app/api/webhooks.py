from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse

from app.gateway import SIGNATURE_HEADER
from app.services import payments

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/payment")
async def payment_webhook(request: Request):
    raw = await request.body()  # signature is over the raw bytes
    try:
        result = await payments.handle_payment_webhook(raw, request.headers.get(SIGNATURE_HEADER))
    except payments.InvalidSignature:
        raise HTTPException(status_code=401, detail="invalid signature")
    except payments.InvalidPayload as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except payments.OrderNotFound:
        raise HTTPException(status_code=404, detail="order not found")
    except payments.PaymentConflict as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return JSONResponse({"status": result})
