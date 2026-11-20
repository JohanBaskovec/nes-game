# Architecture technique

Objectif : une **vraie ROM NES** (format iNES, mapper MMC3) qui respecte les contraintes de la console d'origine et peut être gravée sur une cartouche. Le jeu est écrit **entièrement en assembleur 6502** (ca65). Aucun comportement propre à un émulateur n'est utilisé.

Ce document décrit le code tel qu'il existe. Les écarts avec la conception initiale sont signalés.

---

## 1. Plateforme cible

| Élément | Valeur |
|---|---|
| Région | **NTSC** (60 Hz). PAL : non géré pour l'instant. |
| CPU | Ricoh 2A03 (6502 sans mode décimal), 1,79 MHz |
| Budget CPU par image | 29 780 cycles |
| VBlank | ~2 270 cycles pour toutes les écritures dans la VRAM |
| RAM interne | 2 Ko |
| PPU | 64 sprites, 8 par ligne, 4 palettes de fond + 4 de sprites |

**Règle de performance : aucun ralentissement, jamais.** Chaque trame doit finir son calcul avant la NMI suivante, y compris au palier MAXIMUM JUSTICE. Quand il y a trop de sprites sur une ligne, ce sont les fragments qui clignotent, mais le jeu ne ralentit pas. Voir §10 pour les mesures.

## 2. Cartouche : MMC3 (TxROM, mapper 4)

| Élément | Valeur actuelle | Extensible à |
|---|---|---|
| PRG-ROM | 128 Ko (16 banques de 8 Ko) | 512 Ko |
| CHR-ROM | 32 Ko (seuls les 8 premiers Ko sont utilisés) | 256 Ko |
| PRG-RAM | 8 Ko en $6000–$7FFF, sans pile | — |
| Miroir | vertical (défilement horizontal) | réglable par logiciel |

En-tête iNES 1.0 : `NES␚`, 8 × 16 Ko de PRG, 4 × 8 Ko de CHR, octet 6 = `$41` (mapper 4, miroir vertical). C'est la configuration d'une cartouche TxROM standard (ex. TLROM, TSROM). Les cartouches flash (EverDrive N8, PowerPak…) la gèrent toutes.

Le MMC3 apporte :
- l'**IRQ de ligne de balayage**, qui permet un HUD fixe pendant que le terrain défile ;
- le découpage de la PRG en banques de 8 Ko et de la CHR en banques de 1 et 2 Ko, utile pour les niveaux suivants ;
- 8 Ko de RAM supplémentaire (copie des tables de noms, §6.3).

### 2.1 Organisation de la PRG-ROM

| Adresse | Banque | Contenu |
|---|---|---|
| $8000–$9FFF | 0 (commutable, R6) | Niveau 1 : carte des colonnes ($8000, alignée sur une page) et liste des apparitions |
| $A000–$BFFF | 1 (commutable, R7) | Libre (prévu : musique et niveaux suivants) |
| $C000–$DFFF | 14 (fixe) | Segment `CODE` : moteur (niveau, OAM, héros, ennemis, fragments, jeu) |
| $E000–$FFFF | 15 (fixe) | Segments `FIXED` / `RODATA` / `VECTORS` : démarrage, NMI, IRQ, écrans, son, données générées |

Au démarrage, seule la banque en $E000 est garantie par le MMC3. Le code de démarrage (`reset`, `mmc3_init`) est donc dans `FIXED` ; il configure le mode PRG 0 avant d'appeler quoi que ce soit en $C000.

### 2.2 Organisation de la CHR (banque 0, 8 Ko)

| Fenêtre PPU | Contenu |
|---|---|
| $0000–$0FFF | Fond : $00–$03 tuiles unies, $20–$6B police (ASCII + accents + ♥ ©), $70–$FF décor du niveau et variantes tachées |
| $1000–$1FFF | Sprites : 128 paires 8×16 (86 utilisées) |

**Contrainte de l'IRQ MMC3** : le compteur de lignes compte les fronts montants de l'adresse A12 du PPU. Il faut donc le fond en $0000 et les sprites en $1000. En mode 8×16, le bit 0 du numéro de tuile choisit la table : **toutes les tuiles de sprites ont un numéro impair**. Le script de conversion s'en charge.

## 3. Outils

| Outil | Rôle |
|---|---|
| **ca65 / ld65** (cc65) | Assemblage et édition de liens |
| **GNU Make** | `make` produit `build/udc3.nes` |
| **Python 3** (+ rien d'autre) | `tools/build_assets.py` : convertit les fichiers texte de `assets/` en CHR et en tables |
| **Node.js + jsnes** | `tools/emu/run.mjs` : banc de test sans écran (captures, mesures de cycles) |
| FCEUX, Mesen 2… | Pour jouer |

Les graphismes, le niveau et les textes sont décrits dans des **fichiers texte** (ASCII art) : pas besoin d'éditeur graphique, et les différences se lisent dans git.

Le son utilise un **moteur maison** (§9) plutôt que FamiStudio : la musique s'écrit directement en assembleur, sans outil graphique. C'est un écart avec la conception initiale.

Arborescence :
```
src/            code assembleur (main.s inclut tous les modules)
  main.s        en-tête iNES, segments, inclusions
  nes.inc       registres matériels
  vars.s        toutes les variables (page zéro, RAM, PRG-RAM)
  core.s        reset, NMI, IRQ, boucle principale, PPU, manette, textes
  level.s       colonnes de décor, collisions, caméra, taches
  oam.s         métasprites et construction de l'OAM
  player.s      héros et ses balles
  enemies.s     ennemis, barils, explosions, projectiles ennemis
  particles.s   gerbes de fragments
  game.s        écran de jeu, combo, score, HUD, palettes
  screens.s     titre, options, briefing, bilan, game over
  audio.s       bruitages et musique
  notes.inc     table des périodes NTSC
assets/         sources texte : police, sprites, décor, niveau, textes
tools/          build_assets.py, banc de test emu/
cfg/mmc3.cfg    configuration de ld65
build/          sorties (ROM, CHR, tables générées, symboles .lbl)
```

## 4. Mémoire vive

| Plage | Usage |
|---|---|
| $0000–$00FF | Page zéro : système, héros, partie, paramètres des modules (~110 octets) |
| $0100–$01FF | Pile |
| $0200–$02FF | Copie de l'OAM (DMA à chaque NMI) |
| $0300–$07FF | Tampon VRAM, palettes, colonne en attente, score, statistiques, tables d'entités (~980 octets) |
| $6000–$67FF | PRG-RAM : copie des deux tables de noms du terrain (pour les taches) |

Entités, en tableaux parallèles (un tableau par champ, indexés par X) :

| Catégorie | Emplacements |
|---|---|
| Héros | 1 |
| Balles du héros | 6 |
| Ennemis, barils, explosions, fumées | 8 |
| Projectiles ennemis | 8 |
| Fragments | 32 |

Positions : x monde sur 16 bits (+ sous-pixel pour les objets qui en ont besoin), y écran sur 8 bits. Vitesses en virgule fixe 8.8.

## 5. Boucle principale, NMI et IRQ

```
reset → init matériel, RAM, MMC3, son → écran titre → boucle principale

boucle principale (une itération par trame) :
  lire la manette (deux lectures identiques exigées : bogue DPCM)
  exécuter l'état courant (titre / options / briefing / jeu / bilan / game over)
  nmi_ready = 1, attendre que la NMI le remette à 0

NMI :
  si render_off : seulement le son
  si nmi_ready : DMA OAM, palette (si modifiée), colonne de décor (si prête),
                 tampon VRAM, validation du défilement
  sinon        : trame en retard (compteur lag_count, doit rester à 0)
  HUD : défilement (0,0) sur la table 0, armement de l'IRQ MMC3 (ligne 26)
  son

IRQ (ligne ~27, dans la rangée noire sous le HUD) :
  PPUCTRL (table de noms) + PPUSCROLL (x) du terrain
```

Détails importants pour le matériel réel :
- L'IRQ écrit **une seule fois** dans `PPUSCROLL`, ce qui laisse le verrou d'adresse du PPU dans l'état « deuxième écriture ». La NMI relit `PPUSTATUS` avant toute écriture, et `ppu_off` aussi avant de redessiner un écran (sinon les écritures dans `PPUADDR` sont décalées).
- Écriture de l'IRQ MMC3 : `$C000 = $C001 = 26` puis `$E001`. L'IRQ tombe à la fin de la ligne 25 ; le changement de défilement prend effet vers la ligne 27, dans la rangée de tuiles 3, entièrement noire dans les deux tables de noms. Aucun artefact visible.
- Les changements d'état (game over, bilan) coupent le rendu, redessinent l'écran, puis le rallument. La boucle de jeu s'arrête aussitôt après un changement d'état pour ne rien envoyer de plus au PPU.

## 6. Défilement et décor

### 6.1 Données du niveau
- Métatuiles 16×16 (4 tuiles + palette + type de collision). 34 métatuiles pour la plage.
- Une colonne = 16 octets (13 métatuiles + 3 de remplissage), donc colonne `c` à `level1_map + c*16`. Le niveau 1 fait 192 colonnes (12 écrans).
- Collisions : vide, solide, plateforme (traversable par dessous, Bas + A pour descendre), eau (mortelle).
- Liste des apparitions triée par colonne : `[colonne, rangée, type]`.

### 6.2 Défilement
- Uniquement vers la droite. La caméra suit le héros au-delà de x = 120 (3 px par trame au plus), jusqu'à la fin du niveau.
- Écran de départ : colonnes 0 à 17 écrites pendant que le rendu est coupé.
- Ensuite, dès que `colonne_caméra + 17 ≥ prochaine_colonne`, la boucle principale prépare une colonne (52 tuiles + 7 attributs), envoyée par la NMI en mode d'incrément 32 avec un code déroulé (~640 cycles).
- Le terrain occupe les rangées de tuiles 4 à 29 ; les rangées 0 à 3 forment le HUD (fond noir) dans les deux tables de noms.
- Tremblement d'écran : décalage horizontal de 0 ou 3 px une trame sur deux, appliqué au terrain seulement (le HUD reste fixe).

### 6.3 Taches
Quand un fragment rebondit une deuxième fois sur le sol (à partir du palier 1), la tuile touchée est remplacée par sa **variante tachée** (deux niveaux de taches, générés automatiquement par le script). La boucle principale lit la tuile actuelle dans la copie des tables de noms en PRG-RAM, cherche la suivante dans `stain_next`, et l'envoie par le tampon VRAM. Comme on ne revient jamais en arrière, rien n'est mémorisé hors de l'écran.

### 6.4 Budget du VBlank

| Poste | Coût |
|---|---|
| DMA OAM | 513 cycles |
| Colonne de décor | ~640 cycles |
| Palette (32 octets, déroulé) | ~290 cycles |
| Tampon VRAM | ~15 cycles/octet, plafonné à 64 octets (32 si une colonne est en attente, 16 de moins si la palette change) |

Le plafond est appliqué par `vbuf_alloc` : une demande qui ne tient pas est refusée et réessayée à la trame suivante (HUD) ou abandonnée (tache).

## 7. Sprites, priorités et clignotement

Sprites 8×16. Le héros est en deux parties (haut 16×16 selon la visée, jambes 16×16 selon l'animation) : 4 sprites. Les moustachus, ninjas et imprudents font 16×32 (4 sprites), le motard à moto 32×32.

L'OAM est reconstruite à chaque trame, dans cet ordre de priorité :
1. le héros ;
2. les projectiles ennemis (toujours visibles) ;
3. les ennemis (ordre de départ tournant à chaque trame) ;
4. les balles du héros ;
5. les fragments (ordre tournant, sacrifiés en premier).

Au-delà de 64 sprites, ou de 8 sur une ligne, ce sont les derniers de la liste qui disparaissent. Comme l'ordre tourne, ils clignotent au lieu de disparaître.

Les 8 pixels de gauche de l'écran sont masqués (PPUMASK) pour cacher l'apparition des sprites au bord gauche.

## 8. Palettes et Mode Famille

### 8.1 Palettes du niveau 1

| Palette | Couleurs | Usage |
|---|---|---|
| Fond 0 | rose (fond), blanc, noir, **sang** | HUD |
| Fond 1 | violet, orange, jaune | ciel, soleil, hôtels |
| Fond 2 | bleu foncé, bleu clair, vert | mer, palmiers, poteaux du ponton |
| Fond 3 | sable, brun, **sang** | sol, planches, caisses, ponton (tachables) |
| Sprites 0 | peau, bleu, noir | héros, curseur |
| Sprites 1 | peau, rose pastel, noir | moustachus roses, ninjas, objets |
| Sprites 2 | peau, menthe, noir | moustachus menthe (palette changée par XOR), imprudents, motards |
| Sprites 3 | **sang**, orange, blanc | fragments, balles, barils, explosions, fumée |

Le noir de la moustache est le même dans toutes les palettes : elle est identique chez tout le monde, techniquement aussi.

### 8.2 La règle du sang
**Les couleurs `$06`, `$16` et `$26` sont réservées au sang.** Rien d'autre dans le jeu ne les utilise : ni les barils (orange), ni les explosions (orange et blanc), ni le décor.

### 8.3 Implémentation du Mode Famille
`refresh_palette` recopie la palette de base, applique les effets de ciel (flash, ciel rouge au palier 4, qui utilisent eux aussi les couleurs du sang), puis, **si `family_mode` vaut 1, remplace `$06/$16/$26` par `$0A/$1A/$2A`**. Rien d'autre.

Côté textes, le script génère pour chaque texte une variante Mode Famille, identique sauf `SANG` → `SLIME` (ou une variante explicite, comme `SANG : ROUGE` / `SLIME : VERT`). `text_ptr` choisit la table selon `family_mode`.

`family_mode` n'est lu qu'à trois endroits : `refresh_palette`, `text_ptr` et le menu des options.

## 9. Son

Moteur maison dans `audio.s`, appelé dans la NMI. La boucle principale ne fait que des demandes d'un octet (`sfx_play`, `music_play`), donc il n'y a aucune course entre la boucle et la NMI.
- **Musique** : carré 1 (mélodie), carré 2 (arpèges), triangle (basse), bruit (batterie). Pistes en octets : notes, durées, volume, boucle. Trois morceaux : titre (la mineur), niveau (mi mineur), jingle de fin.
- **Bruitages** : 11 sons, sur le canal de bruit ou le carré 2, avec priorités. Pendant un bruitage, la piste musicale du canal se tait, puis reprend.
- **Pas encore fait** : l'échantillon DPCM « MAXIMUM JUSTICE ! ». Il devra être placé en $C000–$FFFF (contrainte matérielle du DMC). Le bogue de lecture de la manette lié au DPCM est déjà contourné (double lecture).

## 10. Performances mesurées

Mesures faites avec `tools/emu/run.mjs --profile` (cycles CPU réels de l'émulateur) :

| Scénario | NMI (partie PPU) | Calcul max d'une trame | Trames en retard |
|---|---|---|---|
| Parcours normal du niveau | 1 394 / ~2 270 | 18 700 | 0 |
| Parcours avec le combo forcé au palier 4 | 1 604 / ~2 270 | 23 000 | 0 |
| Test synthétique : 8 ennemis et barils serrés, réaction en chaîne, palier 4 | 1 104 / ~2 270 | 24 400 | 0 |

Le calcul disponible par trame est d'environ 27 500 cycles (29 780 moins la NMI). Les mesures qui ont permis de tenir ce budget :
- au plus **16 fragments créés par trame** ; les autres demandes sont ignorées ;
- les victimes d'une explosion éclatent **en cascade**, sur 2 à 5 trames ;
- points × multiplicateur en une seule addition ;
- palette recalculée au plus une fois par trame ;
- collisions des fragments testées une trame sur deux ;
- affichage des fragments en boucle déroulée, sans sous-programme.

## 11. Tests

```
cd tools/emu && npm install        # une seule fois (jsnes, pngjs)
node run.mjs ../../build/udc3.nes --frames 600 \
     --input "100:+START,104:-START,140:+START,144:-START,200:+RIGHT,200:+B" \
     --shots 300,500 --out /tmp/captures --watch "state,lag_count,combo" --profile 150
```

Options : `--input` (appuis/relâchements par trame), `--shots` / `--every` (captures PNG), `--watch` / `--ram` (variables par nom, grâce au fichier `.lbl`), `--poke` (valeur forcée à chaque trame, par ex. `p_invuln=20`), `--set` (écriture unique), `--nt 0` (table de noms en texte), `--profile N` (mesure des cycles), `--breakdown F` (coût de chaque étape à la trame F).

À faire avant une gravure sur cartouche : tester dans Mesen 2 avec la RAM initialisée au hasard et les avertissements d'accès PPU activés, puis sur une vraie console avec une cartouche flash.
