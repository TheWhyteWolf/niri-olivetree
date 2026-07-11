#!/usr/bin/env python3
# Conway's Game of Life wallpaper — olive edition. Stdlib only.
# Runs inside `kitten panel --edge=background` (spawned from niri/config.kdl);
# also works in any terminal for previewing.
#
# Palette: dead #121412 · mature #66744c · newborn #87a540 (olive, muted ~20% toward bg)
# Births fade newborn->mature and deaths fade out to bg, each over FADE_STEPS frames.
# Half-block rendering: each character row holds two cell rows ("▀" fg=top, bg=bottom).

import shutil
import signal
import sys
import time
from collections import Counter, deque
from random import random

TICK = 0.3          # seconds per generation
SOUP = 0.14         # fill fraction when (re)seeding
STALE_HOLD = 20.0   # let a settled board oscillate this long before reseeding
MIN_POP_FRAC = 0.005  # reseed if the board nearly dies out
HASH_MEMORY = 600   # recent board states remembered for cycle detection

FADE_STEPS = 3      # frames for newborn->mature and dying->background fades

BG = (18, 20, 18)
MATURE = (102, 116, 76)
NEWBORN = (135, 165, 64)


def blend(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# Cell states: 0 dead · 1 mature · 2..4 birth fade (newborn->mature) ·
# 5..7 death fade (mature->bg).
FORCE_RESEED = False  # set by SIGUSR1 (Mod+Ctrl+G reset bind)

RGB = {0: BG, 1: MATURE}
for i in range(FADE_STEPS):
    RGB[2 + i] = blend(NEWBORN, MATURE, i / FADE_STEPS)
    RGB[5 + i] = blend(MATURE, BG, (i + 1) / (FADE_STEPS + 1))
PAIR = {
    (t, b): f"\x1b[38;2;{RGB[t][0]};{RGB[t][1]};{RGB[t][2]}m"
            f"\x1b[48;2;{RGB[b][0]};{RGB[b][1]};{RGB[b][2]}m"
    for t in RGB for b in RGB
}


def seed(w, h):
    # Seed as mature so a fresh board isn't a wall of bright newborns.
    return {(x, y): 1 for y in range(h) for x in range(w) if random() < SOUP}


def step(live, w, h):
    counts = Counter()
    for x, y in live:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    counts[(x + dx) % w, (y + dy) % h] += 1
    nxt = {}
    for cell, n in counts.items():
        if n == 3 or (n == 2 and cell in live):
            nxt[cell] = live[cell] + 1 if cell in live else 0
    return nxt


def state(live, dying, x, y):
    age = live.get((x, y))
    if age is not None:
        return 1 if age >= FADE_STEPS else 2 + age
    left = dying.get((x, y))
    if left:
        return 5 + (FADE_STEPS - left)
    return 0


def render(live, dying, w, h):
    parts = []
    for r in range(h // 2):
        parts.append(f"\x1b[{r + 1};1H")
        yt, yb = 2 * r, 2 * r + 1
        last = None
        row = []
        for x in range(w):
            tb = (state(live, dying, x, yt), state(live, dying, x, yb))
            if tb != last:
                row.append(PAIR[tb])
                last = tb
            row.append("▀")
        parts.append("".join(row))
    return "".join(parts)


def main():
    out = sys.stdout
    w = h = 0
    live, dying = {}, {}
    seen, order = set(), deque()
    stale_since = None

    def reseed():
        nonlocal live, stale_since
        live = seed(w, h)
        dying.clear()
        seen.clear()
        order.clear()
        stale_since = None

    out.write("\x1b[?25l\x1b[2J")
    while True:
        global FORCE_RESEED
        cols, rows = shutil.get_terminal_size()
        if (cols, rows * 2) != (w, h):
            w, h = cols, rows * 2
            reseed()
        if FORCE_RESEED:
            FORCE_RESEED = False
            reseed()
        out.write(render(live, dying, w, h))
        out.flush()
        time.sleep(TICK)
        nxt = step(live, w, h)
        dying = {c: n - 1 for c, n in dying.items() if n > 1 and c not in nxt}
        dying.update((c, FADE_STEPS) for c in live if c not in nxt)
        live = nxt

        if len(live) < MIN_POP_FRAC * w * h:
            reseed()
            continue
        # Cycle detection on cell positions (ages excluded — they never repeat).
        key = hash(frozenset(live))
        now = time.monotonic()
        if key in seen:
            if stale_since is None:
                stale_since = now
            elif now - stale_since >= STALE_HOLD:
                reseed()
        else:
            stale_since = None
            seen.add(key)
            order.append(key)
            if len(order) > HASH_MEMORY:
                seen.discard(order.popleft())


def _on_usr1(*_):
    global FORCE_RESEED
    FORCE_RESEED = True


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGUSR1, _on_usr1)
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        try:
            sys.stdout.write("\x1b[0m\x1b[?25h\x1b[2J\x1b[H")
            sys.stdout.flush()
        except BrokenPipeError:
            pass
