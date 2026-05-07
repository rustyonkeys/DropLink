# DropLink Architecture

## Phase 1 MVP

DropLink uses a local peer-to-peer design.

```text
Android Flutter App                    Windows Python App
-------------------                    ------------------
UDP announcer/listener  <---------->   UDP announcer/listener
HTTP client/server      <---------->   FastAPI transfer server
File picker/storage                  Downloads storage
Modern transfer UI                   CustomTkinter desktop UI
```

## Discovery

Each device broadcasts a JSON UDP packet every few seconds:

```json
{
  "app": "droplink",
  "version": 1,
  "id": "device-uuid",
  "name": "Shreyas Laptop",
  "platform": "windows",
  "host": "192.168.1.20",
  "port": 45871,
  "ts": 1778123456789
}
```

Devices are expired if they have not been seen recently.

## Pairing

Pairing is intentionally lightweight for the MVP:

1. Sender creates an offer with filename, size, MIME type, and sender identity.
2. Receiver shows a confirmation popup.
3. Receiver returns a one-time token when accepted.
4. Sender uses that token to upload the file.

Tokens are kept in memory and expire after a short time.

## Transfer

File bytes are transferred by HTTP multipart upload to:

```text
POST /api/transfers/{transfer_id}/upload
Authorization: Bearer <temporary-token>
```

The receiver streams chunks to disk, so large files do not need to be held fully in memory.

## Roadmap

Phase 2:

- BLE discovery
- Background transfers
- Multi-file batch flow
- Better motion design

Phase 3:

- AES-GCM encryption
- Resume interrupted transfers
- QR pairing
- Drag and drop on Windows
- Auto reconnect
