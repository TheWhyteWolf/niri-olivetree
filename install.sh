#!/usr/bin/env bash
# Install niri-olivetree: packages + symlinks + validate.
# Idempotent — safe to re-run. Needs your sudo password for the package step.
# Arch-based distros; see README.md for the package list on anything else.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Official repos:
PKGS=(niri kitty fuzzel waybar mako swaybg xwayland-satellite wl-clipboard cliphist jq wob
      swaylock swayidle brightnessctl adw-gtk-theme
      ttf-sharetech-mono-nerd ttf-cousine-nerd xdg-desktop-portal-gtk xdg-desktop-portal-gnome qt6ct)
# AUR (cursor theme):
AUR_PKGS=(phinger-cursors)

echo "==> Installing packages: ${PKGS[*]} ${AUR_PKGS[*]}"
if command -v yay >/dev/null 2>&1; then
  yay -S --needed "${PKGS[@]}" "${AUR_PKGS[@]}"
elif command -v paru >/dev/null 2>&1; then
  paru -S --needed "${PKGS[@]}" "${AUR_PKGS[@]}"
else
  sudo pacman -S --needed "${PKGS[@]}"
  echo "    NOTE: no AUR helper found — install ${AUR_PKGS[*]} yourself"
  echo "    (or swap the cursor theme in niri/config.kdl for one you have)."
fi

# link SRC DST — back up a real file at DST to DST.bak (once), then symlink.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "    backing up $dst -> $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "    linked $dst -> $src"
}

echo "==> Symlinking configs into ~/.config"
link "$REPO/niri/config.kdl"     "$HOME/.config/niri/config.kdl"
link "$REPO/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "$REPO/waybar/style.css"    "$HOME/.config/waybar/style.css"
link "$REPO/fuzzel/fuzzel.ini"   "$HOME/.config/fuzzel/fuzzel.ini"
link "$REPO/mako/config"         "$HOME/.config/mako/config"
link "$REPO/kitty/rice.conf"     "$HOME/.config/kitty/rice.conf"
link "$REPO/kitty/olive.conf"    "$HOME/.config/kitty/olive.conf"
link "$REPO/wob/wob.ini"         "$HOME/.config/wob/wob.ini"
link "$REPO/swaylock/config"     "$HOME/.config/swaylock/config"
link "$REPO/xdg/portals.conf"    "$HOME/.config/xdg-desktop-portal/portals.conf"
link "$REPO/qt6ct/qt6ct.conf"    "$HOME/.config/qt6ct/qt6ct.conf"

# Wire rice.conf into kitty.conf (appended -> last-wins over the stock config).
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
touch "$KITTY_CONF"
if ! grep -qxF 'include rice.conf' "$KITTY_CONF"; then
  printf '\n# Olive rice extras (transparency + font; managed by niri-olivetree).\ninclude rice.conf\n' >> "$KITTY_CONF"
  echo "    appended 'include rice.conf' to $KITTY_CONF"
fi

echo "==> Installing scripts into ~/.local/bin"
chmod +x "$REPO/scripts/clip-menu.sh" "$REPO/scripts/life.py" \
         "$REPO/scripts/power-menu.sh" "$REPO/scripts/lifebg-toggle.sh" \
         "$REPO/scripts/float-snap.sh" "$REPO/scripts/scratch-term.sh" \
         "$REPO/scripts/vol-osd.sh" "$REPO/scripts/bright-osd.sh" "$REPO/scripts/dnd-toggle.sh"
mkdir -p "$HOME/.local/bin"
ln -sfn "$REPO/scripts/clip-menu.sh"     "$HOME/.local/bin/clip-menu.sh"
ln -sfn "$REPO/scripts/power-menu.sh"    "$HOME/.local/bin/power-menu.sh"
ln -sfn "$REPO/scripts/lifebg-toggle.sh" "$HOME/.local/bin/lifebg-toggle.sh"
ln -sfn "$REPO/scripts/float-snap.sh"    "$HOME/.local/bin/float-snap.sh"
ln -sfn "$REPO/scripts/scratch-term.sh"  "$HOME/.local/bin/scratch-term.sh"
ln -sfn "$REPO/scripts/vol-osd.sh"       "$HOME/.local/bin/vol-osd.sh"
ln -sfn "$REPO/scripts/bright-osd.sh"    "$HOME/.local/bin/bright-osd.sh"
ln -sfn "$REPO/scripts/dnd-toggle.sh"    "$HOME/.local/bin/dnd-toggle.sh"

echo "==> Game of Life wallpaper (~/.local/bin/lifebg)"
if command -v cargo >/dev/null 2>&1; then
  (cd "$REPO/lifewall" && cargo build --release)
  ln -sfn "$REPO/lifewall/target/release/lifewall" "$HOME/.local/bin/lifebg"
else
  echo "    cargo not found — using the python fallback (scripts/life.py)"
  ln -sfn "$REPO/scripts/life.py" "$HOME/.local/bin/lifebg"
fi

echo "==> GTK dark theme + cursor (GTK apps; Qt follows qt6ct)"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  gsettings set org.gnome.desktop.interface cursor-theme "phinger-cursors-light"
  gsettings set org.gnome.desktop.interface cursor-size 24
fi

echo "==> Validating niri config"
niri validate

cat <<'EOF'

==> Done.
    - Log out and pick "Niri" at the login screen (Mod = Super).
    - The Game of Life wallpaper starts with niri. Preview in a terminal: `lifebg`
      Pause/resume: Mod+Shift+G · fresh soup: Mod+Ctrl+G · flags: `lifebg --help`
    - Lock: Mod+Alt+Escape (or 10 min idle); screens off at 15 min.
    - Float snap: Mod+Alt+arrows (or H/J/K/L) · dropdown terminal: Mod+Grave.
    - Volume/brightness keys flash a wob OSD bar · do-not-disturb: Mod+N.
    - Power menu: Mod+Shift+E · clipboard history: Mod+P · launcher: Mod+Space.
    - Restart kitty windows to pick up the transparency + font + olive palette
      (rice.conf now includes olive.conf).
    - Optional olive login screen (replaces your display manager — deliberate step):
        bash greeter-install.sh
EOF
