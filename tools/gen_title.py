#!/usr/bin/env python3
"""Génère assets/title.txt : l'image de fond de l'écran titre.

    python3 tools/gen_title.py [assets/title.txt]

Le fichier produit est la vraie source (lue par build_assets.py) : une carte
des palettes par case de 16x16 et une image de 256x240 pixels en indices de
couleur 0-3. On peut le retoucher à la main ; relancer ce script écrase les
retouches. Les textes (menu, copyright...) sont écrits par le code par-dessus.

Palettes du titre (pal_title dans src/game.s) :
  0 : noir, blanc, noir, gris       -> textes, étoiles
  1 : noir, violet, orange, jaune   -> ciel, soleil, plage
  2 : noir, bleu nuit, bleu clair, blanc -> lettres chromées, mer
  3 : noir, jaune, noir, rouge néon -> « III », MAXIMUM JUSTICE
"""
import math
import random
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/title.txt"
W, H = 256, 240
img = [[0] * W for _ in range(H)]
attr = [[0] * 16 for _ in range(15)]
B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y, t):
    return B4[y % 4][x % 4] < t * 16


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = c


def mask(rows):
    return [[ch == "#" for ch in r] for r in rows]


# ------------------------------------------------------------ lettres
F12 = {
    "U": ["###......###"] * 10 + ["####....####", ".##########.", "..########..", "...######..."],
    "L": ["###........."] * 11 + ["############"] * 3,
    "T": ["############"] * 3 + ["....####...."] * 11,
    "R": ["#########...", "##########..", "###.....###.", "###.....###.", "###.....###.", "##########..",
          "#########...", "###...###...", "###....###..", "###.....###.", "###.....###.", "###......###",
          "###......###", "###......###"],
    "A": ["....####....", "...######...", "..###..###..", "..###..###..", ".###....###.", ".###....###.",
          "###......###", "############", "############", "###......###", "###......###", "###......###",
          "###......###", "###......###"],
    "D": ["#########...", "##########..", "###....####.", "###.....###.", "###......###", "###......###",
          "###......###", "###......###", "###......###", "###......###", "###.....###.", "###....####.",
          "##########..", "#########..."],
    "E": ["############"] * 2 + ["###........."] * 3 + ["#########..."] * 2 + ["###........."] * 4 +
         ["############"] * 3,
    "H": ["###......###"] * 5 + ["############"] * 2 + ["###......###"] * 7,
    "C": ["..########..", ".##########.", "####....####", "###......###", "###.........", "###.........",
          "###.........", "###.........", "###.........", "###.........", "###......###", "####....####",
          ".##########.", "..########.."],
    "O": ["..########..", ".##########.", "####....####"] + ["###......###"] * 8 +
         ["####....####", ".##########.", "..########.."],
    "P": ["#########...", "##########..", "###....####.", "###.....###.", "###.....###.", "###....####.",
          "##########..", "#########..."] + ["###........."] * 6,
}


def chrome(f):
    """Dégradé chromé selon la hauteur relative f (0 = haut)."""
    if f < 0.13:
        return 3
    if f < 0.46:
        return 2
    if f < 0.53:
        return 3
    if f < 0.80:
        return 1
    if f < 0.93:
        return 2
    return 3


def draw_chrome(ch, x0, y0, scale=1):
    m = mask(F12[ch])
    h = len(m) * scale
    # ombre portée bleu nuit (1 px en bas à droite)
    for y, row in enumerate(m):
        for x, on in enumerate(row):
            if on:
                for sy in range(scale):
                    for sx in range(scale):
                        put(x0 + x * scale + sx + 1, y0 + y * scale + sy + 1, 1)
    for y, row in enumerate(m):
        for x, on in enumerate(row):
            if on:
                for sy in range(scale):
                    for sx in range(scale):
                        yy = y * scale + sy
                        put(x0 + x * scale + sx, y0 + yy, chrome(yy / h))
    return len(m[0]) * scale


def draw_word(word, x0, y0, gap, scale=1):
    x = x0
    for ch in word:
        if ch == " ":
            x += 8 * scale
            continue
        x += draw_chrome(ch, x, y0, scale) + gap
    return x


def word_width(word, gap, scale=1):
    w = 0
    for ch in word:
        w += 8 * scale if ch == " " else 12 * scale + gap
    return w - gap


# « ULTRA DEATH » : rangée de cases 1 (y 16-31)
w = word_width("ULTRA DEATH", 2)
draw_word("ULTRA DEATH", (W - w) // 2, 17, 2)
for x in range(16):
    attr[1][x] = 2

# « COP » en grand (x2) et « III » au néon : rangées 2-3 (y 32-63)
COP_W = word_width("COP", 4, 2)
III_W = 3 * 12 + 2 * 3
total = COP_W + 12 + III_W
x0 = (W - total) // 2
draw_word("COP", x0, 34, 4, 2)
assert x0 + COP_W < 144, "COP doit finir avant la colonne 9 (palette 2)"
ix = max(x0 + COP_W + 12, 148)
for k in range(3):
    bx = ix + k * 14
    for y in range(34, 62):
        serif = y < 38 or y >= 58
        xa, xb = (bx, bx + 12) if serif else (bx + 2, bx + 10)
        for x in range(xa, xb):
            edge = x < xa + 2 or x >= xb - 2 or y < 36 or y >= 60
            put(x, y, 3 if edge else 1)
        # reflet blanc-jaune au centre du tube
for y in range(2, 4):
    for x in range(16):
        attr[y][x] = 3 if x >= 9 else 2

# « MAXIMUM JUSTICE » : la police (assets/font.txt) dessinée dans l'image,
# palette 3 (jaune), rangée de tuiles 8
for x in range(16):
    attr[4][x] = 3


def font_glyphs():
    lines = [l.rstrip("\n") for l in open("assets/font.txt", encoding="utf-8")
             if not (l.startswith("# ") or l.rstrip("\n") == "#")]
    g, i = {}, 0
    while i < len(lines):
        if lines[i].startswith("= "):
            for k, ch in enumerate(lines[i][2:].split(" ")):
                g[ch] = [lines[i + 1 + y][k * 6:k * 6 + 5] for y in range(7)]
            i += 8
        else:
            i += 1
    return g


GLYPHS = font_glyphs()
text = "MAXIMUM JUSTICE"
tx0 = (32 - len(text)) // 2
for k, ch in enumerate(text):
    if ch == " ":
        continue
    for y in range(7):
        for x in range(5):
            if GLYPHS[ch][y][x] == "#":
                put((tx0 + k) * 8 + 1 + x, 64 + y, 1)

# ------------------------------------------------------------ paysage
SKY0, HORIZON, SEA_END, BEACH_END = 80, 128, 144, 160
for y in range(5, 8):
    for x in range(16):
        attr[y][x] = 1
for x in range(16):
    attr[8][x] = 2
    attr[9][x] = 1

# ciel : noir -> violet (tramé)
for y in range(SKY0, HORIZON):
    t = (y - SKY0 - 4) / 16
    for x in range(W):
        put(x, y, 1 if dith(x, y, max(0, min(1, t))) else 0)

# soleil rayé
CX, CY, R = 128, 109, 25
GAPS = set()
yy = 104
for k, th in enumerate((1, 1, 2, 2, 3, 3)):
    for d in range(th):
        GAPS.add(yy + d)
    yy += th + 3 - k // 3
for y in range(CY - R, HORIZON):
    for x in range(CX - R, CX + R + 1):
        if math.hypot(x - CX, y - CY) <= R and y not in GAPS:
            f = (y - (CY - R)) / (HORIZON - (CY - R))
            put(x, y, 3 if f < 0.45 or (f < 0.62 and dith(x, y, 0.5)) else 2)

# immeubles en ombres chinoises, fenêtres jaunes
rnd = random.Random(3)
BLD = []  # motif de 64 px, répété (les tuiles se répètent aussi)
x = 0
while x < 64:
    bw = min(rnd.randrange(8, 18), 64 - x)
    BLD.append((x, bw, rnd.randrange(6, 17), rnd.random() < 0.3,
                [(wx, wy) for wy in range(2, 16, 3) for wx in range(2, bw - 1, 3) if rnd.random() < 0.35]))
    x += bw + 1
for rep_x in range(0, W, 64):
    for bx, bw, bh, ant, wins in BLD:
        x = rep_x + bx
        if abs(x + bw / 2 - CX) < 30:
            bh = min(bh, 7)  # plus bas devant le soleil
        top = HORIZON - bh
        for xx in range(x, x + bw):
            for y in range(top, HORIZON):
                put(xx, y, 0)
        if ant:
            for y in range(top - 4, top):
                put(x + bw // 2, y, 0)
        for wx, wy in wins:
            if top + wy < HORIZON - 1:
                put(x + wx, top + wy, 3)

# mer : bleu nuit, vagues bleu clair, reflet blanc sous le soleil
rnd = random.Random(5)
for y in range(HORIZON, SEA_END):
    for x in range(W):
        put(x, y, 1)
for y in range(HORIZON, SEA_END):
    ly = y - HORIZON
    if ly == 0:
        for x in range(W):
            put(x, y, 2)
        continue
    if ly % 2 == 0:
        dash = [(rnd.randrange(32), 2 + ly // 3) for _ in range(1 + ly // 5)]
        for rep_x in range(0, W, 32):
            for dx, ln in dash:
                for k in range(ln):
                    put(rep_x + (dx + k) % 32, y, 2)
    half = 22 - ly
    for x in range(CX - half, CX + half):
        if ly % 2 == 1 and rnd.random() < 0.7:
            put(x, y, 3)

# plage
for y in range(SEA_END, BEACH_END):
    ly = y - SEA_END
    for x in range(W):
        if ly == 0:
            c = 3 if x % 8 not in (3, 7) else 2
        elif ly < 3:
            c = 3 if dith(x, y, 0.5) else 2
        else:
            c = 3 if dith(x, y, 0.75) else 2
        put(x, y, c)


# palmiers en ombres chinoises (noir), un de chaque côté
def palm(bx, lean):
    """Silhouette noire : tronc courbé, palmes épaisses aux folioles pendantes."""
    top_y = 92
    pts = []
    for y in range(BEACH_END - 1, top_y, -1):
        t = (BEACH_END - y) / (BEACH_END - top_y)
        x = bx + lean * 18 * t * t
        pts.append((x, y))
        w = 4 if t < 0.25 else 3
        for k in range(w):
            put(round(x) - w // 2 + k, y, 0)
    cx, cy = pts[-1]
    cx, cy = round(cx), round(cy)
    fronds = [(-34, 16), (-26, 2), (-12, -8), (10, -9), (26, 1), (34, 15), (18, 20), (-18, 20)]
    for fx, fy in fronds:
        prev = None
        for i in range(61):
            t = i / 60
            x = cx + fx * t
            y = cy + fy * t - 9 * math.sin(math.pi * t) + 7 * t * t
            X, Y = round(x), round(y)
            th = 2 if t < 0.7 else 1
            for k in range(th + 1):
                put(X, Y + k, 0)
            # folioles : pendent vers le bas, plus courtes vers la pointe
            if i % 2 == 0 and 0.12 < t < 0.97:
                ln = int(6 * (1 - t) + 2)
                for k in range(1, ln):
                    put(X - (1 if fx > 0 else -1) * (k // 3), Y + th + k, 0)
    for dx in range(-3, 4):
        for dy in range(-1, 4):
            if abs(dx) + abs(dy) < 4:
                put(cx + dx, cy + dy, 0)


palm(20, 1)
palm(236, -1)

# ------------------------------------------------------------ étoiles
rnd = random.Random(11)
stars = 0
while stars < 16:
    x, y = rnd.randrange(8, W - 8), rnd.randrange(2, 92)
    if 60 <= y < 76 or (12 <= y < 66 and 36 < x < 220):
        continue
    if any(img[yy][xx] for yy in range(y - 2, y + 3) for xx in range(x - 2, x + 3)):
        continue
    pal = attr[y // 16][x // 16]
    star = {0: 1, 1: 3, 2: 3, 3: 1}[pal]
    if pal == 1 and y >= 88:
        continue
    put(x, y, star)
    if stars % 5 == 0:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(x + dx, y + dy, {0: 3, 1: 1, 2: 2, 3: 3}[pal] if pal else 3)
    stars += 1

lines = ["# Écran titre : généré par tools/gen_title.py (le relancer écrase les retouches).",
         "#",
         "# @attr : palette (0-3) de chaque case de 16x16, 15 rangées de 16.",
         "# @image : 240 lignes de 256 pixels, indice de couleur dans la palette",
         "#     de la case ('.' = 0, couleur de fond). Palettes : pal_title (src/game.s).",
         "# Les textes du menu sont écrits par le code par-dessus (src/screens.s) :",
         "# laisser vides les rangées de texte (tuiles 20-29). La rangée de tuiles 20",
         "# doit rester noire : c'est là que l'IRQ remet la police (haut de l'écran :",
         "# banques du titre, 256 tuiles ; bas : police).",
         "",
         "@attr"]
lines += ["".join(str(v) for v in row) for row in attr]
lines += ["", "@image"]
lines += ["".join(".123"[c] for c in row) for row in img]
open(OUT, "w").write("\n".join(lines) + "\n")
print("écrit :", OUT)
