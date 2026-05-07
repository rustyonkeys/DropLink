from __future__ import annotations

import secrets
import time
from typing import Callable, Dict, Optional, Union

from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .config import CHUNK_SIZE, TOKEN_TTL_SECONDS, AppConfig
from .models import PendingToken, TransferOffer
from .storage import StorageManager

OfferCallback = Callable[[TransferOffer], bool]
ProgressCallback = Callable[[str, int, int], None]


class OfferRequest(BaseModel):
    transfer_id: str
    sender_id: str
    sender_name: str
    filename: str
    size: int
    mime_type: str = "application/octet-stream"


class OfferResponse(BaseModel):
    accepted: bool
    token: Optional[str] = None
    message: str = ""


class TransferServer:
    def __init__(
        self,
        config: AppConfig,
        storage: StorageManager,
        on_offer: Optional[OfferCallback] = None,
        on_progress: Optional[ProgressCallback] = None,
    ) -> None:
        self.config = config
        self.storage = storage
        self.on_offer = on_offer
        self.on_progress = on_progress
        self.tokens: Dict[str, PendingToken] = {}
        self.app = FastAPI(title="DropLink Windows")
        self._configure_routes()

    def _configure_routes(self) -> None:
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_methods=["*"],
            allow_headers=["*"],
        )

        @self.app.get("/api/health")
        def health() -> Dict[str, Union[str, int]]:
            return {
                "status": "ok",
                "device_id": self.config.device_id,
                "device_name": self.config.device_name,
                "port": self.config.http_port,
            }

        @self.app.post("/api/offers", response_model=OfferResponse)
        def create_offer(request: OfferRequest) -> OfferResponse:
            offer = TransferOffer(**request.dict())
            accepted = self.on_offer(offer) if self.on_offer else True
            if not accepted:
                return OfferResponse(accepted=False, message="Transfer declined")

            token = secrets.token_urlsafe(32)
            self.tokens[offer.transfer_id] = PendingToken(
                token=token,
                transfer_id=offer.transfer_id,
                expires_at=time.time() + TOKEN_TTL_SECONDS,
            )
            return OfferResponse(accepted=True, token=token)

        @self.app.post("/api/transfers/{transfer_id}/upload")
        async def upload_file(
            transfer_id: str,
            file: UploadFile = File(...),
            authorization: Optional[str] = Header(default=None),
        ) -> Dict[str, Union[str, int]]:
            self._authorize(transfer_id, authorization)
            destination = self.storage.safe_destination(file.filename or transfer_id)
            received = 0

            with destination.open("wb") as output:
                while True:
                    chunk = await file.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    output.write(chunk)
                    received += len(chunk)
                    if self.on_progress:
                        self.on_progress(transfer_id, received, 0)

            self.tokens.pop(transfer_id, None)
            return {"status": "saved", "path": str(destination), "bytes": received}

    def _authorize(self, transfer_id: str, authorization: Optional[str]) -> None:
        pending = self.tokens.get(transfer_id)
        if not pending or pending.expires_at < time.time():
            self.tokens.pop(transfer_id, None)
            raise HTTPException(status_code=401, detail="Transfer token expired or missing")

        expected = f"Bearer {pending.token}"
        if authorization != expected:
            raise HTTPException(status_code=403, detail="Invalid transfer token")
