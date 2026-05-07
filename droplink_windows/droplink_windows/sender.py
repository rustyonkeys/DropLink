from __future__ import annotations

import mimetypes
import uuid
from pathlib import Path
from time import monotonic
from typing import Callable, Optional

import requests

from .config import CHUNK_SIZE, AppConfig
from .models import Device

ProgressCallback = Callable[[int, int, float], None]


class ProgressFile:
    def __init__(self, path: Path, on_progress: Optional[ProgressCallback] = None) -> None:
        self.path = path
        self.file = path.open("rb")
        self.size = path.stat().st_size
        self.sent = 0
        self.started = monotonic()
        self.on_progress = on_progress

    def read(self, size: int = CHUNK_SIZE) -> bytes:
        chunk = self.file.read(size)
        if chunk:
            self.sent += len(chunk)
            elapsed = max(monotonic() - self.started, 0.001)
            if self.on_progress:
                self.on_progress(self.sent, self.size, self.sent / elapsed)
        return chunk

    def close(self) -> None:
        self.file.close()


class FileSender:
    def __init__(self, config: AppConfig) -> None:
        self.config = config

    def send(self, device: Device, path: Path, on_progress: Optional[ProgressCallback] = None) -> None:
        transfer_id = str(uuid.uuid4())
        mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        offer = {
            "transfer_id": transfer_id,
            "sender_id": self.config.device_id,
            "sender_name": self.config.device_name,
            "filename": path.name,
            "size": path.stat().st_size,
            "mime_type": mime_type,
        }

        offer_response = requests.post(f"{device.base_url}/api/offers", json=offer, timeout=30)
        offer_response.raise_for_status()
        offer_data = offer_response.json()
        if not offer_data.get("accepted"):
            raise RuntimeError(offer_data.get("message") or "Transfer declined")

        token = offer_data["token"]
        progress_file = ProgressFile(path, on_progress)
        try:
            files = {"file": (path.name, progress_file, mime_type)}
            response = requests.post(
                f"{device.base_url}/api/transfers/{transfer_id}/upload",
                files=files,
                headers={"Authorization": f"Bearer {token}"},
                timeout=None,
            )
            response.raise_for_status()
        finally:
            progress_file.close()
