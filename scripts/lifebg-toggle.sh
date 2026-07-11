#!/usr/bin/env bash
# Pause/resume the Game of Life wallpaper (SIGSTOP/SIGCONT on lifebg).
# Bound to Mod+Shift+G in niri. Frozen wallpaper costs zero CPU; the last
# frame stays on screen. lifewall resyncs its clock on resume.
set -euo pipefail

# Matches the rust binary (…/bin/lifebg) or the python fallback
# (python3 …/bin/lifebg) but NOT the kitty panel, whose multi-word cmdline
# also ends in bin/lifebg — [^ ]* cannot span its spaces.
pattern='^(python[0-9.]* )?[^ ]*bin/lifebg( |$)'
pid=$(pgrep -f "$pattern" | head -1) || {
  notify-send -t 2000 "Game of Life" "wallpaper is not running"
  exit 0
}

if [[ "$(ps -o stat= -p "$pid" | tr -d ' ')" == T* ]]; then
  kill -CONT "$pid"
  notify-send -t 1500 "Game of Life" "resumed"
else
  kill -STOP "$pid"
  notify-send -t 1500 "Game of Life" "paused"
fi
