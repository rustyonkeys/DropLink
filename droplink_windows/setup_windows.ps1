param(
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"

Write-Host "DropLink Windows setup" -ForegroundColor Cyan
Write-Host "Using Python command: $PythonCommand"

$env:PYTHONPATH = ""
$env:PYTHONHOME = ""
$env:PIP_REQUIRE_VIRTUALENV = ""

if (!(Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "Creating isolated virtual environment..."
    & $PythonCommand -m venv .venv
}

$VenvPython = ".venv\Scripts\python.exe"

Write-Host "Python inside venv:"
& $VenvPython -c "import sys; print(sys.executable); print(sys.version)"

Write-Host "Upgrading packaging tools inside .venv..."
& $VenvPython -m pip install --isolated --upgrade pip setuptools wheel

Write-Host "Installing DropLink dependencies..."
& $VenvPython -m pip install --isolated -r requirements.txt

Write-Host "Checking imports..."
& $VenvPython -c "import sys; print(sys.executable); import uvicorn, fastapi, customtkinter, requests; print('DropLink dependencies OK')"

Write-Host ""
Write-Host "Setup complete. Start DropLink with:" -ForegroundColor Green
Write-Host "  .\.venv\Scripts\python.exe -m droplink_windows.main"
