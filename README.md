# DropLink

DropLink is a free, local-only AirDrop-like file sharing prototype for Android phones and Windows laptops.

Phase 1 is implemented for same-WiFi networks:

- UDP broadcast device discovery
- Local HTTP file transfer
- Receiver confirmation with temporary transfer tokens
- Progress, speed, ETA, cancel, retry-ready state structure
- Flutter Android UI
- Python Windows desktop/backend app

No Firebase, cloud backend, paid APIs, or external servers are required.

## Project Structure

```text
droplink_mobile/       Flutter Android app
droplink_windows/      Python Windows app/backend
docs/                  Architecture and setup notes
```

## How It Works

1. Each device starts a local HTTP server for transfer requests.
2. Each device sends UDP presence packets on the local network.
3. Nearby devices appear in the UI.
4. A sender posts a transfer offer to the receiver.
5. The receiver accepts or rejects.
6. On accept, the sender uploads the file over HTTP with a temporary token.
7. The receiver streams the file to Downloads.

BLE discovery is intentionally left for Phase 2 because Android and Windows BLE support have different runtime constraints. The core transfer path already avoids Bluetooth and uses fast local networking.

## Quick Start

### Windows App

```powershell
cd droplink_windows
powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1
.\.venv\Scripts\python.exe -m droplink_windows.main
```

Windows Firewall may ask for local network access. Allow private network access so phones on the same WiFi can discover and transfer files.

### Flutter App

```powershell
cd droplink_mobile
flutter pub get
flutter run
```

Use a physical Android device connected to the same WiFi network as the Windows laptop. Emulators often cannot receive LAN broadcasts reliably.

## Current MVP Limitations

- Same WiFi/local network required.
- UDP broadcast discovery may be blocked by some routers.
- Large file transfer works through streaming, but resume support is planned for Phase 3.
- End-to-end encryption is designed into the roadmap but not enabled in Phase 1.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/SETUP.md](docs/SETUP.md).
