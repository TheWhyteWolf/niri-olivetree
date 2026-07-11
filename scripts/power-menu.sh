#!/usr/bin/env bash
# Power menu: fuzzel dmenu, olive-styled via fuzzel.ini.
# Bound to Mod+Shift+E in niri (Ctrl+Alt+Delete stays as the raw quit fallback).
set -euo pipefail

choice=$(printf 'Lock\nSuspend\nLog out\nReboot\nPower off' \
  | fuzzel --dmenu --prompt "power> " --lines 5) || exit 0

case "$choice" in
  "Lock")      loginctl lock-session ;;
  "Suspend")   systemctl suspend ;;
  "Log out")   niri msg action quit --skip-confirmation ;;
  "Reboot")    systemctl reboot ;;
  "Power off") systemctl poweroff ;;
esac
