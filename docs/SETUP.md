# Setup Guide

## Requirements

- Windows 10/11
- Python 3.8+ for the current MVP, Python 3.10+ recommended
- Flutter stable
- Android phone on the same WiFi network

## Windows

Recommended:

```powershell
cd D:\ProjectNew\Python\Dropfile\droplink_windows
powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1
.\.venv\Scripts\python.exe -m droplink_windows.main
```

Manual:

```powershell
cd droplink_windows
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
python -m droplink_windows.main
```

If your terminal shows warnings from `C:\ProgramData\Anaconda3\Lib\site-packages` or errors like `Invalid version: '4.0.0-unsupported'`, you are using a broken global Python/Anaconda environment. Do not run global `python -m pip install --upgrade pip`. Use the `.venv\Scripts\python.exe` commands above so pip runs inside DropLink's isolated environment.

If your venv uses Python 3.8, keep `uvicorn[standard]==0.33.0`. Newer `uvicorn` versions require newer Python and pip will report that no matching distribution exists.

If `python -m droplink_windows.main` imports from `C:\ProgramData\Anaconda3`, your prompt may show `(venv)` but still be using Anaconda packages. Start with the explicit interpreter:

```powershell
.\.venv\Scripts\python.exe -c "import sys; print(sys.executable)"
.\.venv\Scripts\python.exe -m droplink_windows.main
```

If discovery does not work:

- Confirm Windows and Android are on the same WiFi.
- Allow Python through Windows Firewall on private networks.
- Disable AP/client isolation in router settings.
- Try another WiFi network or mobile hotspot.

## Android

```powershell
cd droplink_mobile
flutter pub get
flutter run
```

Android permissions needed:

- Internet/local network sockets
- WiFi state
- Storage/file access through picker
- Nearby/Bluetooth permissions in Phase 2

## Testing Locally

1. Start the Windows app.
2. Run the Flutter app on a physical Android phone.
3. Wait for each device to appear.
4. Pick a file on Android and send it to Windows.
5. The Windows app prompts to accept.
6. Accepted files are saved in Downloads/DropLink.
