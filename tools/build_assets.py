#!/usr/bin/env python3
"""Convertit les fichiers texte de assets/ en données NES.

Sorties (dans build/) :
  chr.bin        CHR-ROM (32 Ko), organisée en banques MMC3 :
                   $0000  police (128 tuiles)        -> R0 pour le HUD et les écrans de texte
                   $0800  décor, tuiles 128-255      -> R1 (toujours)
                   $1000  sprites (256 tuiles)       -> R2-R5
                   $2000  décor, tuiles 0-127        -> R0 sous le HUD (IRQ)
                   $2800  écran titre, tuiles 0-127  -> R0 en haut du titre
                   $3000  écran titre, tuiles 128-255 -> R1 sur l'écran titre
  title.inc      table de noms + attributs de l'écran titre (banque 0)
  assets.inc     tables pour la banque fixe : métasprites, métatuiles, textes
  level1.inc     données du niveau 1 (banque 0, $8000)
"""
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = lambda *p: os.path.join(ROOT, "assets", *p)
OUT = os.path.join(ROOT, "build")

CHR_SIZE = 32 * 1024


def die(msg):
    print("build_assets: " + msg, file=sys.stderr)
    sys.exit(1)


def strip_comments(lines):
    return [l.rstrip("\n") for l in lines if not (l.startswith("# ") or l.rstrip("\n") == "#")]


def tile_bytes(px):
    """px : 8 lignes de 8 indices de couleur -> 16 octets CHR."""
    lo, hi = [], []
    for row in px:
        a = b = 0
        for x, c in enumerate(row):
            if c & 1:
                a |= 0x80 >> x
            if c & 2:
                b |= 0x80 >> x
        lo.append(a)
        hi.append(b)
    return bytes(lo + hi)


# ------------------------------------------------------------------ police
CHAR_CODES = {chr(c): c for c in range(0x20, 0x60)}
EXTRA = "ÉÈÊÀÇÙÔÎÂ♥©x"
for i, ch in enumerate(EXTRA):
    CHAR_CODES[ch] = 0x60 + i


def char_code(ch):
    if ch not in CHAR_CODES:
        die("caractère non supporté par la police : %r" % ch)
    return CHAR_CODES[ch]


def build_font(fnt):
    lines = strip_comments(open(A("font.txt"), encoding="utf-8").readlines())
    i = 0
    glyphs = {}
    while i < len(lines):
        l = lines[i]
        if not l.strip():
            i += 1
            continue
        if not l.startswith("= "):
            die("font.txt : ligne inattendue %r" % l)
        chars = l[2:].split(" ")
        rows = lines[i + 1:i + 8]
        for gi, ch in enumerate(chars):
            g = []
            for r in rows:
                cell = r[gi * 6:gi * 6 + 5]
                if len(cell) != 5:
                    die("font.txt : glyphe %r mal formé" % ch)
                g.append(cell)
            glyphs[ch] = g
        i += 8
    # espace
    glyphs[" "] = ["....."] * 7
    for ch, g in glyphs.items():
        code = char_code(ch)
        px = [[2] * 8 for _ in range(8)]
        for y in range(7):
            for x in range(5):
                if g[y][x] == "#":
                    px[y][x + 1] = 1
        fnt[code] = tile_bytes(px)
    for idx in range(4):
        fnt[idx] = tile_bytes([[idx] * 8 for _ in range(8)])
    return glyphs


# -------------------------------------------------------- métatuiles (fond)
def parse_bg(path):
    lines = strip_comments(open(path, encoding="utf-8").readlines())
    pals = {}
    metas = []  # (nom, pal, coll, stain, pixels 16x16)
    byname = {}
    i = 0

    def attrs(tokens):
        d = {}
        for t in tokens:
            k, v = t.split("=")
            d[k] = v
        return d

    def read_rows(n, w):
        nonlocal i
        rows = lines[i:i + n]
        i += n
        for r in rows:
            if len(r) != w:
                die("%s : ligne de largeur %d au lieu de %d : %r" % (path, len(r), w, r))
        return rows

    while i < len(lines):
        l = lines[i].strip()
        i += 1
        if not l:
            continue
        tok = l.split()
        if tok[0] == "@pal":
            pals[int(tok[1])] = tok[2:6]
        elif tok[0] == "@meta":
            name = tok[1]
            at = attrs(tok[2:])
            pal = int(at["pal"])
            rows = read_rows(16, 16)
            px = []
            for r in rows:
                line = []
                for ch in r:
                    if ch == "_":
                        line.append(None)
                    else:
                        line.append(pals[pal].index(ch))
                px.append(line)
            if "bg" in at:
                bgpx = byname[at["bg"]][4]
                px = [[bgpx[y][x] if px[y][x] is None else px[y][x] for x in range(16)] for y in range(16)]
            m = (name, pal, int(at.get("coll", 0)), at.get("stain", "0"), px, at.get("hi") == "1")
            metas.append(m)
            byname[name] = m
        elif tok[0] == "@big":
            name = tok[1]
            at = attrs(tok[2:])
            w, h, pal = int(at["w"]), int(at["h"]), int(at["pal"])
            rows = read_rows(h, w)
            bgs = at.get("bg", "").split(",") if "bg" in at else []
            for my in range(h // 16):
                for mx in range(w // 16):
                    px = []
                    for y in range(16):
                        line = []
                        for x in range(16):
                            ch = rows[my * 16 + y][mx * 16 + x]
                            if ch == "_":
                                bgpx = byname[bgs[my]][4]
                                line.append(bgpx[y][x])
                            else:
                                line.append(pals[pal].index(ch))
                        px.append(line)
                    nm = "%s_%d_%d" % (name, mx, my)
                    m = (nm, pal, int(at.get("coll", 0)), at.get("stain", "0"), px, at.get("hi") == "1")
                    metas.append(m)
                    byname[nm] = m
        else:
            die("%s : directive inconnue %r" % (path, l))
    return metas


def splat(px, rng, amount):
    """Ajoute des pixels de sang (couleur 3) sur une tuile 8x8."""
    px = [row[:] for row in px]
    for _ in range(amount):
        cx, cy = rng.randrange(8), rng.randrange(8)
        px[cy][cx] = 3
        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            if rng.random() < 0.45:
                x, y = cx + dx, cy + dy
                if 0 <= x < 8 and 0 <= y < 8:
                    px[y][x] = 3
    return px


def build_bg(bg, metas):
    """Remplit la table de motifs du décor (256 tuiles, sans la police).

    Les tuiles 0-3 sont unies (couleurs 0-3), comme dans la banque de la
    police : la rangée noire sous le HUD reste identique quand l'IRQ change
    de banque. Les métatuiles hi=1 (écran titre) sont placées dans les
    tuiles 128-255, les autres d'abord dans 4-127.
    """
    tiles = {}  # bytes -> index
    for idx in range(4):
        b = tile_bytes([[idx] * 8 for _ in range(8)])
        bg[idx] = b
        tiles[b] = idx
    nxt = {"lo": 4, "hi": 128}

    def alloc(b, hi=False):
        if b in tiles:
            t = tiles[b]
            if hi and 4 <= t < 128:
                die("tuile partagée entre l'écran titre et la moitié basse")
            return t
        if not hi and nxt["lo"] < 128:
            key = "lo"
        else:
            key = "hi"
        if nxt[key] > (127 if key == "lo" else 255):
            die("plus de place dans la table de motifs du décor")
        t = nxt[key]
        nxt[key] += 1
        bg[t] = b
        tiles[b] = t
        return t

    mt = [None] * len(metas)
    stain_src = {}  # index de tuile -> pixels
    order = [i for i, m in enumerate(metas) if m[5]] + [i for i, m in enumerate(metas) if not m[5]]
    for i in order:
        name, pal, coll, stain, px, hi = metas[i]
        q = []
        for (ox, oy) in ((0, 0), (8, 0), (0, 8), (8, 8)):
            sub = [row[ox:ox + 8] for row in px[oy:oy + 8]]
            t = alloc(tile_bytes(sub), hi)
            q.append(t)
            if stain == "1" or (stain == "top" and oy == 0):
                if pal != 3:
                    die("métatuile %s : seules les tuiles de palette 3 peuvent être tachées" % name)
                stain_src[t] = sub
        mt[i] = (name, q, pal, coll)
    stain_next = [0] * 256
    for t, sub in sorted(stain_src.items()):
        rng = random.Random(t * 7919)
        prev, cur = t, sub
        for level, amount in ((1, 3), (2, 7)):
            cur = splat(cur, rng, amount)
            s = alloc(tile_bytes(cur))
            if stain_next[prev] == 0 and s != prev:
                stain_next[prev] = s
            prev = s
    used = nxt["lo"] + nxt["hi"] - 128
    print("décor : %d tuiles utilisées sur 256 (basse %d/128, haute %d/128), %d métatuiles"
          % (used, nxt["lo"], nxt["hi"] - 128, len(mt)))
    return mt, stain_next


# ------------------------------------------------------------ écran titre
TITLE_SPLIT_ROW = 20  # rangée de tuiles noire où l'IRQ remet la police


def build_title(ttl):
    """assets/title.txt -> 1024 octets (table de noms + attributs).

    Haut de l'écran (rangées de tuiles 0-19) : 256 tuiles propres au titre,
    ttl[0..127] en R0 et ttl[128..255] en R1. Les tuiles 0-3 sont unies,
    comme dans la police. Bas (rangées 20-29) : vide, les textes sont écrits
    par le code avec la police (l'IRQ remet R0 sur la police en rangée 20)."""
    lines = strip_comments(open(A("title.txt"), encoding="utf-8").readlines())
    i = lines.index("@attr")
    attr = [[int(c) for c in lines[i + 1 + y]] for y in range(15)]
    j = lines.index("@image")
    img = [[".123".index(c) for c in lines[j + 1 + y]] for y in range(240)]
    if any(len(r) != 256 for r in img) or any(len(r) != 16 for r in attr):
        die("title.txt : image de 256x240 et attributs de 16x15 attendus")
    if any(any(r) for r in img[TITLE_SPLIT_ROW * 8:]):
        die("title.txt : les rangées de tuiles %d à 29 doivent rester vides" % TITLE_SPLIT_ROW)
    tiles = {}
    for k in range(4):
        ttl[k] = tile_bytes([[k] * 8 for _ in range(8)])
        tiles[ttl[k]] = k
    nxt = [4]

    def alloc(b):
        if b in tiles:
            return tiles[b]
        if nxt[0] > 255:
            die("écran titre : plus de 256 tuiles différentes dans le haut de l'écran")
        ttl[nxt[0]] = b
        tiles[b] = nxt[0]
        nxt[0] += 1
        return nxt[0] - 1

    nt = []
    for ty in range(30):
        for tx in range(32):
            if ty >= TITLE_SPLIT_ROW:
                nt.append(0)
            else:
                nt.append(alloc(tile_bytes([row[tx * 8:tx * 8 + 8] for row in img[ty * 8:ty * 8 + 8]])))
    at = [0] * 64
    for y in range(15):
        for x in range(16):
            at[(y // 2) * 8 + x // 2] |= (attr[y][x] & 3) << (((y & 1) * 2 + (x & 1)) * 2)
    print("titre : %d tuiles utilisées sur 256" % nxt[0])
    return nt + at


# ---------------------------------------------------------------- sprites
SPR_COLORS = {".": 0, "s": 1, "r": 1, "1": 1, "c": 2, "o": 2, "2": 2, "k": 3, "w": 3, "3": 3}


def parse_sprites(path):
    lines = strip_comments(open(path, encoding="utf-8").readlines())
    imgs, frames = {}, []
    i = 0
    while i < len(lines):
        l = lines[i].strip()
        i += 1
        if not l:
            continue
        tok = l.split()
        if tok[0] == "@img":
            rows = []
            while i < len(lines) and lines[i].strip() and not lines[i].startswith("@"):
                rows.append(lines[i].rstrip())
                i += 1
            w = len(rows[0])
            for r in rows:
                if len(r) != w:
                    die("sprite %s : lignes de largeurs différentes" % tok[1])
            imgs[tok[1]] = rows
        elif tok[0] == "@frame":
            at = dict(t.split("=") for t in tok[2:])
            frames.append((tok[1], at))
        else:
            die("sprites.txt : directive inconnue %r" % l)
    return imgs, frames


def flip_h(rows):
    return [r[::-1] for r in rows]


def flip_v(rows):
    return rows[::-1]


def build_sprites(spr, imgs, frames):
    cells = {}  # tuple(pixels) -> pair index
    pairs = []
    out = []
    consts = []

    def find_or_add(cell):
        # cell : 16 lignes de 8 entiers
        key = tuple(tuple(r) for r in cell)
        for flip, f in ((0, lambda c: c), (0x40, flip_h), (0x80, flip_v), (0xC0, lambda c: flip_v(flip_h(c)))):
            k = tuple(tuple(r) for r in f([list(r) for r in key]))
            if k in cells:
                return cells[k], flip
        p = len(pairs)
        if p >= 128:
            die("plus de place pour les sprites (128 paires 8x16)")
        pairs.append(cell)
        cells[key] = p
        return p, 0

    for name, at in frames:
        pal = int(at["pal"])
        ax, ay = int(at["ax"]), int(at["ay"])
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
        px = [[SPR_COLORS[c] for c in r] for r in rows]
        h, w = len(px), len(px[0])
        if w % 8 or h % 16:
            die("frame %s : taille %dx%d non multiple de 8x16" % (name, w, h))
        entries = []
        for cy in range(0, h, 16):
            for cx in range(0, w, 8):
                cell = [row[cx:cx + 8] for row in px[cy:cy + 16]]
                if not any(any(r) for r in cell):
                    continue
                p, flip = find_or_add(cell)
                entries.append((cy - ay, p * 2 + 1, pal | flip, cx - ax))
        out.append((name, entries))
        if len(entries) == 1:
            consts.append((name, entries[0][1]))
    for p, cell in enumerate(pairs):
        top = [row for row in cell[:8]]
        bot = [row for row in cell[8:]]
        spr[2 * p] = tile_bytes(top)
        spr[2 * p + 1] = tile_bytes(bot)
    print("sprites : %d paires 8x16 utilisées sur 128" % len(pairs))
    return out, consts


# ---------------------------------------------------------------- niveau
def parse_level(path, mt_index):
    lines = strip_comments(open(path, encoding="utf-8").readlines())
    rows_default, legend, enemies, screens = None, {}, {}, []
    i = 0
    while i < len(lines):
        l = lines[i].strip()
        i += 1
        if not l:
            continue
        tok = l.split()
        if tok[0] == "@rows":
            rows_default = tok[1:]
            if len(rows_default) != 13:
                die("level : @rows doit avoir 13 entrées")
        elif tok[0] in ("@legend", "@enemies"):
            d = legend if tok[0] == "@legend" else enemies
            while lines[i].strip() != "@end":
                if lines[i].strip():
                    k, v = lines[i].split()
                    d[k] = v
                i += 1
            i += 1
        elif tok[0] == "@screen":
            rows = [lines[i + k].rstrip() for k in range(13)]
            for r in rows:
                if len(r) != 16:
                    die("level : ligne d'écran de largeur %d : %r" % (len(r), r))
            screens.append(rows)
            i += 13
        else:
            die("level : directive inconnue %r" % l)
    def row_default(y, col):
        """Terrain par défaut ; « a|b|c » : variante pseudo-aléatoire fixe
        selon la colonne (répéter un nom pour le rendre plus fréquent)."""
        if rows_default[y].startswith("~"):
            # « ~nom » : les métatuiles nom_0_0, nom_1_0... à la suite, en boucle
            base = rows_default[y][1:]
            n = 0
            while "%s_%d_0" % (base, n) in mt_index:
                n += 1
            if n == 0:
                die("level : aucune métatuile %s_N_0" % base)
            return "%s_%d_0" % (base, col % n)
        opts = rows_default[y].split("|")
        if len(opts) == 1:
            return opts[0]
        return opts[random.Random(col * 131 + y * 7).randrange(len(opts))]

    width = 16 * len(screens)
    grid = [[None] * width for _ in range(13)]
    spawns = []
    stamps = []
    for s, rows in enumerate(screens):
        for y in range(13):
            for x in range(16):
                ch = rows[y][x]
                col = s * 16 + x
                if ch in enemies:
                    spawns.append((col, y, enemies[ch]))
                    grid[y][col] = "<"
                elif ch == ".":
                    grid[y][col] = row_default(y, col)
                elif ch in legend and legend[ch].startswith("@"):
                    stamps.append(((col, y), legend[ch][1:]))
                    grid[y][col] = row_default(y, col)
                elif ch in legend:
                    opts = legend[ch].split("|")
                    grid[y][col] = opts[random.Random(col * 131 + y * 7).randrange(len(opts))]
                else:
                    die("level : caractère inconnu %r (écran %d)" % (ch, s + 1))
    for y in range(13):
        for x in range(width):
            if grid[y][x] == "<":
                grid[y][x] = grid[y][x - 1] if x > 0 else row_default(y, x)
    # tampons : « K @palm » pose palm_X_Y à partir de la case du K
    for (x, y), base in stamps:
        found = False
        for name in mt_index:
            m = re.match(re.escape(base) + r"_(\d+)_(\d+)$", name)
            if m:
                dx, dy = int(m.group(1)), int(m.group(2))
                if y + dy < 13 and x + dx < width:
                    grid[y + dy][x + dx] = name
                found = True
        if not found:
            die("level : aucune métatuile %s_X_Y pour le tampon" % base)
    for y in range(13):
        for x in range(width):
            if grid[y][x] not in mt_index:
                die("level : métatuile inconnue %s" % grid[y][x])
    spawns.sort(key=lambda s: (s[0], s[1]))
    return width, grid, spawns


# ------------------------------------------------------------------ textes
def parse_texts(path):
    out = []
    for l in strip_comments(open(path, encoding="utf-8").readlines()):
        if not l.strip():
            continue
        name, _, text = l.partition("=")
        name, text = name.strip(), text.strip()
        pad = None
        if ":" in name:
            name, pad = name.split(":")
            pad = int(pad)
        if "|" in text:
            normal, fam = [t.strip() for t in text.split("|")]
        else:
            normal = text
            fam = text.replace("SANG", "SLIME")
        if pad:
            if len(normal) > pad or len(fam) > pad:
                die("texte %s trop long pour %d caractères" % (name, pad))
            normal, fam = normal.ljust(pad), fam.ljust(pad)
        out.append((name, normal, fam))
    return out


def asm_bytes(data, per_line=16):
    lines = []
    for i in range(0, len(data), per_line):
        lines.append("\t.byte " + ",".join("$%02X" % (b & 0xFF) for b in data[i:i + per_line]))
    return "\n".join(lines)


def main():
    os.makedirs(OUT, exist_ok=True)
    fnt = [None] * 128
    ttl = [None] * 256
    bg = [None] * 256
    spr = [None] * 256
    build_font(fnt)
    title_nt = build_title(ttl)
    metas = parse_bg(A("bg_beach.txt"))
    mt, stain_next = build_bg(bg, metas)
    imgs, frames = parse_sprites(A("sprites.txt"))
    ms, consts = build_sprites(spr, imgs, frames)

    chr_data = bytearray(CHR_SIZE)
    for i, b in enumerate(fnt):
        if b:
            chr_data[i * 16:(i + 1) * 16] = b
    for i, b in enumerate(bg):
        if b:
            base = 0x2000 + i * 16 if i < 128 else 0x0800 + (i - 128) * 16
            chr_data[base:base + 16] = b
    for i, b in enumerate(ttl):
        if b:
            chr_data[0x2800 + i * 16:0x2800 + (i + 1) * 16] = b  # $2800-$37FF
    for i, b in enumerate(spr):
        if b:
            chr_data[0x1000 + i * 16:0x1000 + (i + 1) * 16] = b
    open(os.path.join(OUT, "chr.bin"), "wb").write(chr_data)

    o = ["; Fichier généré par tools/build_assets.py — ne pas modifier.", ""]
    # métatuiles
    mt_index = {m[0]: i for i, m in enumerate(mt)}
    o.append("NUM_METATILES = %d" % len(mt))
    for i, m in enumerate(mt):
        o.append("MT_%s = %d" % (m[0].upper(), i))
    for k, label in enumerate(("mt_tl", "mt_tr", "mt_bl", "mt_br")):
        o.append(label + ":")
        o.append(asm_bytes([m[1][k] for m in mt]))
    o.append("mt_pal:")
    o.append(asm_bytes([m[2] for m in mt]))
    o.append("mt_coll:")
    o.append(asm_bytes([m[3] for m in mt]))
    o.append("stain_next:")
    o.append(asm_bytes(stain_next))
    # métasprites
    o.append("")
    for name, val in consts:
        o.append("SPR_%s = $%02X" % (name.upper(), val))
    for name, entries in ms:
        o.append("ms_%s:" % name)
        data = []
        for dy, t, at, dx in entries:
            data += [dy & 0xFF, t, at, dx & 0xFF]
        data.append(0x80)
        o.append(asm_bytes(data))
    # textes
    texts = parse_texts(A("textes.txt"))
    o.append("")
    for i, (name, _, _) in enumerate(texts):
        o.append("TXT_%s = %d" % (name, i))
    for suffix, idx in (("", 1), ("_fam", 2)):
        for i, t in enumerate(texts):
            o.append("txt%s_%d:" % (suffix, i))
            o.append(asm_bytes([char_code(c) for c in t[idx]] + [0xFF]))
    for suffix in ("", "_fam"):
        o.append("txt%s_lo:" % suffix)
        o.append("\t.byte " + ",".join("<txt%s_%d" % (suffix, i) for i in range(len(texts))))
        o.append("txt%s_hi:" % suffix)
        o.append("\t.byte " + ",".join(">txt%s_%d" % (suffix, i) for i in range(len(texts))))
    open(os.path.join(OUT, "assets.inc"), "w").write("\n".join(o) + "\n")

    # niveau 1
    width, grid, spawns = parse_level(A("level1.txt"), mt_index)
    if width > 256:
        die("niveau trop long (256 colonnes max)")
    data = []
    for x in range(width):
        col = [mt_index[grid[y][x]] for y in range(13)] + [0, 0, 0]
        data += col
    lo = ["; Fichier généré par tools/build_assets.py — ne pas modifier.", ""]
    lo.append("LEVEL1_COLS = %d" % width)
    lo.append("level1_map:")
    lo.append(asm_bytes(data))
    lo.append("level1_spawns:")
    for col, row, kind in spawns:
        lo.append("\t.byte %d, %d, ENT_%s" % (col, row, kind))
    lo.append("\t.byte $FF")
    open(os.path.join(OUT, "level1.inc"), "w").write("\n".join(lo) + "\n")
    to = ["; Fichier généré par tools/build_assets.py — ne pas modifier.", "",
          "title_nt:", asm_bytes(title_nt)]
    open(os.path.join(OUT, "title.inc"), "w").write("\n".join(to) + "\n")
    print("niveau 1 : %d colonnes, %d apparitions" % (width, len(spawns)))


if __name__ == "__main__":
    main()
