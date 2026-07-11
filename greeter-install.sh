#!/usr/bin/env bash
# Switch the login screen to greetd + tuigreet (olive console greeter).
# Separate from install.sh because it replaces the display manager — run it
# once, deliberately: bash greeter-install.sh
# Idempotent — safe to re-run. Needs sudo.
#
# Rollback (from a TTY, Ctrl+Alt+F3):
#   sudo systemctl disable greetd && sudo systemctl enable <your-old-dm> && reboot
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing greetd + tuigreet"
sudo pacman -S --needed greetd greetd-tuigreet

echo "==> Installing /etc/greetd/config.toml"
if [[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.bak ]] \
   && ! cmp -s "$REPO/greetd/config.toml" /etc/greetd/config.toml; then
  sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
  echo "    backed up stock config to config.toml.bak"
fi
sudo install -Dm644 "$REPO/greetd/config.toml" /etc/greetd/config.toml

# tuigreet needs a writable cache dir (as the greeter user) for --remember.
echo "==> Creating /var/cache/tuigreet (remembers last user/session)"
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

==> Done. greetd + tuigreet take over at next reboot.
    - Enter = log in (defaults to Niri; remembers your last session per user)
    - F3 = session picker, F12 = power menu
    - If it ever breaks: Ctrl+Alt+F3 to a TTY, then
      sudo systemctl disable greetd && sudo systemctl enable ${current:-<your-old-dm>} && reboot
EOF
