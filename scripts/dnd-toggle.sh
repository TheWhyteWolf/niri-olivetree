#!/usr/bin/env bash
# Toggle mako's do-not-disturb mode. Bound to Mod+N in niri and to the
# waybar DND label's on-click; the RTMIN+8 ping refreshes that label.
set -euo pipefail

makoctl mode -t do-not-disturb >/dev/null
pkill -RTMIN+8 waybar || true
