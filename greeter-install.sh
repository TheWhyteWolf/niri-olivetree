#!/usr/bin/env bash
# Switch the login screen to greetd + lifegreet — the Game of Life greeter that
# matches the lifelock lock screen (tuigreet stays installed as the fallback).
# Separate from install.sh because it replaces the display manager — run it
# once, deliberately: bash greeter-install.sh
# Idempotent — safe to re-run (also how you deploy a rebuilt lifegreet). Needs sudo.
#
# Rollback (from a TTY, Ctrl+Alt+F3):
#   back to tuigreet: sudo install -Dm644 ~/niri-olivetree/greetd/config-tuigreet.toml /etc/greetd/config.toml
#                     sudo systemctl restart greetd
#   off greetd:       sudo systemctl disable greetd && sudo systemctl enable <your-old-dm> && reboot
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_DATA_HOME:-$HOME/.local/share}/niri-olivetree/src"

echo "==> Installing greetd + tuigreet (fallback) + cage + build tools + rice font"
sudo pacman -S --needed greetd greetd-tuigreet cage git rust ttf-sharetech-mono-nerd

if ! command -v cargo >/dev/null 2>&1; then
  echo "    ERROR: cargo not found — lifegreet is a Rust binary and needs it." >&2
  exit 1
fi

echo "==> Building lifegreet (Game of Life greeter) from the lifegate repo"
if [[ -d "$SRC/lifegate/.git" ]]; then
  git -C "$SRC/lifegate" pull --ff-only --quiet
else
  mkdir -p "$(dirname "$SRC/lifegate")"
  git clone --quiet https://github.com/TheWhyteWolf/lifegate.git "$SRC/lifegate"
fi
(cd "$SRC/lifegate" && cargo build --release -p lifegreet)
# /usr/local/bin, not ~/.local/bin: the binary runs as the `greeter` user.
sudo install -Dm755 "$SRC/lifegate/target/release/lifegreet" /usr/local/bin/lifegreet
# Wrapper: wipes vt1 (cursor + text + scrollback) so the KMS handoffs flash
# pure black, then execs cage+lifegreet with output in the journal, not the VT.
sudo install -Dm755 "$REPO/greetd/lifegreet-cage" /usr/local/bin/lifegreet-cage

echo "==> Installing /etc/greetd/config.toml"
if [[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.bak ]] \
   && ! cmp -s "$REPO/greetd/config.toml" /etc/greetd/config.toml; then
  sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
  echo "    backed up previous config to config.toml.bak"
fi
sudo install -Dm644 "$REPO/greetd/config.toml" /etc/greetd/config.toml

# Service drop-in: LimitMEMLOCK=infinity (lifegreet mlockalls ~112 MiB; the
# 8 MiB systemd default killed it at boot) and StartLimitIntervalSec=0 (a
# login screen must retry forever, never start-limit-hit into a dead vt1).
echo "==> Installing greetd service drop-in (memlock + restart policy)"
sudo install -Dm644 "$REPO/greetd/greetd.service.d/lifegreet.conf" \
  /etc/systemd/system/greetd.service.d/lifegreet.conf
sudo systemctl daemon-reload
sudo systemctl reset-failed greetd 2>/dev/null || true

# tuigreet (the fallback) needs a writable cache dir for --remember.
echo "==> Creating /var/cache/tuigreet (fallback greeter's remember cache)"
sudo install -d -o greeter -g greeter -m 755 /var/cache/tuigreet

# Swap display managers. enable/disable only touch next boot — the current
# session keeps running; greetd takes over vt1 after a reboot.
current="$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" .service || true)"
if [[ -n "$current" && "$current" != greetd ]]; then
  echo "==> Disabling current display manager: $current"
  sudo systemctl disable "$current"
fi
echo "==> Enabling greetd"
sudo systemctl enable greetd

cat <<EOF

==> Done. greetd + lifegreet take over at next reboot. Never restart greetd
    from inside a session it started — that kills the session. Reboot instead.
    - Pre-reboot check (only from a session greetd did NOT start, e.g. a TTY
      login): sudo systemctl start greetd flips to the greeter on vt1 — look,
      switch back to your VT (Ctrl+Alt+F3...), then sudo systemctl stop greetd.
    - Type your username into the box (required EVERY login — by design),
      Enter grows the cube, then type your password: no text, only panel
      flares (rust flash + collapse back to the box on a wrong password).
    - Esc on an empty password backs out to the username box.
    - F3 = session picker, Ctrl+Alt+Del = reboot.
    - Logs: journalctl -t lifegreet (greeter/cage) and -t greetd-session.
    - If it ever breaks: Ctrl+Alt+F3 to a TTY, then either
      tuigreet fallback:  sudo install -Dm644 $REPO/greetd/config-tuigreet.toml /etc/greetd/config.toml
                          sudo systemctl restart greetd
      or leave greetd:    sudo systemctl disable greetd && sudo systemctl enable ${current:-<your-old-dm>} && reboot
EOF
