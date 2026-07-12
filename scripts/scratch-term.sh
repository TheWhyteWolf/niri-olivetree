#!/usr/bin/env bash
# scratch-term.sh — quake-style dropdown terminal for niri (Mod+Grave).
#
# Toggles a persistent floating kitty (app-id "scratchterm") snapped to the
# top half of the screen (via float-snap.sh):
#   - not running            -> spawn it and snap it
#   - visible and focused    -> hide it (stash on the trailing empty
#                               workspace; a named workspace would sort
#                               first on the output and steal Mod+1)
#   - hidden or unfocused    -> bring it to the focused workspace and focus it
set -euo pipefail

APP_ID="scratchterm"
SNAP="$HOME/.local/bin/float-snap.sh"

win=$(niri msg --json windows | jq "[.[] | select(.app_id == \"$APP_ID\")][0]")

if [[ -z "$win" || "$win" == null ]]; then
  setsid kitty --app-id "$APP_ID" >/dev/null 2>&1 &
  # Wait for the window to map, then pin it to the top half.
  id=null
  for _ in $(seq 1 40); do
    id=$(niri msg --json windows | jq "[.[] | select(.app_id == \"$APP_ID\")][0].id")
    if [[ "$id" != null ]]; then break; fi
    sleep 0.05
  done
  if [[ "$id" != null ]]; then "$SNAP" half-top "$id"; fi
  exit 0
fi

read -r id ws_id focused <<<"$(jq -r '"\(.id) \(.workspace_id) \(.is_focused)"' <<<"$win")"
read -r cur_ws_id cur_ws_idx <<<"$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | "\(.id) \(.idx)"')"

if [[ "$ws_id" == "$cur_ws_id" && "$focused" == true ]]; then
  # Visible and focused -> stash on the trailing empty workspace without
  # dragging focus along (niri always keeps one empty workspace at the end).
  last_idx=$(niri msg --json workspaces | jq '[.[].idx] | max')
  niri msg action move-window-to-workspace --window-id "$id" --focus false "$last_idx"
else
  # Summon: move to the focused workspace, re-assert the top-half geometry
  # (also self-heals if it was re-tiled or dragged), then focus it.
  niri msg action move-window-to-workspace --window-id "$id" --focus false "$cur_ws_idx"
  "$SNAP" half-top "$id"
  niri msg action focus-window --id "$id"
fi
