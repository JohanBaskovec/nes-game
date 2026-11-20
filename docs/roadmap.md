# Feuille de route

Chaque jalon produit une ROM `.nes` qui démarre dans un émulateur.

## Jalon 0 — Chaîne d'outils ✅
- cc65 (ca65/ld65), Make, Python 3 ; configuration ld65 MMC3 ; en-tête iNES.
- Conversion des graphismes, du niveau et des textes depuis des fichiers texte (`tools/build_assets.py`).
- Banc de test sans écran avec captures et mesure de cycles (`tools/emu/run.mjs`).

## Jalon 1 — Le héros dans le niveau ✅
- Défilement horizontal, colonnes envoyées pendant le VBlank, HUD fixe par IRQ MMC3.
- Déplacement, saut, position couchée, plateformes traversables (Bas + A), murs, fosses et eau.

## Jalon 2 — Tirer sur des moustaches ✅
- Mitraillette 8 directions, 6 balles max, 10 tirs/s, pas de munitions.
- Gerbes de fragments avec objets absurdes, clignotement par rotation de l'OAM.

## Jalon 3 — Combo, gore, Mode Famille ✅
- Combo, paliers 0 à 4, multiplicateur, messages, tremblement, flash, ciel rouge.
- Taches dans le décor (deux niveaux), copie des tables de noms en PRG-RAM.
- Menu Options : Mode Famille (couleurs du sang et textes seulement), nombre de vies.

## Jalon 4 — Le bestiaire ✅ (sauf la variante « ninja sauteur » complète)
- Moustachus rose (coureur) et menthe (rafales), ninjas (fumée, saut, shurikens, disparition), motards (moto puis à pied), imprudents (vont se placer à côté du baril le plus proche, ou en apportent un).
- Barils, explosions, réactions en chaîne, cascade de victimes.
- Ninjas qui apparaissent n'importe où, sans explication.
- Moustachus lavande et pêche : pas encore faits.

## Jalon 5 — Niveau 1 jouable de bout en bout 🟡
- ✅ Vice Beach : plage, promenade, hôtels, port (12 écrans).
- ✅ Écran titre, options, briefing, HUD, bilan, game over et continues.
- ✅ Musique (titre, niveau, fin) et 11 bruitages.
- ✅ Aucun ralentissement, mesuré (voir [technique.md](technique.md) §10).
- ⬜ Boss : le Flamant Rose Blindé.
- ⬜ Échantillon DPCM « MAXIMUM JUSTICE ! ».
- ⬜ Vie bonus tous les 50 000 points, jauge de remplissage dans le HUD, taches sur les murs.

## Jalon 6 — Niveaux 2 à 6 ⬜
- Un niveau à la fois : jeu de tuiles (banque CHR), carte (banque PRG), palette, musique, boss.
- Section verticale du niveau 6 (si validée).
- Séquence de fin (« VOUS ÊTES ALLÉ À LA FIN. ») et générique.

## Jalon 7 — Finitions ⬜
- Équilibrage, trois difficultés.
- Tests dans Mesen 2 (RAM aléatoire, avertissements PPU), puis sur console avec une cartouche flash.

---

## Décisions prises par défaut

Ces questions étaient ouvertes. J'ai retenu les recommandations ; on peut revenir dessus.

| Question | Choix actuel |
|---|---|
| Un ou deux joueurs ? | Un joueur |
| Bonus d'arme ? | Aucun : mitraillette seule |
| Langue des textes | Français, titre en anglais |
| Noms | Pas encore utilisés dans le jeu (« Sergent Brick Justice », « Victor Velours » proposés) |
| Région | NTSC uniquement |

## Questions ouvertes

| # | Question | Recommandation |
|---|---|---|
| 1 | Seconde boucle après la fin ? | Oui, peu coûteuse |
| 2 | Code de triche ? | Un code original, par exemple un « Mode Moustache » |
| 3 | Support PAL ? | Plus tard : détection au démarrage, vitesses et musique ajustées |
