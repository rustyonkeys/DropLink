from __future__ import annotations

import socket
import uuid
from dataclasses import dataclass, field
from pathlib import Path


APP_NAME = "droplink"
DISCOVERY_PORT = 45870
DEFAULT_HTTP_PORT = 45871
DISCOVERY_INTERVAL_SECONDS = 2.0
DEVICE_TIMEOUT_SECONDS = 8.0
TOKEN_TTL_SECONDS = 120
CHUNK_SIZE = 1024 * 1024


def get_download_dir() -> Path:
    downloads = Path.home() / "Downloads" / "DropLink"
    downloads.mkdir(parents=True, exist_ok=True)
    return downloads


def get_lan_ip() -> str:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try:
            sock.connect(("8.8.8.8", 80))
            return sock.getsockname()[0]
        except OSError:
            return "127.0.0.1"


@dataclass
class AppConfig:
    device_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    device_name: str = field(default_factory=socket.gethostname)
    platform: str = "windows"
    http_port: int = DEFAULT_HTTP_PORT
    discovery_port: int = DISCOVERY_PORT
    download_dir: Path = field(default_factory=get_download_dir)
