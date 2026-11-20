#!/usr/bin/env python3
"""Aperçu du niveau 1 en PNG, sans émulateur.

    python3 tools/preview_level.py [sortie.png] [--scale N] [--screens A-B]

Lit assets/bg_beach.txt, assets/level1.txt et la palette pal_level1 de
src/game.s, puis dessine tout le terrain (sans HUD ni sprites) avec les
couleurs NES. Nécessite Pillow (python3-pil).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_assets as ba  # noqa: E402

from PIL import Image  # noqa: E402

# Palette NTSC de jsnes (format 0xRRGGBB après conversion)
_BGR = [0x525252, 0xB40000, 0xA00000, 0xB1003D, 0x740069, 0x00005B, 0x00005F, 0x001840,
        0x002F10, 0x084A08, 0x006700, 0x124200, 0x6D2800, 0x000000, 0x000000, 0x000000,
        0xC4D5E7, 0xFF4000, 0xDC0E22, 0xFF476B, 0xD7009F, 0x680AD7, 0x0019BC, 0x0054B1,
        0x006A5B, 0x008C03, 0x00AB00, 0x2C8800, 0xA47200, 0x000000, 0x000000, 0x000000,
        0xF8F8F8, 0xFFAB3C, 0xFF7981, 0xFF5BC5, 0xFF48F2, 0xDF49FF, 0x476DFF, 0x00B4F7,
        0x00E0FF, 0x00E375, 0x03F42B, 0x78B82E, 0xE5E218, 0x787878, 0x000000, 0x000000,
        0xFFFFFF, 0xFFF2BE, 0xF8B8B8, 0xF8B8D8, 0xFFB6FF, 0xFFC3FF, 0xC7D1FF, 0x9ADAFF,
        0x88EDF8, 0x83FFDD, 0xB8F8B8, 0xF5F8AC, 0xFFFFB0, 0xF8D8F8, 0x000000, 0x000000]
NES_RGB = [((c & 0xFF), (c >> 8) & 0xFF, (c >> 16) & 0xFF) for c in _BGR]


def level_palette():
    src = open(os.path.join(ba.ROOT, "src", "game.s"), encoding="utf-8").read()
    m = re.search(r"pal_level1:\s*\n((?:\s*\.byte[^\n]*\n){2})", src)
    vals = [int(v, 16) for v in re.findall(r"\$([0-9A-Fa-f]{2})", m.group(1))]
    return [[NES_RGB[vals[p * 4 + i]] for i in range(4)] for p in range(4)]


def main():
    args = sys.argv[1:]
    out = "build/level1_preview.png"
    scale, screens = 1, None
    i = 0
    while i < len(args):
        if args[i] == "--scale":
            scale = int(args[i + 1])
            i += 2
        elif args[i] == "--screens":
            a, b = args[i + 1].split("-")
            screens = (int(a) - 1, int(b))
            i += 2
        else:
            out = args[i]
            i += 1
    metas = ba.parse_bg(ba.A("bg_beach.txt"))
    byname = {m[0]: m for m in metas}
    width, grid, spawns = ba.parse_level(ba.A("level1.txt"), byname)
    pal = level_palette()
    x0, x1 = 0, width
    if screens:
        x0, x1 = screens[0] * 16, min(width, screens[1] * 16)
    img = Image.new("RGB", ((x1 - x0) * 16, 13 * 16 + 32), pal[0][2])
    px = img.load()
    for y in range(13):
        for x in range(x0, x1):
            name, p, coll, stain, pix, hi = byname[grid[y][x]]
            for yy in range(16):
                for xx in range(16):
                    px[(x - x0) * 16 + xx, 32 + y * 16 + yy] = pal[p][pix[yy][xx]]
    # marqueurs des ennemis (petits carrés blancs)
    for col, row, kind in spawns:
        if x0 <= col < x1:
            for yy in range(4):
                for xx in range(4):
                    px[(col - x0) * 16 + 6 + xx, 32 + row * 16 + 12 + yy] = (255, 255, 255)
    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    img.save(out)
    print("aperçu : %s (%dx%d)" % (out, img.width, img.height))


if __name__ == "__main__":
    main()
