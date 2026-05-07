from __future__ import annotations

import json
import socket
import threading
import time
from typing import Callable, Dict, List, Optional

from .config import APP_NAME, DEVICE_TIMEOUT_SECONDS, DISCOVERY_INTERVAL_SECONDS, AppConfig, get_lan_ip
from .models import Device

DeviceCallback = Callable[[Dict[str, Device]], None]


class DiscoveryService:
    def __init__(self, config: AppConfig, on_devices_changed: Optional[DeviceCallback] = None) -> None:
        self.config = config
        self.on_devices_changed = on_devices_changed
        self.devices: Dict[str, Device] = {}
        self._stop = threading.Event()
        self._threads: List[threading.Thread] = []

    def start(self) -> None:
        self._threads = [
            threading.Thread(target=self._announce_loop, daemon=True),
            threading.Thread(target=self._listen_loop, daemon=True),
            threading.Thread(target=self._cleanup_loop, daemon=True),
        ]
        for thread in self._threads:
            thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _payload(self) -> bytes:
        payload = {
            "app": APP_NAME,
            "version": 1,
            "id": self.config.device_id,
            "name": self.config.device_name,
            "platform": self.config.platform,
            "host": get_lan_ip(),
            "port": self.config.http_port,
            "ts": int(time.time() * 1000),
        }
        return json.dumps(payload).encode("utf-8")

    def _announce_loop(self) -> None:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            while not self._stop.is_set():
                try:
                    sock.sendto(self._payload(), ("255.255.255.255", self.config.discovery_port))
                except OSError:
                    pass
                self._stop.wait(DISCOVERY_INTERVAL_SECONDS)

    def _listen_loop(self) -> None:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(("", self.config.discovery_port))
            sock.settimeout(1)
            while not self._stop.is_set():
                try:
                    data, addr = sock.recvfrom(4096)
                    self._handle_packet(data, addr[0])
                except socket.timeout:
                    continue
                except OSError:
                    continue

    def _handle_packet(self, data: bytes, fallback_host: str) -> None:
        try:
            packet = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return

        if packet.get("app") != APP_NAME or packet.get("id") == self.config.device_id:
            return

        device_id = str(packet.get("id", ""))
        name = str(packet.get("name", "Unknown device"))
        platform = str(packet.get("platform", "unknown"))
        host = str(packet.get("host") or fallback_host)
        port = int(packet.get("port", 0))
        if not device_id or not port:
            return

        self.devices[device_id] = Device(device_id, name, platform, host, port)
        self._notify()

    def _cleanup_loop(self) -> None:
        while not self._stop.is_set():
            now = time.time()
            stale = [device_id for device_id, device in self.devices.items() if now - device.last_seen > DEVICE_TIMEOUT_SECONDS]
            for device_id in stale:
                self.devices.pop(device_id, None)
            if stale:
                self._notify()
            self._stop.wait(2)

    def _notify(self) -> None:
        if self.on_devices_changed:
            self.on_devices_changed(dict(self.devices))
