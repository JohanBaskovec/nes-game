# Game Design Document — ULTRA DEATH COP III: MAXIMUM JUSTICE

Les éléments marqués **[proposition]** sont des idées à valider ; tout le reste vient du cahier des charges initial.

---

## 1. Ton et direction artistique

**Années 80 parodiques et loufoques.** Le jeu se prend exactement autant au sérieux qu'une jaquette de VHS d'action de 1987 : pas du tout, mais avec une conviction totale.

- **Palette** : néons roses et cyans, couchers de soleil dégradés (dans la limite des 54 couleurs de la NES), palmiers, chrome.
- **Humour** : visuel et textuel, jamais d'explication. Les absurdités sont présentées comme normales. Personne dans le jeu ne remarque que tous les hommes de main ont la même moustache.
- **Textes** : courts, en majuscules, avec l'emphase des briefings de l'époque (« MISSION : ALLER À LA FIN. »).
- **Le « III »** : le jeu se présente comme une suite. Les épisodes I et II n'existent pas. L'écran d'intro y fait référence avec aplomb (« APRÈS LES ÉVÉNEMENTS D'ULTRA DEATH COP II... »), sans jamais préciser lesquels.

## 2. Le héros **[proposition]**

**Sergent Brick Justice**, flic hors-la-loi de la loi. Lunettes de soleil (jamais retirées), coupe mulet, badge, débardeur, mitraillette.

- Sprite de 16×32 pixels environ.
- Une seule réplique, affichée au début de chaque niveau : « C'EST L'HEURE DE LA JUSTICE. » (variantes possibles : « JUSTICE ? JUSTICE. »).

## 3. Objectif

**Aller à la fin.** C'est littéralement l'objectif affiché au briefing. Le dernier niveau s'appelle « LA FIN » et se termine devant un panneau sur lequel est écrit « FIN ». Voir [niveaux.md](niveaux.md).

## 4. Contrôles

Manette NES standard.

| Entrée | Action |
|---|---|
| Croix directionnelle | Se déplacer / viser dans 8 directions |
| Bas (au sol) | Se coucher (tir à ras du sol) |
| A | Sauter (saut en boule, hauteur fixe, contrôle aérien horizontal) |
| Bas + A (sur plateforme) | Descendre à travers la plateforme |
| B (maintenu) | Tirer en continu |
| Start | Pause |
| Select | **[proposition]** Le héros réajuste ses lunettes de soleil. Aucun effet de jeu. |

Règles de visée :
- Debout immobile : tir horizontal, ou vers le haut avec Haut.
- En marchant : diagonales avec Haut/Bas + direction.
- En saut : les 8 directions, y compris vers le bas.
- Couché : tir horizontal bas.

## 5. L'arme : la mitraillette

On commence avec une mitraillette. **Pas de munitions, pas de recharge.**

- Tir automatique tant que B est maintenu : une balle toutes les 6 images (10 tirs/s en NTSC).
- Maximum **6 balles du joueur à l'écran** simultanément (limite technique, voir [technique.md](technique.md)). Si la limite est atteinte, le tir attend qu'une balle sorte de l'écran.
- Balle : petit sprite 8×8, vitesse ~4 px/image, un point de dégât.
- Aucun écran, aucune icône, aucun compteur de munitions. Le HUD affiche à la place de l'emplacement de l'arme : « MUNITIONS : OUI ».

**[proposition — à décider]** Faut-il des bonus d'arme ? Deux options :
1. **Mitraillette seule pour tout le jeu** (le plus fidèle au cahier des charges, et un bon gag : des caisses de bonus apparaissent, on les fait exploser, elles contiennent... une autre mitraillette identique).
2. Quelques bonus parodiques temporaires (ex. « MITRAILLETTE PLUS » qui tire exactement pareil mais affiche « PLUS »).

L'option 1 est recommandée : elle simplifie le jeu, le code et la mémoire, et le gag fonctionne.

## 6. Vies, dégâts et continues

- Mort en un coup (convention du genre).
- 3 vies par partie, 3 continues. Vie bonus tous les 50 000 points.
- Après une mort : réapparition sur place en haut de l'écran, 2 secondes d'invincibilité (clignotement).
- Le héros, lui aussi, éclate en gerbe de pixels quand il meurt. En Mode Famille, en slime.

## 7. Le système de combo et de gore

C'est la mécanique centrale du jeu.

### 7.1 Le combo

- Chaque ennemi tué **dans les 90 images (1,5 s)** qui suivent le précédent augmente le compteur de combo.
- Si le délai expire, le combo retombe à 0.
- Les explosions de barils qui tuent plusieurs ennemis comptent pour chaque victime : c'est le moyen le plus rapide de faire grimper le compteur.
- Le combo multiplie le score (voir §10).

### 7.2 Les gerbes de pixels

Chaque ennemi tué éclate en une **gerbe absurde de morceaux de pixels** : des fragments de 1 à 4 pixels, projetés dans toutes les directions, qui retombent avec la gravité et rebondissent une fois au sol.

Parmi les morceaux, des objets absurdes apparaissent au hasard :
- des moustaches (intactes) ;
- des lunettes de soleil ;
- des cassettes audio, des VHS ;
- une chaussure ;
- un canard en plastique ;
- un pin's « I ♥ 1986 ».

Chaque type d'ennemi a sa propre table d'objets (les moustachus perdent des moustaches, les motards des clous et des chaînes, les ninjas des shurikens et, sans explication, des sushis).

### 7.3 Plus le combo est gros, plus l'écran se remplit

Le combo est découpé en **paliers**. Chaque palier ajoute des effets aux précédents :

| Palier | Combo | Effets |
|---|---|---|
| 0 | 1–4 | Gerbe normale (4 fragments par ennemi) |
| 1 — « JOLI » | 5–9 | 6 fragments par ennemi ; les fragments qui touchent le sol laissent des **taches** sur le décor |
| 2 — « BAIN DE SANG » | 10–19 | 8 fragments ; message à l'écran (taches sur les murs : prévu) |
| 3 — « CARNAGE » | 20–49 | 12 fragments ; tremblement d'écran ; flash rouge de la palette à chaque mort |
| 4 — « MAXIMUM JUSTICE » | 50+ | 16 fragments par ennemi ; le ciel vire au rouge sang ; fanfare (voix digitalisée « MAXIMUM JUSTICE ! » prévue) |

- Les **taches** sont dessinées dans le décor lui-même (tuiles du fond), donc elles s'accumulent sans coûter de sprites. Elles restent jusqu'à ce que la zone sorte de l'écran.
- **Aucun ralentissement**, même au palier 4. Le clignotement des fragments est assumé (c'est l'esthétique de l'époque), mais le jeu ne ralentit jamais. Pour tenir le budget, une trame crée au plus 16 fragments, et les victimes d'une explosion éclatent en cascade sur quelques trames (voir [technique.md](technique.md) §10).
- Chaque message de palier s'affiche dans le HUD à la place du message précédent.
- Une jauge « REMPLISSAGE » dans le HUD **[proposition]** indique la progression vers le palier suivant.

## 8. Le Mode Famille

Pour se moquer de la censure sur consoles dans les années 80, le menu des options propose un **« Mode Famille »**.

**Ce qu'il fait :**
1. Le sang devient **vert**.
2. Le sang est **rebaptisé « slime »** dans tous les textes du jeu.

**Ce qu'il ne fait pas :** tout le reste. Les ennemis explosent toujours en gerbes de morceaux, avec les mêmes moustaches volantes, les mêmes taches sur les murs, les mêmes paliers, la même voix « MAXIMUM JUSTICE ! ». C'est ça, le gag.

### 8.1 Présentation dans le menu

```
  MODE FAMILLE ........ NON

  > REND LE JEU ADAPTÉ À
    TOUTE LA FAMILLE.
```

Quand on l'active, un sceau s'affiche **[proposition]** : « APPROUVÉ PAR LE COMITÉ NATIONAL DE LA MORALITÉ LUDIQUE ».

### 8.2 Textes remplacés

| Mode normal | Mode Famille |
|---|---|
| BAIN DE SANG | BAIN DE SLIME |
| LITRES DE SANG | LITRES DE SLIME |
| SANG : ROUGE | SLIME : VERT |
| (toute autre occurrence de « SANG ») | « SLIME » |

### 8.3 Règle de conception stricte

**Le Mode Famille ne doit rien changer d'autre que la couleur du sang et le mot « sang ».** Concrètement :
- les explosions de barils restent orange ;
- les éléments rouges du décor (néons, voitures) restent rouges ;
- le gameplay, le score et les sons sont identiques.

Critère de test : une capture d'écran en mode normal et une en Mode Famille, prises dans la même situation, ne doivent différer que par les pixels de sang et le mot « SANG/SLIME ». Les conséquences techniques (palettes) sont décrites dans [technique.md](technique.md).

## 9. Menus et écrans

### 9.1 Écran titre
- Logo « ULTRA DEATH COP III », sous-titre « MAXIMUM JUSTICE » en chrome, coucher de soleil, palmiers.
- « APPUYEZ SUR START (FERMEMENT) ».
- Options : COMMENCER / OPTIONS.

### 9.2 Options
| Option | Valeurs |
|---|---|
| DIFFICULTÉ | FACILE / NORMAL / MAXIMUM JUSTICE |
| VIES | 3 / 5 / 7 |
| MODE FAMILLE | NON / OUI |
| TEST SON | 00–XX |

Les options sont conservées jusqu'au reset de la console (pas de sauvegarde sur pile).

### 9.3 Briefing (avant chaque niveau)
Écran texte façon télétype :
```
NIVEAU 1 : VICE BEACH
OBJECTIF : ALLER À LA FIN.
RENSEIGNEMENTS : NINJAS SIGNALÉS.
EXPLICATION : AUCUNE.
```

### 9.4 Bilan de fin de niveau
```
MOUSTACHUS ÉLIMINÉS ..... 47
  (TOUS IDENTIQUES)
NINJAS ................... 12
  (INEXPLIQUÉS)
MOTARDS .................. 8
  (APOCALYPSE : TOUJOURS PAS)
SBIRES PRÈS DES BARILS ... 15
  (ILS L'AVAIENT CHERCHÉ)
LITRES DE SANG ........... 340
MEILLEUR COMBO ........... 63
```

### 9.5 Écran de game over
« LA JUSTICE A ÉTÉ... SUSPENDUE. CONTINUER ? »

### 9.6 Fin du jeu
Voir [niveaux.md](niveaux.md), niveau 6.

## 10. Score

| Action | Points |
|---|---|
| Moustachu | 100 |
| Ninja | 200 |
| Motard (à moto) | 300 |
| Motard (à pied) | 150 |
| Sbire près d'un baril | 100 |
| Baril détruit | 50 |
| Boss | 10 000 |

- **Multiplicateur de combo** : ×1 au palier 0, ×2, ×3, ×5, ×10 au palier 4.
- Score maximal affiché : 9 999 990 (7 chiffres + un zéro fixe, comme à l'époque).

## 11. Musique et sons

- Musique 2A03 pur (2 voies carrées, triangle, bruit, DPCM), style synth-pop / power ballad / rock FM.
- Un thème par niveau, un thème de boss, un jingle de fin de niveau, un thème de game over.
- **Échantillon DPCM** (prévu, pas encore fait) : la voix « MAXIMUM JUSTICE ! » (palier 4 et écran titre). En attendant, une fanfare sur le carré 2.
- Effets : tir (court, sec), explosion d'ennemi (bruit + chute de hauteur), baril (bruit long), saut, mort du héros.
