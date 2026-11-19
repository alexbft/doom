#!/usr/bin/env bash
# Quiet test launch for automated checks: small window, no sound, keeps
# rendering when unfocused, separate config (config/dev.ini) so the
# player's settings in config/uzdoom.ini stay untouched.
# Screenshots go to config/screenshots/.
# SHOTS=<scene> also loads tools/devshot, which plays a scripted scene and
# takes screenshots (the game keeps running after). Scenes: start, look, button
# (see tools/devshot/zscript.zs). SHOTS=1 means "look".
# Extra arguments go to UZDoom.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/config/screenshots"

EXTRA=()
if [ -n "${SHOTS:-}" ] && [ "$SHOTS" != "0" ]; then
  SCENE="$SHOTS"; [ "$SCENE" = "1" ] && SCENE=look
  EXTRA=(-file "$ROOT/tools/devshot" +enablescriptscreenshot 1 +devshot_scene "$SCENE")
fi

CONFIG="$ROOT/config/dev.ini" exec "$ROOT/run.sh" \
  ${EXTRA[@]+"${EXTRA[@]}"} \
  -nosound \
  +vid_fullscreen 0 +win_w 960 +win_h 600 \
  +vid_activeinbackground 1 +i_pauseinbackground 0 \
  +screenshot_dir "$ROOT/config/screenshots" +screenshot_quiet 1 \
  "$@"
