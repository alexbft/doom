# Download UZDoom (Windows x64) and Freedoom into this folder.
# Nothing is installed globally. Safe to re-run: existing files are skipped.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$UzdoomVersion   = "5.0.3"
$FreedoomVersion = "0.13.0"
$FreedoomSha256  = "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"

$Root  = $PSScriptRoot
$Cache = Join-Path $Root ".cache"
New-Item -ItemType Directory -Force -Path $Cache, (Join-Path $Root "iwad") | Out-Null

$EngineDir = Join-Path $Root "engine\windows"
if (-not (Test-Path (Join-Path $EngineDir "uzdoom.exe"))) {
    Write-Host "Downloading UZDoom $UzdoomVersion for Windows..."
    $zip = Join-Path $Cache "uzdoom-win.zip"
    Invoke-WebRequest -Uri "https://github.com/UZDoom/UZDoom/releases/download/$UzdoomVersion/Windows-UZDoom-Release-x86_64.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $EngineDir -Force
}

if (-not (Test-Path (Join-Path $Root "iwad\freedoom2.wad"))) {
    Write-Host "Downloading Freedoom $FreedoomVersion..."
    $zip = Join-Path $Cache "freedoom.zip"
    Invoke-WebRequest -Uri "https://github.com/freedoom/freedoom/releases/download/v$FreedoomVersion/freedoom-$FreedoomVersion.zip" -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $FreedoomSha256) { throw "Freedoom checksum mismatch" }
    $fd = Join-Path $Cache "fd"
    if (Test-Path $fd) { Remove-Item -Recurse -Force $fd }
    Expand-Archive -Path $zip -DestinationPath $fd -Force
    Copy-Item (Join-Path $fd "freedoom-$FreedoomVersion\freedoom2.wad") (Join-Path $Root "iwad\")
    Copy-Item (Join-Path $fd "freedoom-$FreedoomVersion\COPYING.txt") (Join-Path $Root "iwad\FREEDOOM-COPYING.txt")
}

Write-Host "Setup done. Start the game with run.cmd"
