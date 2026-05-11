param(
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"

Write-Host "DropLink Windows app build" -ForegroundColor Cyan

$env:PYTHONPATH = ""
$env:PYTHONHOME = ""
$env:PIP_REQUIRE_VIRTUALENV = ""

if (!(Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "Creating isolated virtual environment..."
    & $PythonCommand -m venv .venv
}

$VenvPython = ".venv\Scripts\python.exe"

Write-Host "Installing runtime dependencies..."
& $VenvPython -m pip install --isolated --upgrade pip setuptools wheel
& $VenvPython -m pip install --isolated -r requirements.txt

Write-Host "Installing build dependency..."
& $VenvPython -m pip install --isolated -r requirements-build.txt

Write-Host "Building DropLink.exe..."
& $VenvPython -m PyInstaller `
    --noconfirm `
    --clean `
    --windowed `
    --name DropLink `
    --collect-all customtkinter `
    --collect-all uvicorn `
    --hidden-import multipart `
    --hidden-import python_multipart `
    --hidden-import uvicorn.logging `
    --hidden-import uvicorn.loops `
    --hidden-import uvicorn.loops.auto `
    --hidden-import uvicorn.protocols `
    --hidden-import uvicorn.protocols.http `
    --hidden-import uvicorn.protocols.http.auto `
    --hidden-import uvicorn.protocols.websockets `
    --hidden-import uvicorn.protocols.websockets.auto `
    --hidden-import uvicorn.lifespan `
    --hidden-import uvicorn.lifespan.on `
    run_droplink.py

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Give your friend this folder:"
Write-Host "  dist\DropLink"
Write-Host ""
Write-Host "They can run:"
Write-Host "  dist\DropLink\DropLink.exe"
