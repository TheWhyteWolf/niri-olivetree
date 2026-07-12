# niri-olivetree 🫒

A minimal, muted, olive-green rice for the [niri](https://yalter.github.io/niri/)
scrollable-tiling Wayland compositor — with a live **Conway's Game of Life
wallpaper**, an olive **tuigreet login screen**, and the whole desktop
(bar, launcher, notifications, lock screen, terminal, GTK/Qt apps) pulled onto
one quiet palette.

## Screenshots

![The desktop at rest — the Game of Life wallpaper under the waybar](assets/lifewall.png)
*At rest: Conway's Game of Life drifting across the moss-black background in
olive `#` glyphs, under the 26 px bar.*

![A working session — transparent terminals over the wallpaper](assets/terminal-view.png)
*At work: shell, file manager and [termusic](https://github.com/tramhao/termusic)
in kitty panes, with the colonies ghosting through the 7% transparency.*

## Palette

| Role | Hex | |
|---|---|---|
| Background | `#121412` | dark moss-black |
| Panel / surface | `#171a14` | |
| Border / inactive | `#39412b` | dim olive |
| Text | `#7b8c5a` | sage |
| Accent / focus | `#a4c94b` | bright lime-olive |
| Urgent | `#8a3b2e` | rust |

One accent, no gradients, no rounded corners, shadows off. The only thing that
moves is the wallpaper.

## What's in the box

| Piece | What it does |
|---|---|
| `niri/config.kdl` | Full ready-to-run config: olive borders, dimmed unfocused windows, crisp animations, sane binds |
| `lifewall/` | Conway's Game of Life as the wallpaper — a tiny Rust binary rendered through kitty's background panel at 30 fps, with fade-in births and dissolving deaths. Pause it (zero CPU) with `Mod+Shift+G`, reseed with `Mod+Ctrl+G`. Python fallback included if you don't have cargo. |
| `waybar/` | Thin 26 px bar: workspaces, window title, clock, volume, battery, CPU/MEM |
| `fuzzel/` | Launcher, clipboard history (`Mod+P`) and power menu (`Mod+Shift+E`), all matching |
| `mako/` | Olive notifications |
| `swaylock/` + swayidle | Olive lock screen; auto-lock at 10 min, screens off at 15, locks before sleep |
| `greetd/` + tuigreet | Matching console login screen (optional, separate installer) |
| `kitty/` | `rice.conf` (transparency + font, wired in automatically) and `olive.conf` (full opt-in colour theme) |
| `qt6ct/`, `xdg/`, GTK | Dark theme routing so Qt and GTK apps don't flashbang you |

Font: [Cousine Nerd Font](https://www.nerdfonts.com/) everywhere.
Cursor: [phinger-cursors](https://github.com/phisch/phinger-cursors) (light).

## Install

Arch-based distros (uses `yay`/`paru` if present for the one AUR package):

```sh
git clone https://github.com/TheWhyteWolf/niri-olivetree.git ~/niri-olivetree
bash ~/niri-olivetree/install.sh
```

The script installs packages, backs up any existing configs to `*.bak`,
symlinks these configs into `~/.config`, builds the wallpaper, sets the GTK
dark theme + cursor, and runs `niri validate`. Then log out and pick **Niri**
at the login screen.

On other distros: install the equivalents of the package list at the top of
`install.sh`, then run the script — the symlink/build steps are distro-agnostic
(package step will just fail past pacman; comment it out).

### The login screen (optional, deliberate)

Replaces your display manager with greetd + an olive-themed
[tuigreet](https://github.com/apognu/tuigreet):

```sh
bash ~/niri-olivetree/greeter-install.sh
```

It backs up any existing greetd config, remembers your last user/session, and
prints the exact rollback command for your old display manager when it's done.

## Keys worth knowing

| Bind | Action |
|---|---|
| `Mod+Space` / `Mod+Return` / `Mod+D` | Launcher (fuzzel) |
| `Mod+T` | Terminal (kitty) |
| `Mod+Grave` | Dropdown terminal (quake-style kitty in the top half) |
| `Mod+P` | Clipboard history |
| `Mod+Shift+E` | Power menu (lock / suspend / logout / reboot / poweroff) |
| `Mod+Alt+Escape` | Lock |
| `Mod+Alt+arrows` / `H/J/K/L` | Float snap: halves → quarters → max; back toward the middle restores |
| `Mod+Alt+C` / `Mod+Alt+R` | Center / un-snap floating window |
| `Mod+Shift+Ctrl+arrows` | Nudge floating window 40 px |
| `Mod+Shift+G` / `Mod+Ctrl+G` | Pause / reseed the Game of Life wallpaper |
| `Mod+O` | Overview |
| `Mod+Shift+/` | Full hotkey overlay |

Everything else follows niri's standard scheme — arrows/HJKL to focus,
`+Ctrl` to move, numbers for workspaces, `Print` to screenshot. It's all in
[`niri/config.kdl`](niri/config.kdl), which is commented for tweaking.

### Floating windows

`Mod+V` floats the focused window; then `Mod+Alt+arrows` (or `H/J/K/L`) snap it
Windows-style (`scripts/float-snap.sh`): a first press takes a half, a second
along the other axis refines to a corner quarter, `Mod+Alt+Up` from the top
half maximizes — always with a 12 px margin matching the gaps. Pressing back
toward the middle steps out and finally **restores the pre-snap geometry**;
tiled windows auto-float on the first snap and return to tiling on restore.
`Mod+Alt+C` centers, `Mod+Alt+R` un-snaps, `Mod+Shift+Ctrl+arrows` nudge, and
`Mod+drag` / `Mod+right-drag` move / resize with the mouse (niri built-in).
`Mod+Grave` toggles a quake-style dropdown kitty pinned to the top half
(`scripts/scratch-term.sh`). Firefox picture-in-picture docks bottom-right, and
pavucontrol / blueman / nm-connection-editor open floating at a sane size.
These need `jq` (in the package list).

## The wallpaper

[`lifewall`](lifewall/) is a ~400 KB dependency-free Rust binary that runs
Conway's Game of Life on a torus and interpolates every cell's colour each
frame. When the board settles into still lifes for ~20 s it crossfades into a
fresh random soup. It rides inside `kitten panel --edge=background`, so it
behaves like any other layer-shell wallpaper. Terminals are 7% transparent so
the life ghosts through them.

Tick rate, colours, density and glyph are all flags — see
[`lifewall/README.md`](lifewall/README.md), or preview it in any terminal by
just running `lifebg`.

## Uninstall

Configs are symlinks into this repo — delete the links (your originals are
next to them as `*.bak`) and remove the repo. The greeter rolls back with
`sudo systemctl disable greetd && sudo systemctl enable <your-old-dm>`.

## License

[MIT](LICENSE)
