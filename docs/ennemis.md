# Bestiaire

Quatre familles d'ennemis communs, présentes (dans des proportions différentes) dans tous les niveaux, plus un boss par niveau. Les éléments marqués **[proposition]** sont à valider.

Règle générale : **aucun ennemi n'est jamais expliqué.** Ni par un texte, ni par un personnage, ni par le décor.

---

## 1. Les Moustachus — hommes de main en costume pastel

> Ils ont tous la même moustache. Personne ne le remarque.

**Apparence** : costume croisé pastel avec épaulettes, chemise ouverte, chaîne en or, mocassins sans chaussettes, et **la** moustache. Toujours la même : même forme, même couleur, même nombre de pixels.

**Variantes par couleur de costume** (simples changements de palette, même dessin) :
| Variante | Couleur | Comportement |
|---|---|---|
| Rose | rose bonbon | Court en ligne droite vers le héros, tire une balle à hauteur de torse |
| Menthe | vert menthe | Reste sur place, tire en rafale de 3 balles |
| Lavande | violet pâle | Sort de derrière le décor (portes, voitures), tire, se recache |
| Pêche | orange pâle | Saute de plateforme en plateforme, tire en diagonale |

Chaque niveau n'utilise que **deux couleurs** à la fois (limite de palettes, voir [technique.md](technique.md)).

**Points de vie** : 1.
**Gerbe** : pixels + moustaches, lunettes de soleil, chaînes en or, cassettes.

Détail : la moustache vole souvent intacte dans la gerbe. Elle ne s'abîme jamais.

---

## 2. Les Ninjas

> Dans tous les niveaux. Y compris à la plage. Sans aucune explication.

**Apparence** : tenue de ninja noire intégrale, bandeau. Identiques dans tous les niveaux : pas de version « plage », pas de maillot, pas de crème solaire. C'est la même tenue sous le soleil de Vice Beach que dans l'usine.

**Comportement** :
- **Apparition** : surgissent dans un nuage de fumée à un endroit aléatoire (mais jamais directement sur le héros), y compris dans des lieux absurdes (derrière un parasol, d'une poubelle, d'un distributeur de boissons, d'une cabine d'essayage).
- **Ninja lanceur** : lance 2 shurikens en éventail, puis disparaît en fumée s'il n'est pas tué en 2 secondes.
- **Ninja sauteur** : enchaîne des sauts acrobatiques vers le héros et attaque au corps à corps.

**Points de vie** : 1.
**Gerbe** : pixels + shurikens, bandeaux, et, sans explication, des sushis.

Au briefing de chaque niveau, la ligne « NINJAS SIGNALÉS. EXPLICATION : AUCUNE. » apparaît systématiquement.

---

## 3. Les Motards post-apocalyptiques

> Il n'y a pas eu d'apocalypse.

**Apparence** : crête iroquoise, épaulettes cloutées, lunettes d'aviateur, pneus en guise d'armure, moto bricolée avec des pics. Exactement l'équipement qu'on aurait après la fin du monde. Le monde, lui, va très bien.

**Comportement** :
- **À moto** : traverse l'écran à grande vitesse de droite à gauche (ou de gauche à droite pour surprendre), saute sur les tremplins, percute le héros. 2 points de vie. Une fois détruite, la moto explose et le motard continue **à pied**.
- **À pied** : avance en faisant tourner une chaîne ; lance parfois une bougie d'allumage. 1 point de vie.

**Gags de décor** **[proposition]** :
- Panneaux autour d'eux : « POPULATION : TOUT LE MONDE VA BIEN », « SUPERMARCHÉ OUVERT 7J/7 ».
- Un motard qui fait la queue sagement à une station-service ouverte et parfaitement approvisionnée.

**Gerbe** : pixels + clous, chaînes, bougies d'allumage, morceaux de crête.

---

## 4. Les Imprudents — sbires qui se placent exprès à côté des barils explosifs

> Ils l'ont bien cherché.

**Apparence** : salopette, casquette, air satisfait. **[proposition]** Ils lèvent le pouce quand ils sont en position.

**Comportement** :
1. À l'apparition, l'Imprudent cherche le **baril explosif le plus proche** à l'écran et marche jusqu'à lui.
2. Arrivé au baril, il s'installe à côté (s'adosse, s'assoit dessus, le serre dans ses bras), puis tire sur le héros depuis cette position.
3. S'il n'y a aucun baril à l'écran, il **en apporte un** : il arrive en le roulant devant lui, le pose, et s'installe à côté.

**Points de vie** : 1. Mais il est évidemment plus efficace de tirer sur le baril.

**Gerbe** : pixels + casquettes, clés à molette, bidons.

### Les barils explosifs

- Orange avec une tête de mort blanche. Pas rouges : le rouge est réservé au sang, sinon le Mode Famille les rendrait verts.
- 3 balles pour les faire exploser.
- **Rayon d'explosion** : environ 32 pixels. Tue tous les ennemis dans le rayon (et le héros s'il est trop près).
- **Réaction en chaîne** : un baril qui explose fait exploser les barils voisins dans son rayon, avec un délai de 8 images entre chaque, pour l'effet visuel. Les ennemis soufflés éclatent en cascade, 2 à 5 images après l'explosion.
- Chaque victime d'une explosion compte dans le combo. C'est le principal moyen d'atteindre les paliers élevés.
- L'explosion est **orange** et n'est pas du sang : elle ne change pas en Mode Famille.

---

## 5. Les boss

Un boss par niveau, en fin de niveau, avec défilement bloqué. Les boss sont grands : ils sont dessinés en partie dans le **décor** (tuiles de fond) pour économiser les sprites, avec des parties mobiles en sprites. Tous les boss sont des **[propositions]**.

| Niveau | Boss | Concept |
|---|---|---|
| 1 — Vice Beach | **Le Flamant Rose Blindé** | Une bouée géante en forme de flamant, blindée, pilotée par deux Moustachus. Tire des balles depuis le bec, lâche des ninjas (sans explication). |
| 2 — Mégamall 2000 | **La Borne d'Arcade Possédée** | Une borne d'arcade géante qui tire des pixels et fait apparaître des ennemis « en 8 bits » (encore plus pixelisés que le reste). |
| 3 — La Zone Pas Du Tout Dévastée | **Le Roi du Bitume** | Chef motard sur un bus scolaire couvert de pics. Klaxonne avant chaque charge. Se plaint que personne n'a respecté l'apocalypse. |
| 4 — Barils & Fils | **Le Méga-Baril** | Un baril géant, de la taille de l'écran. Des Imprudents viennent sans arrêt se placer à côté. Le boss se fait exploser lui-même à la fin, emportant tout le monde. |
| 5 — Canal 80 | **Le Présentateur de Télé-Achat** | Vend des objets en direct (« LE COUTEAU QUI COUPE AUSSI LES NINJAS ! ») et les lance sur le héros. Bandeau défilant en bas de l'écran. |
| 6 — LA FIN | **Victor Velours** | Le grand méchant. Le **seul** personnage du jeu sans moustache. Personne n'en parle. Combat en trois phases, voir [niveaux.md](niveaux.md). |
