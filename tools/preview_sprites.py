#!/usr/bin/env python3
"""Planche de tous les sprites (frames de assets/sprites.txt) en PNG.

    python3 tools/preview_sprites.py [sortie.png] [--scale N]

Chaque frame est dessinée avec sa palette de sprites (pal_level1 de
src/game.s) sur un fond gris, avec son nom. Nécessite Pillow.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_assets as ba  # noqa: E402
from preview_level import NES_RGB  # noqa: E402

from PIL import Image, ImageDraw  # noqa: E402


def sprite_palettes():
    src = open(os.path.join(ba.ROOT, "src", "game.s"), encoding="utf-8").read()
    m = re.search(r"pal_level1:\s*\n((?:\s*\.byte[^\n]*\n){2})", src)
    vals = [int(v, 16) for v in re.findall(r"\$([0-9A-Fa-f]{2})", m.group(1))]
    return [[None] + [NES_RGB[vals[16 + p * 4 + i]] for i in (1, 2, 3)] for p in range(4)]


def frame_pixels(imgs, at):
    rows = []
    for part in at["src"].split("+"):
        rows += imgs[part]
    if "map" in at:
        for pair in at["map"].split(","):
            a, b = pair.split(":")
            rows = [r.replace(a, b) for r in rows]
    if at.get("rot") == "1":
        n = len(rows)
        rows = ["".join(rows[n - 1 - y][x] for y in range(n)) for x in range(len(rows[0]))]
    if at.get("mirror4") == "1":
        top = [r + r[::-1] for r in rows]
        rows = top + top[::-1]
    return [[ba.SPR_COLORS[c] for c in r] for r in rows]


def main():
    args = sys.argv[1:]
    out, scale = "build/sprites_preview.png", 4
    if "--scale" in args:
        i = args.index("--scale")
        scale = int(args[i + 1])
        del args[i:i + 2]
    if args:
        out = args[0]
    imgs, frames = ba.parse_sprites(ba.A("sprites.txt"))
    pals = sprite_palettes()
    cell_w, cell_h = 40, 56
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell_w * scale, rows * cell_h * scale), (110, 110, 120))
    draw = ImageDraw.Draw(img)
    for n, (name, at) in enumerate(frames):
        px = frame_pixels(imgs, at)
        pal = pals[int(at["pal"])]
        ox = (n % cols) * cell_w * scale + 4 * scale
        oy = (n // cols) * cell_h * scale + 4 * scale
        for y, row in enumerate(px):
            for x, c in enumerate(row):
                if c:
                    draw.rectangle([ox + x * scale, oy + y * scale,
                                    ox + (x + 1) * scale - 1, oy + (y + 1) * scale - 1], fill=pal[c])
        draw.text((ox, oy + 46 * scale), name, fill=(255, 255, 255))
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    img.save(out)
    print("aperçu : %s" % out)


if __name__ == "__main__":
    main()
