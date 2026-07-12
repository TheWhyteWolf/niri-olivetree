#!/usr/bin/env bash
# float-snap.sh — Windows-style snapping for niri floating windows.
#
#   left|right|up|down     smart snap (Mod+Alt+arrows / H,J,K,L): halves ->
#                          quarters -> max-with-margins; pressing back toward
#                          the middle steps out and finally restores the
#                          pre-snap geometry
#   tl|tr|bl|br            snap straight to a quarter   (Mod+KP_7/9/1/3)
#   half-left|half-right   snap straight to a half      (Mod+KP_4/6)
#   half-top|half-bottom                                (Mod+KP_8/2)
#   max                    maximize with margins
#   center                 center the floating window   (Mod+Alt+C / KP_5)
#   restore                un-snap to pre-snap geometry (Mod+Alt+R)
#
# An optional second argument targets a specific window id instead of the
# focused window (used by scratch-term.sh and for testing).
#
# Tiled windows auto-float on the first snap; restoring them sends them back
# to the tiling layout (fullscreen windows get unfullscreened by this).
# Pre-snap geometry lives in $XDG_RUNTIME_DIR/float-snap/<window-id>.
#
# Calibrated against niri 26.04:
#   - `move-floating-window -x -y` absolute coords are working-area-relative
#     (below the waybar strut) and position the TILE (window + border);
#   - `tile_pos_in_workspace_view` from `niri msg --json windows` is
#     output-relative -> subtract BAR_TOP before comparing;
#   - `set-window-width/height` size the WINDOW, so tile = size + 2*BORDER;
#   - out-of-bounds moves clamp to keep ~75px of the tile visible.
set -euo pipefail

MARGIN=12    # gap to screen edges / between snapped tiles (matches layout gaps)
BAR_TOP=26   # waybar exclusive height (keep in sync with waybar config.jsonc)
BORDER=2     # niri border width (layout { border { width 2 } })
POS_TOL=10   # px tolerance when matching a zone by position
SIZE_TOL=48  # px tolerance by size (clients round: kitty snaps to cell grid)
STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/float-snap"

verb="${1:-}"
target="${2:-}"
case "$verb" in
  left|right|up|down|tl|tr|bl|br|half-left|half-right|half-top|half-bottom|max|center|restore) ;;
  *) echo "usage: float-snap.sh left|right|up|down|tl|tr|bl|br|half-left|half-right|half-top|half-bottom|max|center|restore [window-id]" >&2
     exit 2 ;;
esac

act() { niri msg action "$@"; }

if [[ -n "$target" ]]; then
  win=$(niri msg --json windows | jq ".[] | select(.id == $target)")
else
  win=$(niri msg --json focused-window)
fi
if [[ -z "$win" || "$win" == null ]]; then exit 0; fi

# id, floating, tile size, tile pos ("none none" while e.g. the overview is open)
read -r id floating tw th tx ty <<<"$(jq -r '
  "\(.id) \(.is_floating) \(.layout.tile_size[0] | round) \(.layout.tile_size[1] | round) " +
  (if .layout.tile_pos_in_workspace_view == null then "none none"
   else "\(.layout.tile_pos_in_workspace_view[0] | round) \(.layout.tile_pos_in_workspace_view[1] | round)" end)
' <<<"$win")"

read -r W H <<<"$(niri msg --json focused-output | jq -r '"\(.logical.width) \(.logical.height)"')"
H=$((H - BAR_TOP))  # working area (moves and zone rects live in this space)

# Zone rects (tile geometry, working-area space): "x y w h".
hw=$(( (W - 3 * MARGIN) / 2 ))  # half width:  W/2 - edge margin - half the inner gap
hh=$(( (H - 3 * MARGIN) / 2 ))
fw=$(( W - 2 * MARGIN ))
fh=$(( H - 2 * MARGIN ))
x2=$(( (W + MARGIN) / 2 ))      # x of the right-hand zones
y2=$(( (H + MARGIN) / 2 ))

zone_geom() {
  case "$1" in
    half-left)   echo "$MARGIN $MARGIN $hw $fh" ;;
    half-right)  echo "$x2 $MARGIN $hw $fh" ;;
    half-top)    echo "$MARGIN $MARGIN $fw $hh" ;;
    half-bottom) echo "$MARGIN $y2 $fw $hh" ;;
    tl)          echo "$MARGIN $MARGIN $hw $hh" ;;
    tr)          echo "$x2 $MARGIN $hw $hh" ;;
    bl)          echo "$MARGIN $y2 $hw $hh" ;;
    br)          echo "$x2 $y2 $hw $hh" ;;
    max)         echo "$MARGIN $MARGIN $fw $fh" ;;
  esac
}

near() {
  local d=$(( $1 - $2 ))
  (( d < 0 )) && d=$(( -d ))
  (( d <= $3 ))
}

detect_zone() {
  if [[ "$tx" == none ]]; then echo free; return; fi
  local cx=$tx cy=$(( ty - BAR_TOP )) z gx gy gw gh
  for z in max tl tr bl br half-left half-right half-top half-bottom; do
    read -r gx gy gw gh <<<"$(zone_geom "$z")"
    if near "$cx" "$gx" "$POS_TOL" && near "$cy" "$gy" "$POS_TOL" \
       && near "$tw" "$gw" "$SIZE_TOL" && near "$th" "$gh" "$SIZE_TOL"; then
      echo "$z"; return
    fi
  done
  echo free
}

# transition CURRENT KEY -> next zone or "restore". Two axes, one step per
# press; arriving back at the middle of both axes restores.
transition() {
  local cur=$1 key=$2 h v
  if [[ "$cur" == max ]]; then
    case "$key" in
      left) echo half-left ;; right) echo half-right ;;
      up) echo max ;; down) echo restore ;;
    esac
    return
  fi
  if [[ "$cur" == half-top && "$key" == up ]]; then echo max; return; fi
  case "$cur" in
    free)        h=C v=M ;;
    half-left)   h=L v=M ;;  half-right)  h=R v=M ;;
    half-top)    h=C v=T ;;  half-bottom) h=C v=B ;;
    tl)          h=L v=T ;;  tr)          h=R v=T ;;
    bl)          h=L v=B ;;  br)          h=R v=B ;;
  esac
  case "$key" in
    left)  if [[ $h == R ]]; then h=C; else h=L; fi ;;
    right) if [[ $h == L ]]; then h=C; else h=R; fi ;;
    up)    if [[ $v == B ]]; then v=M; else v=T; fi ;;
    down)  if [[ $v == T ]]; then v=M; else v=B; fi ;;
  esac
  case "$h$v" in
    CM) echo restore ;;
    LM) echo half-left ;;  RM) echo half-right ;;
    CT) echo half-top ;;   CB) echo half-bottom ;;
    LT) echo tl ;;  RT) echo tr ;;  LB) echo bl ;;  RB) echo br ;;
  esac
}

apply_zone() {
  local x y w h
  read -r x y w h <<<"$(zone_geom "$1")"
  act set-window-width  --id "$id" "$(( w - 2 * BORDER ))"
  act set-window-height --id "$id" "$(( h - 2 * BORDER ))"
  act move-floating-window --id "$id" -x "$x" -y "$y"
}

# Remember the free geometry (window-size units + tile pos in move space) so
# restore can put the window back exactly where it was before snapping.
save_free() {
  if [[ "$tx" == none ]]; then return 0; fi
  mkdir -p "$STATE_DIR"
  echo "$tx $(( ty - BAR_TOP )) $(( tw - 2 * BORDER )) $(( th - 2 * BORDER ))" > "$STATE_DIR/$id"
}

restore_win() {
  local f="$STATE_DIR/$id" s x y w h
  if [[ -f "$f" ]]; then
    s=$(<"$f")
    rm -f "$f"
    if [[ "$s" == tiled ]]; then
      act move-window-to-tiling --id "$id"
    else
      read -r x y w h <<<"$s"
      act set-window-width  --id "$id" "$w"
      act set-window-height --id "$id" "$h"
      act move-floating-window --id "$id" -x "$x" -y "$y"
    fi
  else
    act center-window --id "$id"
  fi
}

# Drop state for windows that no longer exist (also covers the id reset
# after a niri restart).
prune() {
  [[ -d "$STATE_DIR" ]] || return 0
  local live f
  live=$(niri msg --json windows | jq -r '.[].id')
  for f in "$STATE_DIR"/*; do
    [[ -e "$f" ]] || continue
    if ! grep -qxF "$(basename "$f")" <<<"$live"; then rm -f "$f"; fi
  done
}

# Auto-float a tiled window and tag it so restore sends it back to tiling.
# Returns 0 if the window was tiled, 1 if it was already floating.
ensure_float() {
  if [[ "$floating" == true ]]; then return 1; fi
  act move-window-to-floating --id "$id"
  mkdir -p "$STATE_DIR"
  echo tiled > "$STATE_DIR/$id"
  return 0
}

case "$verb" in
  center)
    ensure_float || true
    act center-window --id "$id"
    ;;
  restore)
    if [[ "$floating" == true ]]; then restore_win; fi
    ;;
  tl|tr|bl|br|half-left|half-right|half-top|half-bottom|max)
    if ensure_float; then
      : # freshly floated: state already tagged "tiled"
    elif [[ "$(detect_zone)" == free ]]; then
      save_free
    fi
    apply_zone "$verb"
    ;;
  *)
    was_tiled=0
    if ensure_float; then cur=free; was_tiled=1; else cur=$(detect_zone); fi
    next=$(transition "$cur" "$verb")
    if [[ "$next" == restore ]]; then
      restore_win
    else
      if [[ "$cur" == free && "$was_tiled" == 0 ]]; then save_free; fi
      apply_zone "$next"
    fi
    ;;
esac

prune
