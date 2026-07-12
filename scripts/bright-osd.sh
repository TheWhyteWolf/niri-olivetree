#!/usr/bin/env bash
# Brightness-key wrapper (laptop): brightnessctl + a wob OSD flash.
# Bound to XF86MonBrightness* / Mod+F1/F2 in macbook/niri/config.kdl.
set -euo pipefail

case "${1:-}" in
  up)   brightnessctl set 5%+ >/dev/null ;;
  down) brightnessctl set 5%- >/dev/null ;;
  *)    echo "usage: bright-osd.sh up|down" >&2; exit 2 ;;
esac

sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wob.sock"
[[ -p "$sock" ]] || exit 0   # no OSD listener running; brightness changed anyway

# "intel_backlight,backlight,48000,50%,96000" -> 50
pct=$(brightnessctl -m | awk -F, '{ gsub("%", "", $4); print $4 }')
# The listener holds the FIFO open for reading, so this never blocks in
# practice; the timeout guards against a dead listener wedging the script.
timeout 0.2 bash -c "echo $pct > '$sock'" || true
