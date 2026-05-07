from __future__ import annotations

from dataclasses import dataclass, field
from time import time


@dataclass
class Device:
    id: str
    name: str
    platform: str
    host: str
    port: int
    last_seen: float = field(default_factory=time)

    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"


@dataclass
class TransferOffer:
    transfer_id: str
    sender_id: str
    sender_name: str
    filename: str
    size: int
    mime_type: str = "application/octet-stream"
    created_at: float = field(default_factory=time)


@dataclass
class PendingToken:
    token: str
    transfer_id: str
    expires_at: float
