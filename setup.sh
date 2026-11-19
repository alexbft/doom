#!/usr/bin/env bash
# Download UZDoom (for the current OS) and Freedoom into this folder.
# Nothing is installed globally. Safe to re-run: existing files are skipped.
set -euo pipefail

UZDOOM_VERSION="5.0.3"
FREEDOOM_VERSION="0.13.0"
FREEDOOM_SHA256="3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"

ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE="$ROOT/.cache"
UZ_URL="https://github.com/UZDoom/UZDoom/releases/download/$UZDOOM_VERSION"
mkdir -p "$CACHE" "$ROOT/iwad"

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

case "$(uname -s)" in
  Darwin)
    if [ ! -d "$ROOT/engine/macos/UZDoom.app" ]; then
      echo "Downloading UZDoom $UZDOOM_VERSION for macOS..."
      curl -fL# -o "$CACHE/uzdoom-mac.dmg" "$UZ_URL/MacOS-UZDoom-Release-ARM64.dmg"
      MNT="$(mktemp -d)"
      hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$CACHE/uzdoom-mac.dmg" >/dev/null
      mkdir -p "$ROOT/engine/macos"
      cp -R "$MNT/UZDoom.app" "$ROOT/engine/macos/"
      hdiutil detach "$MNT" -quiet
      xattr -dr com.apple.quarantine "$ROOT/engine/macos/UZDoom.app" 2>/dev/null || true
    fi
    ;;
  Linux)
    if [ ! -x "$ROOT/engine/linux/UZDoom.AppImage" ]; then
      echo "Downloading UZDoom $UZDOOM_VERSION for Linux..."
      mkdir -p "$ROOT/engine/linux"
      curl -fL# -o "$ROOT/engine/linux/UZDoom.AppImage" "$UZ_URL/Linux-UZDoom-Release-x86_64.AppImage"
      chmod +x "$ROOT/engine/linux/UZDoom.AppImage"
    fi
    ;;
  *)
    echo "Unsupported OS. On Windows run setup.cmd instead." >&2
    exit 1
    ;;
esac

if [ ! -f "$ROOT/iwad/freedoom2.wad" ]; then
  echo "Downloading Freedoom $FREEDOOM_VERSION..."
  ZIP="$CACHE/freedoom.zip"
  curl -fL# -o "$ZIP" "https://github.com/freedoom/freedoom/releases/download/v$FREEDOOM_VERSION/freedoom-$FREEDOOM_VERSION.zip"
  [ "$(sha256 "$ZIP")" = "$FREEDOOM_SHA256" ] || { echo "Freedoom checksum mismatch" >&2; exit 1; }
  rm -rf "$CACHE/fd" && mkdir -p "$CACHE/fd"
  unzip -q "$ZIP" -d "$CACHE/fd"
  cp "$CACHE/fd/freedoom-$FREEDOOM_VERSION/freedoom2.wad" "$ROOT/iwad/"
  cp "$CACHE/fd/freedoom-$FREEDOOM_VERSION/COPYING.txt" "$ROOT/iwad/FREEDOOM-COPYING.txt"
fi

echo "Setup done. Start the game with ./run.sh"
