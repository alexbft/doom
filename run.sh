#!/usr/bin/env bash
# Launch the arena mod (macOS / Linux). Extra arguments go to UZDoom,
# e.g. ./run.sh +god  or  ./run.sh -skill 4
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MAP="${MAP:-ARENA01}"
CONFIG="${CONFIG:-$ROOT/config/uzdoom.ini}"

case "$(uname -s)" in
  Darwin) ENGINE="$ROOT/engine/macos/UZDoom.app/Contents/MacOS/uzdoom" ;;
  Linux)  ENGINE="$ROOT/engine/linux/UZDoom.AppImage" ;;
  *) echo "Unsupported OS. On Windows use run.cmd." >&2; exit 1 ;;
esac

if [ ! -x "$ENGINE" ] || [ ! -f "$ROOT/iwad/freedoom2.wad" ]; then
  echo "Engine or IWAD missing - running setup first..."
  "$ROOT/setup.sh"
fi

mkdir -p "$ROOT/config"
exec "$ENGINE" \
  -config "$CONFIG" \
  -iwad "$ROOT/iwad/freedoom2.wad" \
  -file "$ROOT/mod" \
  +vid_fullscreen 0 +win_w 1280 +win_h 800 \
  +map "$MAP" \
  "$@"
