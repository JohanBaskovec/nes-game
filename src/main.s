; ULTRA DEATH COP III: MAXIMUM JUSTICE
; Point d'entrée : une seule unité d'assemblage qui inclut tous les modules.

.include "nes.inc"
.macpack longbranch

; ------------------------------------------------------------ en-tête iNES
.segment "HEADER"
	.byte "NES", $1A
	.byte 8                 ; 8 x 16 Ko de PRG-ROM (128 Ko)
	.byte 4                 ; 4 x 8 Ko de CHR-ROM (32 Ko)
	.byte $41               ; mapper 4 (MMC3), miroir vertical
	.byte $00
	.byte 0, 0, 0, 0, 0, 0, 0, 0

.include "vars.s"

; ------------------------------------------------- banque 0 : le niveau
.segment "BANK00"
.include "level1.inc"
.include "title.inc"

; --------------------------------------------- banque fixe : tout le code
.segment "RODATA"
.include "assets.inc"

.segment "CODE"

.include "core.s"
.include "level.s"
.include "oam.s"
.include "player.s"
.include "enemies.s"
.include "particles.s"
.include "game.s"
.include "screens.s"
.include "audio.s"

.segment "VECTORS"
	.word nmi, reset, irq

.segment "CHARS"
	.incbin "chr.bin"
