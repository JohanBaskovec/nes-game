#!/usr/bin/env python3
"""Génère assets/bg_beach.txt (décor de Vice Beach).

    python3 tools/gen_bg_beach.py [assets/bg_beach.txt]

Le fichier produit est la vraie source du décor (lue par build_assets.py) :
on peut le retoucher à la main, mais relancer ce script écrase les retouches.
Le script sert surtout pour ce qui est fastidieux à la main : dégradés tramés
du ciel, ligne d'horizon, soleil rayé, palmes.

Les métatuiles sont assemblées à partir d'un petit jeu de tuiles 8x8
réutilisées (sable, mer, ciel), pour tenir dans les 256 tuiles du décor."""
import math
import random
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/bg_beach.txt"

B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y, t):
    return B4[y % 4][x % 4] < t * 16


out = []


def emit_meta(name, pal, rows, coll=0, extra=""):
    rows = ["".join(r) for r in rows]
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), (name, [len(r) for r in rows])
    out.append("@meta %s pal=%d coll=%d%s" % (name, pal, coll, extra))
    out.extend(rows)
    out.append("")


def emit_big(name, pal, cv, coll=0, extra=""):
    h, w = len(cv), len(cv[0])
    assert w % 16 == 0 and h % 16 == 0, name
    for my in range(h // 16):
        for mx in range(w // 16):
            rows = [cv[my * 16 + y][mx * 16:mx * 16 + 16] for y in range(16)]
            emit_meta("%s_%d_%d" % (name, mx, my), pal, rows, coll, extra)


def comment(t, *lines):
    out.append("# " + "-" * (70 - len(t)) + " " + t)
    for l in lines:
        out.append("# " + l)
    out.append("")


def T(rows):
    rows = [list(r) for r in rows]
    assert len(rows) == 8 and all(len(r) == 8 for r in rows)
    return rows


def quad(tl, tr, bl, br):
    return [tl[y] + tr[y] for y in range(8)] + [bl[y] + br[y] for y in range(8)]


def grid(tiles, tw, th):
    """tiles[ty][tx] -> canevas (liste de listes de caractères)."""
    cv = []
    for ty in range(th):
        for y in range(8):
            row = []
            for tx in range(tw):
                row += tiles[ty][tx][y]
            cv.append(row)
    return cv


def blit(cv, art, ox, oy, transparent="_"):
    for y, row in enumerate(art):
        for x, c in enumerate(row):
            if c != transparent and 0 <= oy + y < len(cv) and 0 <= ox + x < len(cv[0]):
                cv[oy + y][ox + x] = c


def fill_tile(fn):
    return [[fn(x, y) for x in range(8)] for y in range(8)]


# =================================================================== CIEL
# palette 1 : '.' rose (fond universel), p violet, o orange, y jaune pâle
# sy = 0..79 : rangées de terrain 0 à 4 (y écran 32..111)
def sky(x, sy):
    if sy < 10:
        return "p"
    if sy < 26:
        return "." if dith(x, sy, (sy - 9) / 17) else "p"
    if sy < 40:
        return "."
    if sy < 56:
        return "o" if dith(x, sy, (sy - 39) / 17) else "."
    if sy < 66:
        return "o"
    return "y" if dith(x, sy, (sy - 65) / 15) else "o"


SKYT = [fill_tile(lambda x, y, ty=ty: sky(x, ty * 8 + y)) for ty in range(10)]


def sky_meta(row, a=None, b=None, c=None, d=None):
    t0, t1 = SKYT[row * 2], SKYT[row * 2 + 1]
    return quad(a or t0, b or t0, c or t1, d or t1)


def with_px(tile, pts):
    t = [r[:] for r in tile]
    for x, y, c in pts:
        t[y][x] = c
    return t


comment("ciel", "Dégradé tramé (Bayer 4x4) : violet -> rose -> orange -> jaune à l'horizon.",
        "Toutes les tuiles d'une même hauteur sont identiques : le ciel ne coûte",
        "presque rien ; étoiles et nuages sont des tuiles isolées.")
STAR1 = with_px(SKYT[0], [(2, 3, "y"), (6, 1, "o"), (5, 6, "y")])
STAR2 = with_px(SKYT[1], [(4, 2, "o"), (3, 2, "y"), (5, 2, "y"), (4, 1, "y"), (4, 3, "y")])
emit_meta("sky0", 1, sky_meta(0))
emit_meta("sky0s1", 1, sky_meta(0, a=STAR1))
emit_meta("sky0s2", 1, sky_meta(0, d=STAR2))
emit_meta("sky1", 1, sky_meta(1))
WISP = with_px(SKYT[2], [(x, 3, ".") for x in range(1, 8)] + [(x, 4, "o") for x in range(3, 7)])
emit_meta("sky1c", 1, sky_meta(1, b=WISP))


def cloud_tiles(n, y0):
    """Nuage étiré de n tuiles (violet dessus, liseré orange dessous)."""
    cv = [r[:] for r in grid([[SKYT[4]] * n], n, 1)]
    w = n * 8
    for x in range(1, w - 1):
        cv[y0][x] = "p"
    for x in range(2, w - 3):
        cv[y0 + 1][x] = "p"
    for x in range(3, w - 4):
        cv[y0 + 2][x] = "o"
    for x in range(w // 3, w - 2):
        cv[y0 - 1][x] = "p"
    return [[row[k * 8:(k + 1) * 8] for row in cv] for k in range(n)]


CL = cloud_tiles(2, 3)
CS = cloud_tiles(1, 4)
emit_meta("sky2", 1, sky_meta(2))
emit_meta("sky2c1", 1, sky_meta(2, a=CL[0], b=CL[1]))
emit_meta("sky2c2", 1, sky_meta(2, b=CS[0]))
emit_meta("sky3", 1, sky_meta(3))

# ligne d'horizon : silhouettes de Vice Beach (violet), période 64 px
SKY_W = 64
BUILDINGS = [  # x, largeur, hauteur, style
    (0, 7, 6, "win"), (7, 5, 10, "ant"), (12, 9, 8, "win"), (22, 4, 14, "spire"),
    (26, 9, 9, "step"), (40, 11, 11, "hotel"), (51, 6, 15, "tower"), (57, 7, 6, "win"),
]
PALMS_FAR = [36]


def skyline_mask():
    m = {}
    rnd = random.Random(7)
    for bx, bw, bh, st in BUILDINGS:
        top = 16 - bh
        for x in range(bx, bx + bw):
            for ly in range(top, 16):
                m[(x % SKY_W, ly)] = "p"
        if st == "ant":
            for ly in range(top - 4, top):
                m[((bx + bw // 2) % SKY_W, ly)] = "p"
        if st == "spire":
            for ly in range(top - 3, top):
                m[((bx + 1) % SKY_W, ly)] = "p"
            m[((bx + 2) % SKY_W, top - 1)] = "p"
        if st in ("step", "hotel", "tower"):
            for x in range(bx + 2, bx + bw - 2):
                m[(x % SKY_W, top - 1)] = "p"
        if st == "step":
            for x in range(bx + 3, bx + bw - 3):
                m[(x % SKY_W, top - 2)] = "p"
        if st == "hotel":
            for ly in range(top - 4, top - 1):
                m[((bx + bw // 2) % SKY_W, ly)] = "p"
        if st in ("win", "hotel", "tower", "step"):
            for wy in range(top + 2, 15, 3):
                for wx in range(bx + 2, bx + bw - 1, 2):
                    if rnd.random() < 0.4:
                        m[(wx % SKY_W, wy)] = "y"
    for px in PALMS_FAR:
        for p in [(px, 15), (px, 14), (px, 13), (px + 1, 12), (px + 1, 11), (px + 1, 10), (px + 2, 9), (px + 2, 8)]:
            m[p] = "p"
        cx, cy = px + 2, 7
        for dx, dy in ((-1, 0), (-2, 0), (-3, 1), (-4, 2), (1, 0), (2, 0), (3, 1), (4, 2),
                       (-1, -1), (-2, -2), (0, -1), (1, -1), (2, -2), (3, -2), (0, 0)):
            m[(cx + dx, cy + dy)] = "p"
    return m


SKYLINE = skyline_mask()


def horizon(x, ly):
    return SKYLINE.get((x % SKY_W, ly), sky(x, 64 + ly))


cv = [[horizon(x, ly) for x in range(SKY_W)] for ly in range(16)]
emit_big("skyline", 1, cv, extra="")

# ---------------------------------------------------------------- soleil
comment("soleil", "Soleil rayé (rangées 2 à 4, colonnes 4 à 6 de l'écran 1). Les rayures",
        "laissent voir le ciel, la ligne d'horizon passe devant.")
SUN_X0 = 64  # position monde (colonne 4) : la ligne d'horizon raccorde
cv = [[None] * 48 for _ in range(48)]
GAPS = {27, 31, 32, 36, 37, 38, 42, 43, 44, 45}
for y in range(48):
    for x in range(48):
        wx = SUN_X0 + x
        d = math.hypot(x - 23.5, y - 30.5)
        inside = d < 21 and y not in GAPS
        if inside:
            c = "o" if (y + 1) in GAPS or (d > 19.6 and y < 24) else "y"
        else:
            c = sky(wx, 32 + y)
        cv[y][x] = c
for y in range(32, 48):
    for x in range(48):
        c = SKYLINE.get(((SUN_X0 + x) % SKY_W, y - 32))
        if c:
            cv[y][x] = c
emit_big("sun", 1, cv, extra="")

# ===================================================================== MER
comment("mer", "Palette 2 : '.' rose, d bleu nuit, l bleu clair, g vert.",
        "Rangée 5 : horizon ; rangée 6 : vagues et écume (rose et bleue) sur la plage.")


def dashes(seed, rows, w=8):
    """Tuile de mer : rows = {y: (nombre, longueur)} tirets bleu clair."""
    rnd = random.Random(seed)
    t = [["d"] * w for _ in range(8)]
    for y, (n, ln) in rows.items():
        for _ in range(n):
            x = rnd.randrange(w)
            for k in range(ln):
                t[y][(x + k) % w] = "l"
    return t


SEA_A = dashes(1, {0: (8, 1), 1: (2, 3), 3: (1, 2), 5: (1, 3), 7: (1, 2)})
SEA_B = dashes(2, {0: (8, 1), 1: (2, 2), 3: (1, 3), 6: (1, 2)})
for t in (SEA_A, SEA_B):
    t[0] = ["l"] * 8
    t[1] = ["l" if dith(x, 1, 0.5) else "d" for x in range(8)]
SEA_C = dashes(3, {1: (1, 3), 4: (1, 4), 7: (1, 3)})
SEA_D = dashes(4, {2: (1, 4), 5: (1, 3)})
SEA_E = dashes(5, {1: (1, 5), 5: (1, 4)})
SEA_F = dashes(6, {2: (1, 3), 6: (1, 5)})


def foam_tile(k):
    t = [["d"] * 8 for _ in range(8)]
    for x in range(8):
        X = x + k * 8
        edge = 3 + round(1.4 * math.sin(X / 16 * 2 * math.pi) + 0.7 * math.sin(X / 16 * 6 * math.pi))
        for y in range(8):
            if y == edge - 1:
                t[y][x] = "l" if X % 3 else "d"
            elif y == edge:
                t[y][x] = "l"
            elif y > edge:
                t[y][x] = "." if ((X * 7 + y * 3) % 5) < 3 else "l"
    return t


FOAM = [foam_tile(0), foam_tile(1)]
emit_meta("seatop", 2, quad(SEA_A, SEA_B, SEA_C, SEA_D), extra="")
emit_meta("seatop2", 2, quad(SEA_B, SEA_A, SEA_D, SEA_C), extra="")
emit_meta("sea", 2, quad(SEA_E, SEA_F, FOAM[0], FOAM[1]))
emit_meta("sea2", 2, quad(SEA_F, SEA_E, FOAM[0], FOAM[1]))

# reflet du soleil (rangée 5, colonnes 4 à 6)
cv = grid([[SEA_A, SEA_B] * 3, [SEA_C, SEA_D] * 3], 6, 2)
for ly in range(3, 16, 2):
    half = max(3, 14 - ly)
    rnd = random.Random(ly)
    for x in range(24 - half, 24 + half):
        if rnd.random() < 0.7:
            cv[ly][x] = "."
emit_big("refl", 2, cv)

# mer du large (port) et eau des fosses
OPEN_A = dashes(7, {0: (1, 3), 3: (1, 4), 6: (1, 2)})
OPEN_B = dashes(8, {1: (1, 4), 4: (1, 2), 7: (1, 3)})
emit_meta("opensea", 2, quad(OPEN_A, OPEN_B, OPEN_B, OPEN_A))
emit_meta("opensea2", 2, quad(OPEN_B, OPEN_A, OPEN_A, OPEN_B))
CREST = [T(["........", ".l..ll.l", "llll..ll", "dddlllld", "dddddddd", "ddlldddd", "dddddddd", "dddddlll"]),
         T(["........", "...ll..l", "ll.l..ll", "lldddlll", "dddddddd", "dddddlld", "dddddddd", "llldddd."])]
emit_meta("watertop", 2, quad(CREST[0], CREST[1], OPEN_A, OPEN_B), coll=3)
emit_meta("water", 2, quad(OPEN_B, OPEN_A, OPEN_A, OPEN_B), coll=3)

# ================================================================== SABLE
# palette 3 : '.' rose, s sable, b brun, r sang (jamais dans le décor)
comment("sable", "Palette 3 : '.' rose, s sable, b brun ; 'r' est le sang, interdit ici.",
        "Deux tuiles de sable de base, et des détails tenant dans une seule tuile.")
S1 = T(["ssssssss", "ssssssss", "sssssbss", "ssssssss", "sbssssss", "ssssssss", "ssssssss", "ssssssss"])
S2 = T(["ssssssss", "ssssssss", "ssssssss", "ssssssbs", "ssssssss", "ssssssss", "ssbsssss", "ssssssss"])
SHELL = T(["ssssssss", "ssbbbsss", "sb..sbss", "sb.b.bss", "ssb..bss", "sssbbsss", "ssssssss", "sbssssss"])
STARF = T(["ssss.sss", "ssss.sss", "s.......", "ss..b..s", "sss.s.ss", "ss.sss.s", "ssssssss", "ssssssss"])
CRAB = T(["ssssssss", "sbsbsbsb", "s.bsss.b", "ss.....s", "sb.b.b.b", "ssbsbsbs", "ssssssss", "ssssssss"])
STEPS = T(["sbbsssss", "bbbbssss", "bbbbssss", "sbbsssss", "sssssbbs", "ssssbbbb", "ssssbbbb", "sssssbbs"])
emit_meta("sand", 3, quad(S1, S2, S2, S1))
emit_meta("sand2", 3, quad(S2, S1, S1, S2))
emit_meta("shell", 3, quad(S1, S2, SHELL, S1))
emit_meta("starfish", 3, quad(S2, STARF, S1, S2))
emit_meta("crab", 3, quad(S1, S2, S2, CRAB))
emit_meta("steps", 3, quad(STEPS, S2, S1, S2))
WET1 = T([".s..ss.s", "bsbs.sbs", "sbsbsbsb", "bsbsssbs", "ssbsbsss", "sbssssbs", "ssssbsss", "ssssssss"])
WET2 = T(["s.ss..s.", "sbsbsb.b", "bsbsbsbs", "sbsbsbss", "sssbssbs", "bsssbsss", "ssssssbs", "ssssssss"])
emit_meta("shore1", 3, quad(WET1, WET2, S1, S2))
emit_meta("shore2", 3, quad(WET2, WET1, S2, S1))

# ------------------------------------------------------------------ sol
comment("sol", "Le sol où l'on marche (rangée 11) et le sable tassé dessous (rangée 12).",
        "Une seule tuile pour le dessus : elle reçoit les taches de sang (stain=top).")
GTOP = T(["bbbbbbbb", "sbssbsbs", "ssssssss", "ssbsssss", "ssssssbs", "ssssssss", "sbssssss", "ssssssss"])
PEBB = T(["ssssssss", "ssssssss", "ssbbssss", "sbssbsss", "ssbbsbbs", "ssssbssb", "sssssbbs", "ssssssss"])
emit_meta("ground", 3, quad(GTOP, GTOP, S1, S2), coll=1, extra=" stain=top")
emit_meta("groundb", 3, quad(GTOP, GTOP, PEBB, S1), coll=1, extra=" stain=top")
K1 = T(["ssbsssss", "ssssssbs", "sbssssss", "sssssbss", "ssssssss", "bssbssss", "ssssssbs", "ssssssss"])
K2 = T(["ssssssbs", "sbssssss", "sssssbss", "ssssssss", "ssbsssbs", "ssssssss", "bsssssss", "sssbssss"])
K3 = [r[:] for r in K1]
blit(K3, ["_bb_", "b..b", "_bb_"], 2, 2)
emit_meta("ground2", 3, quad(K1, K2, K2, K1), coll=1)
emit_meta("ground2b", 3, quad(K1, K3, K2, K1), coll=1)


# ================================================================ PALMIER
comment("palmier", "Cime sur la mer (palette 2), tronc sur le sable (palette 3).")


def palm_crown():
    cv = grid([[SEA_A, SEA_B] * 3, [SEA_C, SEA_D] * 3, [SEA_E, SEA_F] * 3, FOAM * 3], 6, 4)
    cx, cy = 24, 24
    fronds = [  # (fin x, fin y, contrôle x, contrôle y) : palmes arquées et tombantes
        (1, 22, 9, 4), (47, 21, 39, 3), (10, 31, 6, 14), (39, 31, 43, 13),
        (17, 3, 18, 6), (32, 2, 30, 6),
    ]
    leaf = {}

    def put(x, y, c, force=False):
        if 0 <= x < 48 and 0 <= y < 32:
            if force or leaf.get((x, y)) is None or c == "g":
                leaf[(x, y)] = c

    for fx, fy, kx, ky in fronds:
        pts = []
        for i in range(61):
            t = i / 60
            x = (1 - t) ** 2 * cx + 2 * (1 - t) * t * kx + t * t * fx
            y = (1 - t) ** 2 * cy + 2 * (1 - t) * t * ky + t * t * fy
            pts.append((x, y, t))
        for i, (x, y, t) in enumerate(pts):
            put(round(x), round(y), "g")
            if i == 0 or t < 0.1:
                continue
            px0, py0, _ = pts[i - 1]
            dx, dy = x - px0, y - py0
            ln = math.hypot(dx, dy) or 1
            tx, ty = dx / ln, dy / ln
            if i % 3 == 0:
                size = 5.5 * math.sin(math.pi * min(1, t * 1.15)) + 1
                for side in (1, -1):
                    nx, ny = -ty * side, tx * side
                    # folioles qui pendent : vers le bas et vers l'arrière
                    vx, vy = nx * 0.55 + tx * 0.35, ny * 0.55 + 0.75
                    vl = math.hypot(vx, vy)
                    vx, vy = vx / vl, vy / vl
                    n = int(size * (1.0 if ny > 0 else 0.6))
                    for k in range(1, n + 1):
                        put(round(x + vx * k), round(y + vy * k), "g")
        # reflet clair sur le dessus de la nervure
        for i, (x, y, t) in enumerate(pts):
            if 0.15 < t < 0.75 and i % 2 == 0:
                put(round(x), round(y) - 1, "l", force=leaf.get((round(x), round(y) - 1)) is None)
    for (x, y), c in leaf.items():
        cv[y][x] = c
    # coeur sombre et noix de coco
    for (ox, oy) in ((21, 23), (25, 24), (23, 26)):
        for dx, dy in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
            cv[oy + dy][ox + dx] = "d"
        cv[oy][ox + 1] = "l"
    for y in range(28, 32):
        for x in range(22, 27):
            cv[y][x] = "d"
    return cv


emit_big("palm", 2, palm_crown())

# tronc : motif de 8 px qui se répète (2 tuiles), plus le pied
TRUNK = [list("ss" + "bsbbbbb" + "sssssss")[:16] for _ in range(8)]
TR = [
    "sssssbbbbbbsssss",
    "sssssbsbbbbsssss",
    "sssssbssbbbbssss",
    "sssssbbbbbbbssss",
    "ssssssbbbbbbssss",
    "ssssssbsbbbbssss",
    "ssssssbssbbbssss",
    "sssssbbbbbbbssss",
]
TRUNK = [list(r) for r in TR]
cv = []
for k in range(7):
    cv += [r[:] for r in TRUNK]
BASE = [
    "sssssbsbbbbsssss",
    "ssssbbbbbbbbssss",
    "ssssbbsbbbbbbsss",
    "sssbbbssbbbbbbss",
    "ssbbbbbbbbbbbbbs",
    "sbbsbsbbbsbsbbsb",
    "ssbsbsbsbsbsbsss",
    "ssssssssssssssss",
]
cv += [list(r) for r in BASE]
# le sable autour du tronc reprend les tuiles S1/S2
for y in range(64):
    for x in range(16):
        if cv[y][x] == "s":
            cv[y][x] = (S1 if (x // 8 + y // 8) % 2 == 0 else S2)[y % 8][x % 8]
emit_big("trunk", 3, cv)


# ============================================================== OBJETS
comment("objets de plage", "Décor sans collision posé sur le sable (palette 3).")


def on_sand(w, h, art, ox=0, oy=0):
    cv = [[(S1 if ((x // 8) + (y // 8)) % 2 == 0 else S2)[y % 8][x % 8] for x in range(w)] for y in range(h)]
    blit(cv, art, ox, oy)
    return cv


PARASOL = [
    "___________bbbbbbbbb____________",
    "________bbb..sss...sbbb_________",
    "______bb....sssss....ssbb_______",
    "_____b.....sssssss.....ssb______",
    "____b......sssssss......ssb_____",
    "___b......sssssssss......ssb____",
    "__b.......sssssssss.......ssb___",
    "_bbbbbbbbbbbbbbbbbbbbbbbbbbbbb__",
    "_b._b._bsb._bsb._bsb._b._b._b___",
] + ["______________bb________________"] * 19 + [
    "_____________bbbb_______________",
    "___________bsbbbbsb_____________",
    "________________________________",
    "________________________________",
]
emit_big("parasol", 3, on_sand(32, 32, PARASOL, oy=1))

DECKCHAIR = [
    "___bb___________________________",
    "___b.b__________________________",
    "___bs.b_________________________",
    "____b.sb________________________",
    "____bs..b_______________________",
    "_____b.ss.bbbbbbbbbbbbbbbbbb____",
    "_____bs..ss..ss..ss..ss..ssb____",
    "______bbbbbbbbbbbbbbbbbbbbbb____",
    "______b_____b_______b______b____",
    "_______b___b_________b____b_____",
    "________b_b___________b__b______",
    "_________b_____________bb_______",
    "________b_b___________b__b______",
    "_______b___b_________b____b_____",
]
emit_big("chair", 3, on_sand(32, 16, DECKCHAIR, oy=2))

CASTLE = [
    "________.b______________________",
    "________..b_____________________",
    "________b___________b.__________",
    "_____s_sbs_s_______b..__________",
    "_____sssssss________b___________",
    "_____ssbbsss____s_s_bs_s________",
    "_____ssbbssss_s_sssssss_________",
    "_____sssssssssssssbbsss_________",
    "_____sssssssssssssbbsss_________",
    "____bssssssbbbsssssssssb________",
    "____bssssssbbbsssssssssb________",
    "___bbbbbbbbbbbbbbbbbbbbbbb______",
    "__bsbsbsbsbsbsbsbsbsbsbsbsb_____",
]
emit_big("castle", 3, on_sand(32, 16, CASTLE, oy=2))

SURF = [
    "_____bbbbb______",
    "____b.....b_____",
    "___b...b...b____",
] + ["___b...b...b____", "___b..sbs..b____", "___b..sbs..b____", "___b...b...b____"] + \
    ["___b...b...b____"] * 12 + [
    "___b..bbb..b____",
    "___b..bbb..b____",
    "____b..b..b_____",
    "____bb.b.bb_____",
    "__bbbbbbbbbbb___",
    "_bsbsbsbsbsbsb__",
]
emit_big("surf", 3, on_sand(16, 32, SURF, oy=4))

FLAMINGO = [
    "_____...________",
    "____.....b______",
    "____...bbbb_____",
    "____..___bb_____",
    "____..____b_____",
    "_____.._________",
    "______..________",
    "______..________",
    "_____..___......",
    "_____..._.......",
    "______.........b",
    "_______.......b_",
    "________.....b__",
    "_________bbb____",
] + ["__________b_____"] * 3 + ["_________bbb____"] + ["__________b_____"] * 4 + [
    "_________bbb____",
    "________bsbsb___",
]
emit_big("flamingo", 3, on_sand(16, 32, FLAMINGO, oy=6))

# panneau « VICE BEACH » (32 x 32), lettres sable sur bois
SIGN = [
    "_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb_",
    "_b............................b_",
    "_b.bbbbbbbbbbbbbbbbbbbbbbbbbb.b_",
    "_b.bbbbsbbbsbsbbssbsssbbbbbbb.b_",
    "_b.bbbbsbbbsbsbsbbbsbbbbbbbbb.b_",
    "_b.bbbbsbbbsbsbsbbbssbbbbbbbb.b_",
    "_b.bbbbbsbsbbsbsbbbsbbbbbbbbb.b_",
    "_b.bbbbbbsbbbsbbssbsssbbbbbbb.b_",
    "_b.bbbbbbbbbbbbbbbbbbbbbbbbbb.b_",
    "_b.bbssbbssbbsbbbssbsbsbbbbbb.b_",
    "_b.bbsbsbsbbsbsbsbbbsbsbbbbbb.b_",
    "_b.bbssbbssbsssbsbbbsssbbbbbb.b_",
    "_b.bbsbsbsbbsbsbsbbbsbsbbbbbb.b_",
    "_b.bbssbbssbsbsbbssbsbsbbbbbb.b_",
    "_b.bbbbbbbbbbbbbbbbbbbbbbbbbb.b_",
    "_b............................b_",
    "_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb_",
] + ["____bb__________________bb______"] * 11 + [
    "___bbbb________________bbbb_____",
    "__bsbsbb______________bsbsbb____",
]
emit_big("sign", 3, on_sand(32, 32, SIGN, oy=2))

# ================================================================ PROMENADE
comment("promenade et caisses")
PTOP = T(["bbbbbbbb", "s.sssss.", "ssssssss", "bbbbbbbb", "sbssssbs", "sbssssbs", "ssssssss", "sssbssss"])
emit_meta("plank", 3, quad(PTOP, PTOP, S2, S1), coll=2, extra=" stain=top")
POSTL = T(["ssssssbb", "ssbsssbs", "ssssssbs", "ssssssbb", "ssssssbs", "sbssssbs", "ssssssbs", "ssssssbb"])
POSTR = T(["bbbsssss", "ssbbssss", "ssbbsbss", "bbbbssss", "ssbbssss", "ssbbssss", "ssbbssbs", "bbbbssss"])
BEAM = T(["bbbbbbbb", "bsbbbbsb", "bbsbbsbb", "bbbssbbb", "bbbssbbb", "bbsbbsbb", "bsbbbbsb", "bbbbbbbb"])
emit_meta("dock", 3, quad(PTOP, PTOP, BEAM, BEAM), coll=2, extra=" stain=top")
emit_meta("plankpost", 3, quad(PTOP, PTOP, POSTL, POSTR), coll=2, extra=" stain=top")
POSTBL = T(["ssssssbs", "ssssssbs", "ssbsssbs", "ssssssbb", "ssssssbs", "sssssbbb", "ssssbbbb", "ssssssss"])
POSTBR = T(["ssbbssss", "ssbbssss", "ssbbssss", "bbbbssss", "ssbbssss", "sbbbbsss", "bbbbbbss", "ssssssss"])
emit_meta("post", 3, quad(POSTL, POSTR, POSTBL, POSTBR))

CRATE = [
    "bbbbbbbbbbbbbbbb",
    "bssssssssssssssb",
    "bsbbbbbbbbbbbb.b",
    "bsbssbssssbssb.b",
    "bsbsssbssbsssb.b",
    "bsbssssbbssssb.b",
    "bsbssssbbssssb.b",
    "bsbsssbssbsssb.b",
    "bsbssbssssbssb.b",
    "bsbsbssssssbsb.b",
    "bsbbbbbbbbbbbb.b",
    "b..............b",
    "bbbbbbbbbbbbbbbb",
    "bsbsssbsssbsssbb",
    "bbbbbbbbbbbbbbbb",
    "sbbssssssssssbbs",
]
emit_meta("crate", 3, CRATE, coll=1, extra=" stain=1")

# ================================================================ HÔTELS
comment("hôtels Art déco", "Palette 1 : façade jaune pâle, bandeaux orange, vitres violettes.")
W = ["yyyyyyyy"] * 8
WALLT = T(["yyyyyyyy", "yyyyyyyy", "oooooooo", "yyyyyyyy", "yyyyyyyy", "yyyyyyyy", "yyyyyyyy", "yyyyyyyy"])
WALLB = T(["yyyyyyyy", "yyyyyyyy", "yyyyyyyy", "yyyyyyyy", "yyyyyyyy", "oooooooo", "pppppppp", "yyyyyyyy"])
emit_meta("hwall", 1, quad(WALLT, WALLT, WALLB, WALLB))
WINTL = T(["yyyyyyyy", "yooooooo", "y.oooooo", "yypppppp", "yyppyppp", "yypppypp", "yyppppyp", "yypppppy"])
WINTR = T(["yyyyyyyy", "oooooooy", "oooooo.y", "ppppppyy", "ppppppyy", "ppppppyy", "ppppppyy", "ppppppyy"])
WINBL = T(["yypppppp", "yyppyppp", "yypppypp", "yyyyyyyy", "yoyoyoyo", "yoyoyoyo", "pppppppp", "yyyyyyyy"])
WINBR = T(["ppppppyy", "ppppppyy", "ppppppyy", "yyyyyyyy", "yoyoyoyy", "yoyoyoyy", "pppppppp", "yyyyyyyy"])
emit_meta("hwin", 1, quad(WINTL, WINTR, WINBL, WINBR))
PORTL = T(["yyyyyyyy", "yyyyyyyy", "oooooooo", "yyyyyooo", "yyyyoppp", "yyyoppyp", "yyyopypp", "yyyopppp"])
PORTR = T(["yyyyyyyy", "yyyyyyyy", "oooooooo", "oooyyyyy", "pppoyyyy", "ppppoyyy", "pppppoyy", "pppppoyy"])
PORTBL = T(["yyyoppp", "yyyyoppp", "yyyyyooo", "yyyyyyyy", "yyyyyyyy", "oooooooo", "pppppppp", "yyyyyyyy"]) if False else \
    T(["yyyopppp", "yyyyoppp", "yyyyyooo", "yyyyyyyy", "yyyyyyyy", "oooooooo", "pppppppp", "yyyyyyyy"])
PORTBR = T(["pppppoyy", "ppppoyyy", "oooyyyyy", "yyyyyyyy", "yyyyyyyy", "oooooooo", "pppppppp", "yyyyyyyy"])
emit_meta("hport", 1, quad(PORTL, PORTR, PORTBL, PORTBR))
ROOFT = T(["........", "........", "........", "........", "pppppppp", "yyyyyyyy", "pppppppp", "yyyyyyyy"])
ROOFTL = with_px(ROOFT, [(0, 5, "p")])
ROOFTR = with_px(ROOFT, [(7, 5, "p")])
ROOFB = T(["yoyyoyyo", "yoyyoyyo", "yoyyoyyo", "yyyyyyyy", "oooooooo", "yyyyyyyy", "pppppppp", "yyyyyyyy"])
emit_meta("hroof", 1, quad(ROOFT, ROOFT, ROOFB, ROOFB))
CROWNL = T(["........", ".......p", "......py", ".....pyo", "pppppyoy", "yyyyyyoy", "pppppppp", "yyyyyyyy"])
CROWNR = T(["........", "p.......", "yp......", "oyp.....", "yoyppppp", "yoyyyyyy", "pppppppp", "yyyyyyyy"])
emit_meta("hroofc", 1, quad(CROWNL, CROWNR, ROOFB, ROOFB))
AWN = T(["o.o.o.o.", "oyoyoyoy", "oyoyoyoy", ".o.o.o.o", "pppppppp", "yyyyyyyy", "yyoppppp", "yyoppypp"])
AWNR = T(["o.o.o.o.", "oyoyoyoy", "oyoyoyoy", ".o.o.o.o", "pppppppp", "yyyyyyyy", "ppppoyyy", "pppopyyy"])
DOORL = T(["yyopppyp", "yyoppppy", "yyoppppp", "yyoppppp", "yyoppppp", "yyoppppp", "yyoppppp", "oooooooo"])
DOORR = T(["ppppoyyy", "pppopyyy", "pppoppyy", "pppopppy", "pppoppyy", "pppopyyy", "pppoyyyy", "oooooooo"])
emit_meta("hdoor", 1, quad(AWN, AWNR, DOORL, DOORR))
# enseigne au néon « HOTEL » : lettres roses dans un cadre de 8 px, collée
# à gauche d'un morceau de mur (la moitié droite reprend les tuiles du mur)
FONT5 = {
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
}
cv = []
for i, ch in enumerate("HOTEL"):
    for y in range(16):
        row = list("oppppppo")
        gy = y - 4
        if 0 <= gy < 7:
            for gx, c in enumerate(FONT5[ch][gy]):
                if c == "#":
                    row[1 + gx] = "."
        if y == 0:
            row = list("oooooooo")
        right = (WALLT if y < 8 else WALLB)[y % 8]
        cv.append(row + right)
emit_big("neon", 1, cv)

# ================================================================== PORT
comment("port", "Ponton (palette 3), poteaux dans l'eau et vedette au large (palette 2).")
PIERT = T(["bbbbbbbb", "ss.sssss", "ssssssss", "bbbbbbbb", "bsbbbbbb", "bbbbbbbb", "bbbsbbbb", "bbbbbbbb"])
PIERT2 = T(["bbbbbbbb", "bs.sssss", "bsssssss", "bbbbbbbb", "bbbbbsbb", "bbbbbbbb", "bbbsbbbb", "bbbbbbbb"])
PIERB = T(["bbbbbbbb", "bbbsbbbb", "bbbsbbbb", "bbbbbbbb", "bbbsbbbb", "bbbsbbbb", "bbbbbbbb", "bsbsbsbs"])
emit_meta("pier", 3, quad(PIERT, PIERT2, PIERB, PIERB), coll=1, extra=" stain=top")
PPL = [r[:] for r in OPEN_A]
PPR = [r[:] for r in OPEN_B]
for y in range(8):
    PPL[y][1:4] = list("ggd")
    PPR[y][4:7] = list("ggd")
    if y % 5 == 2:
        PPL[y][2] = "l"
        PPR[y][5] = "l"
PPL2 = [r[:] for r in PPL]
PPR2 = [r[:] for r in PPR]
for t, x in ((PPL2, 2), (PPR2, 5)):
    t[4][x] = "l"
emit_meta("pierpost", 2, quad(PPL, PPR, PPL2, PPR2), coll=1)

BOAT = [
    "________________ll______________________________",
    "_______________l..l_____________________________",
    "______________l....llllllll_____________________",
    "_____________l.....l......l_____________________",
    "____lllllllllllllllllllllllllllllllllllllllll___",
    "__ll.........................................l__",
    "_l..ggggggggggggggggggggggggggggggggggggggg...l_",
    "_l............................................l_",
    "__lllllllllllllllllllllllllllllllllllllllllll___",
    "_______ll..l...ll..l....ll..l...ll..l....ll_____",
    "________ll______ll_______ll_____ll______ll______",
]
cv = grid([[OPEN_A, OPEN_B] * 3, [OPEN_B, OPEN_A] * 3], 6, 2)
blit(cv, BOAT, 0, 3)
emit_big("boat", 2, cv)

LAMP = [
    "_____ll.ll______",
    "____l.....l_____",
    "____l.....l_____",
    "_____lllll______",
] + ["_______g________"] * 23 + [
    "______ggg_______",
    "_____ggggg______",
    "_____gdgdg______",
    "________________",
    "________________",
]
cv = grid([[OPEN_A, OPEN_B], [OPEN_B, OPEN_A], [OPEN_A, OPEN_B], [OPEN_B, OPEN_A]], 2, 4)
blit(cv, LAMP, 0, 1)
emit_big("lamp", 2, cv)

header = """# Métatuiles 16x16 du niveau 1 (VICE BEACH).
# Fichier produit par tools/gen_bg_beach.py (le relancer écrase les retouches).
#
# @pal N c0 c1 c2 c3   : caractères utilisés pour les couleurs 0-3 de la palette N
# @meta NOM pal=N coll=C [stain=1|top] [bg=AUTRE]
#     16 lignes de 16 caractères. '_' = pixel pris dans la métatuile bg.
# @big NOM w=W h=H pal=N coll=C [bg=M1,M2,...]  (bg par rangée de métatuiles)
#     W x H pixels, découpé en métatuiles NOM_<x>_<y>.
# coll : 0 vide, 1 solide, 2 plateforme (traversable par dessous), 3 mortel (eau)
# stain=1 : les 4 tuiles peuvent recevoir des taches de sang ; stain=top : les 2 du haut.
#
# Palettes : 0 = HUD, 1 = ciel et hôtels, 2 = mer et palmes, 3 = sable et bois.
# La couleur 3 de la palette 3 ('r') est le sang : ne pas l'utiliser dans le décor,
# le Mode Famille la rend verte.
#
# Budget : 256 tuiles 8x8 pour tout le décor (taches comprises). Les métatuiles
# réutilisent les mêmes tuiles 8x8 autant que possible : un détail (coquillage,
# étoile de mer) tient dans une seule tuile, le reste est du sable commun.

@pal 0 . w k r
@pal 1 . p o y
@pal 2 . d l g
@pal 3 . s b r

"""
open(OUT, "w").write(header + "\n".join(out) + "\n")
