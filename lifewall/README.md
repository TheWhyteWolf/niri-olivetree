# lifewall

Conway's Game of Life as a smooth terminal wallpaper. The simulation ticks at
a relaxed pace while rendering interpolates every cell's colour at 30 fps:
births fade in, the newborn flash melts into the mature tone, deaths dissolve
back into the background. Cells are drawn as `#` glyphs (configurable).

A single ~400 KB binary; the only dependency is `libc`.

## Build

```sh
cargo build --release        # -> target/release/lifewall
```

## Run

As a wallpaper it rides inside [kitty](https://sw.kovidgoyal.net/kitty/)'s
panel kitten on the desktop background layer:

```sh
kitten panel --edge=background --config NONE -o font_size=8 \
  -o background='#121412' lifewall
```

Smaller `font_size` = finer cells. This needs kitty ≥ 0.42 and either a
Wayland compositor with layer-shell support (niri, sway, Hyprland, river, …)
or macOS. It also runs in any plain terminal — nice for previewing.

## Flags

```
--tick SECS     seconds per generation        (default 0.3)
--fps N         render frames per second      (default 30)
--fade GENS     fade length in generations    (default 3)
--density F     seed fill fraction 0..1       (default 0.14)
--char C        glyph for live cells          (default '#')
--bg HEX        background colour             (default #121412)
--mature HEX    settled cell colour           (default #66744c)
--newborn HEX   birth flash colour            (default #87a540)
```

The board is a torus (gliders wrap). When the board settles into still lifes
and oscillators for ~20 s, or nearly dies out, it crossfades into a fresh soup.

## Sharing / binaries

Rust binaries are per-OS and per-architecture: build once per target
(`x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`, `aarch64-apple-darwin`, …)
and hand that file out, or just share this directory — anyone with rust runs
`cargo build --release`. For a maximally portable Linux binary build against
musl: `cargo build --release --target x86_64-unknown-linux-musl`.
