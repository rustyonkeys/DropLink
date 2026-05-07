from __future__ import annotations

from pathlib import Path


class StorageManager:
    def __init__(self, download_dir: Path) -> None:
        self.download_dir = download_dir
        self.download_dir.mkdir(parents=True, exist_ok=True)

    def safe_destination(self, filename: str) -> Path:
        cleaned = Path(filename).name or "droplink-file"
        destination = self.download_dir / cleaned
        if not destination.exists():
            return destination

        stem = destination.stem
        suffix = destination.suffix
        counter = 1
        while True:
            candidate = self.download_dir / f"{stem} ({counter}){suffix}"
            if not candidate.exists():
                return candidate
            counter += 1
