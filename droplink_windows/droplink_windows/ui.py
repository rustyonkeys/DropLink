from __future__ import annotations

import threading
from pathlib import Path
from tkinter import filedialog, messagebox
from typing import Any, Dict, List, Optional

import customtkinter as ctk

from .config import AppConfig, get_lan_ip
from .discovery import DiscoveryService
from .models import Device, TransferOffer
from .sender import FileSender


class DropLinkApp(ctk.CTk):
    def __init__(self, config: AppConfig, discovery: DiscoveryService, sender: FileSender) -> None:
        super().__init__()
        self.config = config
        self.discovery = discovery
        self.sender = sender
        self.devices: Dict[str, Device] = {}
        self.incoming_offers: Dict[str, TransferOffer] = {}
        self.transfer_rows: Dict[str, Dict[str, Any]] = {}
        self.selected_device: Optional[Device] = None

        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        self.title("DropLink")
        self.geometry("860x560")
        self.minsize(720, 480)
        self._build()

    def _build(self) -> None:
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=3)
        self.grid_rowconfigure(2, weight=1)

        header = ctk.CTkFrame(self, fg_color="transparent")
        header.grid(row=0, column=0, padx=24, pady=(20, 8), sticky="ew")
        header.grid_columnconfigure(0, weight=1)

        title = ctk.CTkLabel(header, text="DropLink", font=ctk.CTkFont(size=30, weight="bold"))
        title.grid(row=0, column=0, sticky="w")

        subtitle = ctk.CTkLabel(
            header,
            text=f"{self.config.device_name} - {get_lan_ip()}:{self.config.http_port}",
            text_color=("#526070", "#aab4c0"),
        )
        subtitle.grid(row=1, column=0, sticky="w", pady=(4, 0))

        send_button = ctk.CTkButton(header, text="Send File", command=self._pick_and_send, height=40)
        send_button.grid(row=0, column=1, rowspan=2, sticky="e")

        body = ctk.CTkFrame(self, corner_radius=18)
        body.grid(row=1, column=0, padx=24, pady=16, sticky="nsew")
        body.grid_columnconfigure(0, weight=1)
        body.grid_rowconfigure(1, weight=1)

        body_title = ctk.CTkLabel(body, text="Nearby Devices", font=ctk.CTkFont(size=18, weight="bold"))
        body_title.grid(row=0, column=0, padx=20, pady=(18, 8), sticky="w")

        self.device_frame = ctk.CTkScrollableFrame(body, fg_color="transparent")
        self.device_frame.grid(row=1, column=0, padx=14, pady=(0, 14), sticky="nsew")
        self.empty_label = ctk.CTkLabel(self.device_frame, text="Scanning local network...")
        self.empty_label.pack(pady=42)

        transfers = ctk.CTkFrame(self, corner_radius=18)
        transfers.grid(row=2, column=0, padx=24, pady=(0, 12), sticky="nsew")
        transfers.grid_columnconfigure(0, weight=1)
        transfers.grid_rowconfigure(1, weight=1)

        transfers_title = ctk.CTkLabel(transfers, text="Transfers", font=ctk.CTkFont(size=18, weight="bold"))
        transfers_title.grid(row=0, column=0, padx=20, pady=(16, 8), sticky="w")

        self.transfer_frame = ctk.CTkScrollableFrame(transfers, fg_color="transparent", height=110)
        self.transfer_frame.grid(row=1, column=0, padx=14, pady=(0, 14), sticky="nsew")
        self.transfer_empty_label = ctk.CTkLabel(self.transfer_frame, text="Received files will appear here.")
        self.transfer_empty_label.pack(pady=24)

        self.status = ctk.CTkLabel(self, text="Ready", anchor="w")
        self.status.grid(row=3, column=0, padx=24, pady=(0, 16), sticky="ew")

    def update_devices(self, devices: Dict[str, Device]) -> None:
        self.after(0, lambda: self._render_devices(devices))

    def _render_devices(self, devices: Dict[str, Device]) -> None:
        self.devices = devices
        for child in self.device_frame.winfo_children():
            child.destroy()

        if not devices:
            self.empty_label = ctk.CTkLabel(self.device_frame, text="Scanning local network...")
            self.empty_label.pack(pady=42)
            return

        for device in devices.values():
            card = ctk.CTkButton(
                self.device_frame,
                text=f"{device.name}\n{device.platform} - {device.host}:{device.port}",
                height=76,
                anchor="w",
                command=lambda selected=device: self._select_device(selected),
            )
            card.pack(fill="x", padx=6, pady=6)

    def confirm_offer(self, offer: TransferOffer) -> bool:
        result: List[bool] = [False]
        event = threading.Event()

        def ask() -> None:
            result[0] = messagebox.askyesno(
                "Accept file transfer?",
                f"{offer.sender_name} wants to send:\n\n{offer.filename}\n{offer.size / (1024 * 1024):.2f} MB",
            )
            event.set()

        self.after(0, ask)
        if not event.wait(timeout=60):
            return False
        if result[0]:
            self.incoming_offers[offer.transfer_id] = offer
            self.after(0, lambda: self._upsert_transfer_row(offer.transfer_id, "Downloading", offer.filename, 0, offer.size))
        return result[0]

    def transfer_progress(self, transfer_id: str, received: int, total: int) -> None:
        offer = self.incoming_offers.get(transfer_id)
        filename = offer.filename if offer else transfer_id
        expected = total or (offer.size if offer else 0)
        state = "Downloaded" if expected and received >= expected else "Downloading"
        self.after(0, lambda: self._upsert_transfer_row(transfer_id, state, filename, received, expected))

    def _select_device(self, device: Device) -> None:
        self.selected_device = device
        self.status.configure(text=f"Selected {device.name}")

    def _pick_and_send(self) -> None:
        if not self.selected_device:
            messagebox.showinfo("Select a device", "Choose a nearby device first.")
            return
        filename = filedialog.askopenfilename()
        if not filename:
            return
        threading.Thread(target=self._send_file_worker, args=(Path(filename), self.selected_device), daemon=True).start()

    def _send_file_worker(self, path: Path, device: Device) -> None:
        try:
            self.sender.send(device, path, self._send_progress)
            self.after(0, lambda: self.status.configure(text=f"Sent {path.name}"))
        except Exception as exc:
            self.after(0, lambda: messagebox.showerror("Transfer failed", str(exc)))

    def _send_progress(self, sent: int, total: int, speed: float) -> None:
        percent = sent / total * 100 if total else 0
        speed_mb = speed / (1024 * 1024)
        self.after(0, lambda: self.status.configure(text=f"Sending... {percent:.1f}% at {speed_mb:.2f} MB/s"))

    def _upsert_transfer_row(self, transfer_id: str, state: str, filename: str, received: int, total: int) -> None:
        if self.transfer_empty_label.winfo_exists():
            self.transfer_empty_label.destroy()

        row = self.transfer_rows.get(transfer_id)
        if row is None:
            frame = ctk.CTkFrame(self.transfer_frame, corner_radius=12)
            frame.pack(fill="x", padx=6, pady=6)
            frame.grid_columnconfigure(1, weight=1)

            badge = ctk.CTkLabel(frame, text="", width=92, font=ctk.CTkFont(size=13, weight="bold"))
            badge.grid(row=0, column=0, padx=(12, 10), pady=12, sticky="ns")

            name = ctk.CTkLabel(frame, text=filename, anchor="w", font=ctk.CTkFont(size=14, weight="bold"))
            name.grid(row=0, column=1, padx=(0, 12), pady=(10, 0), sticky="ew")

            detail = ctk.CTkLabel(frame, text="", anchor="w", text_color=("#526070", "#aab4c0"))
            detail.grid(row=1, column=1, padx=(0, 12), pady=(2, 10), sticky="ew")

            row = {"badge": badge, "name": name, "detail": detail}
            self.transfer_rows[transfer_id] = row

        percent = received / total * 100 if total else 0
        received_mb = received / (1024 * 1024)
        total_mb = total / (1024 * 1024) if total else 0
        detail = f"{received_mb:.2f} MB"
        if total:
            detail = f"{detail} of {total_mb:.2f} MB ({percent:.0f}%)"

        badge = row["badge"]
        badge.configure(
            text=state,
            fg_color=("#1f6aa5", "#1f6aa5") if state == "Downloading" else ("#2d7d46", "#2d7d46"),
            corner_radius=10,
        )
        row["name"].configure(text=filename)
        row["detail"].configure(text=detail)
        self.status.configure(text=f"{state} {filename}")
