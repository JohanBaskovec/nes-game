# ULTRA DEATH COP III: MAXIMUM JUSTICE

> *« Il n'y a jamais eu de I ni de II. Il n'y en avait pas besoin. »*

Un run'n'gun à défilement horizontal pour la **Nintendo Entertainment System**, dans des années 80 parodiques et loufoques. Écrit entièrement en **assembleur 6502**. C'est une vraie ROM NES (mapper MMC3) qui respecte les contraintes de la console et peut être gravée sur une cartouche.

**But du jeu : aller à la fin.**

## Le pitch en 30 secondes

- On incarne un flic avec des lunettes de soleil et une mitraillette. Pas de munitions, pas de recharge. Juste la justice.
- Les ennemis : des hommes de main en costume pastel qui ont **tous la même moustache**, des **ninjas** (partout, même à la plage, sans aucune explication), des **motards post-apocalyptiques** (il n'y a pas eu d'apocalypse) et des **sbires qui se placent exprès à côté des barils explosifs**.
- Les ennemis éclatent en gerbes absurdes de pixels. Plus le combo est gros, plus l'écran se remplit.
- Le menu des options propose un **Mode Famille** : le sang devient vert, s'appelle « slime », et rien d'autre ne change.

## Jouer

La ROM compilée est `build/udc3.nes`. Ouvre-la dans un émulateur NES :
- **FCEUX** : `sudo apt install fceux`, puis `fceux build/udc3.nes`
- **Mesen 2** (le plus précis, recommandé pour vérifier avant une cartouche) : https://www.mesen.ca

| Manette NES | Action |
|---|---|
| Croix | Se déplacer, viser dans 8 directions (en saut : toutes les directions) |
| Bas | Se coucher |
| A | Sauter (Bas + A sur une plateforme : descendre) |
| B (maintenu) | Tirer |
| Start | Pause / valider |

Dans FCEUX, les touches par défaut sont : flèches, F = A, D = B, Entrée = Start, S = Select (modifiables dans Options › Input).

## Compiler

Prérequis : `cc65` (assembleur ca65 + éditeur de liens ld65), GNU Make, Python 3.

```
sudo apt install cc65
make
```

La ROM est produite dans `build/udc3.nes`. `make clean` efface le dossier `build/`.

## Sur une vraie cartouche

La ROM est au format iNES, mapper 4 (MMC3), 128 Ko de PRG-ROM, 32 Ko de CHR-ROM et 8 Ko de PRG-RAM : la configuration d'une cartouche TxROM standard.
- **Cartouche flash** (EverDrive N8, PowerPak…) : copier `udc3.nes` sur la carte SD, c'est tout.
- **Cartouche gravée** : il faut une carte MMC3 (TLROM/TSROM ou une carte de reproduction MMC3), une EPROM de 128 Ko pour la PRG et une de 32 Ko pour la CHR. Les 16 premiers octets du fichier (l'en-tête) ne sont pas gravés.

Avant de graver, tester dans Mesen 2 avec la RAM initialisée au hasard, puis sur une cartouche flash.

## État du projet

Le **niveau 1 (Vice Beach) est jouable de bout en bout** : écran titre, options avec le Mode Famille, briefing, 12 écrans de plage, promenade, hôtels et port, quatre familles d'ennemis, barils et réactions en chaîne, combo jusqu'à MAXIMUM JUSTICE, taches de sang dans le décor, musique et bruitages, bilan, game over et continues. Aucun ralentissement : le temps de calcul de chaque trame est mesuré.

Pas encore fait : le boss du niveau 1, la voix digitalisée, les niveaux 2 à 6. Détails dans [docs/roadmap.md](docs/roadmap.md).

## Inspiration

Le jeu reprend les codes d'un **genre** (le run'n'gun 8 bits de la fin des années 80 : tir dans 8 directions, mort en un coup, défilement horizontal). On ne reprend **aucun** élément d'un jeu existant en particulier : ni nom, ni personnage, ni graphisme, ni musique, ni niveau, ni code de triche. Tout le contenu est original.

## Documentation

| Document | Contenu |
|---|---|
| [docs/game-design.md](docs/game-design.md) | Ton, gameplay, contrôles, arme, système de combo et de gore, Mode Famille, menus, score |
| [docs/ennemis.md](docs/ennemis.md) | Bestiaire : comportements, variantes, boss |
| [docs/niveaux.md](docs/niveaux.md) | Les six niveaux, de la plage jusqu'à LA FIN |
| [docs/technique.md](docs/technique.md) | Architecture NES : cartouche, mémoire, NMI/IRQ, budgets, mesures de performance, tests |
| [docs/roadmap.md](docs/roadmap.md) | Jalons, état d'avancement, décisions |

## Modifier le contenu

Tout le contenu est en texte dans `assets/` ; `make` reconvertit automatiquement :
- `font.txt` : la police ; `sprites.txt` : tous les sprites (ASCII art) ;
- `bg_beach.txt` : les métatuiles du décor ; `level1.txt` : la carte du niveau, écran par écran, avec les ennemis et les objets de décor ;
- `textes.txt` : tous les textes (la variante Mode Famille est générée automatiquement).

- `title.txt` : l'image de l'écran titre (logo, paysage), produite par `tools/gen_title.py`.

`python3 tools/preview_level.py` dessine tout le niveau dans `build/level1_preview.png`, et `python3 tools/preview_sprites.py` tous les sprites dans `build/sprites_preview.png`, sans émulateur (nécessite `python3-pil`). Pratique pour vérifier les graphismes après une modification.
