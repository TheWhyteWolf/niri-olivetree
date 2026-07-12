#!/usr/bin/env bash
# Volume-key wrapper: adjust via wpctl, then flash the wob OSD bar.
# Bound to Mod+KP_* / XF86Audio* in niri (allow-when-locked — the keys still
# work while locked, but session-lock hides overlays so the bar can't show).
set -euo pipefail

case "${1:-}" in
  up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0 ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05- ;;
  mute) wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle ;;
  *)    echo "usage: vol-osd.sh up|down|mute" >&2; exit 2 ;;
esac

sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wob.sock"
[[ -p "$sock" ]] || exit 0   # no OSD listener running; volume changed anyway

# "Volume: 0.45" / "Volume: 0.45 [MUTED]" -> integer percent (0 when muted).
out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
pct=0
if [[ "$out" != *MUTED* ]]; then
  pct=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$out")
fi
# The listener holds the FIFO open for reading, so this never blocks in
# practice; the timeout guards against a dead listener wedging the script.
timeout 0.2 bash -c "echo $pct > '$sock'" || true
