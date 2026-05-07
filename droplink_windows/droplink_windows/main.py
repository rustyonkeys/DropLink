from __future__ import annotations

import threading
from typing import Dict

import uvicorn

from .config import AppConfig
from .discovery import DiscoveryService
from .sender import FileSender
from .storage import StorageManager
from .transfer_server import TransferServer
from .ui import DropLinkApp


def main() -> None:
    config = AppConfig()
    storage = StorageManager(config.download_dir)

    ui_holder: Dict[str, DropLinkApp] = {}

    def on_offer(offer):
        return ui_holder["ui"].confirm_offer(offer)

    def on_progress(transfer_id, received, total):
        ui_holder["ui"].transfer_progress(transfer_id, received, total)

    transfer_server = TransferServer(config, storage, on_offer=on_offer, on_progress=on_progress)
    sender = FileSender(config)
    discovery = DiscoveryService(config)

    ui = DropLinkApp(config, discovery, sender)
    ui_holder["ui"] = ui
    discovery.on_devices_changed = ui.update_devices

    server_thread = threading.Thread(
        target=lambda: uvicorn.run(transfer_server.app, host="0.0.0.0", port=config.http_port, log_level="warning"),
        daemon=True,
    )
    server_thread.start()

    discovery.start()
    try:
        ui.mainloop()
    finally:
        discovery.stop()


if __name__ == "__main__":
    main()
