; Cœur du système : démarrage, NMI, IRQ, boucle principale, PPU, manette.

IRQ_LINE = 26          ; l'IRQ MMC3 tombe dans la rangée noire sous le HUD

.segment "FIXED"

; ------------------------------------------------------------------ RESET
reset:
	sei
	cld
	ldx #$40
	stx JOY2               ; coupe l'IRQ de trame de l'APU
	ldx #$FF
	txs
	inx                    ; X = 0
	stx PPUCTRL
	stx PPUMASK
	stx DMC_FREQ           ; coupe l'IRQ du DMC
	stx MMC3_IRQ_DISABLE
	bit PPUSTATUS
@vb1:
	bit PPUSTATUS
	bpl @vb1
	txa
@clr:
	sta $0000,x
	sta $0100,x
	sta $0300,x
	sta $0400,x
	sta $0500,x
	sta $0600,x
	sta $0700,x
	inx
	bne @clr
	jsr mmc3_init
	jsr oam_clear
@vb2:
	bit PPUSTATUS
	bpl @vb2

	lda #$A7
	sta rng
	lda #$3C
	sta rng+1
	lda #3
	sta opt_lives
	jsr audio_init
	lda #1
	sta render_off
	lda #CTRL_BASE
	sta PPUCTRL
	cli
	jsr goto_title
	; boucle principale
main_loop:
	jsr read_pad
	inc frame
	jsr run_state
	lda #1
	sta nmi_ready
main_wait:                 ; fin du travail de la trame (mesuré par les tests)
	lda nmi_ready
	bne main_wait
	jmp main_loop

run_state:
	ldx state
	lda state_hi,x
	pha
	lda state_lo,x
	pha
	rts

; ------------------------------------------------------------------ MMC3
mmc3_init:
	ldx #7
@l:
	stx MMC3_BANK_SELECT   ; mode PRG 0 : $C000 fixe ; CHR A12 normal
	lda mmc3_init_banks,x
	sta MMC3_BANK_DATA
	dex
	bpl @l
	lda #0
	sta MMC3_MIRRORING     ; miroir vertical (défilement horizontal)
	lda #$80
	sta MMC3_PRG_RAM       ; active la PRG-RAM en écriture
	rts
mmc3_init_banks:
	.byte 0, 2, 4, 5, 6, 7  ; CHR : 2 Ko + 2 Ko de fond, 4 x 1 Ko de sprites
	.byte 0, 1              ; PRG : banque 0 en $8000, banque 1 en $A000

; ------------------------------------------------------------------- NMI
nmi:
	pha
	txa
	pha
	tya
	pha
	inc nmi_count
	lda render_off
	beq :+
	jmp nmi_audio
:
	lda nmi_ready
	beq @lag
	bit PPUSTATUS
	lda #0
	sta OAMADDR
	lda #>oam
	sta OAMDMA
	lda pal_dirty
	beq :+
	jsr upload_palette
:
	lda col_pending
	beq :+
	jsr upload_column
:
	jsr flush_vbuf
	lda scroll_x
	sta cur_x
	lda scroll_nt
	sta cur_nt
	lda #0
	sta nmi_ready
	beq @scroll
@lag:
	inc lag_count
@scroll:
	bit PPUSTATUS
	lda hud_split
	beq @nosplit
	; HUD : défilement nul sur la table de noms 0
	lda #CTRL_BASE
	sta PPUCTRL
	lda #0
	sta PPUSCROLL
	sta PPUSCROLL
	lda #CTRL_BASE
	ora cur_nt
	sta irq_ctrl
	lda #IRQ_LINE
	sta MMC3_IRQ_LATCH
	sta MMC3_IRQ_RELOAD
	sta MMC3_IRQ_ENABLE
	jmp @mask
@nosplit:
	lda #CTRL_BASE
	ora cur_nt
	sta PPUCTRL
	lda cur_x
	sta PPUSCROLL
	lda #0
	sta PPUSCROLL
	sta MMC3_IRQ_DISABLE
@mask:
	lda #MASK_ON
	sta PPUMASK
nmi_audio:                 ; fin du travail PPU (mesuré par les tests)
	jsr audio_update
nmi_exit:
	pla
	tay
	pla
	tax
	pla
	rti

; ------------------------------------------------------------------- IRQ
; Sous le HUD : on règle le défilement horizontal du terrain.
irq:
	pha
	sta MMC3_IRQ_DISABLE
	lda irq_ctrl
	sta PPUCTRL
	lda cur_x
	sta PPUSCROLL
	pla
	rti

; Envoie les 32 couleurs de pal_buf (pendant le VBlank ou rendu coupé).
upload_palette:
	lda #$3F
	sta PPUADDR
	lda #$00
	sta PPUADDR
	.repeat 32, i
	lda pal_buf+i
	sta PPUDATA
	.endrep
	lda #0
	sta pal_dirty
	rts

; Envoie la colonne de décor préparée (2 colonnes de tuiles + 7 attributs).
upload_column:
	lda #CTRL_BASE|CTRL_INC32
	sta PPUCTRL
	lda col_addr_hi
	sta PPUADDR
	lda col_addr_lo
	sta PPUADDR
	.repeat 26, i
	lda col_left+i
	sta PPUDATA
	.endrep
	lda col_addr_hi
	sta PPUADDR
	ldx col_addr_lo
	inx
	stx PPUADDR
	.repeat 26, i
	lda col_right+i
	sta PPUDATA
	.endrep
	ldx col_attr_x
	.repeat 7, i
	lda col_attr_hi
	sta PPUADDR
	txa
	ora #($C8 + 8*i)
	sta PPUADDR
	lda col_attr+i
	sta PPUDATA
	.endrep
	lda #CTRL_BASE
	sta PPUCTRL
	lda #0
	sta col_pending
	rts

; Vide le tampon VRAM : [longueur][adr haute][adr basse][données...] ... [0]
flush_vbuf:
	lda #CTRL_BASE
	sta PPUCTRL
	ldx #0
@next:
	ldy vbuf,x
	beq @end
	lda vbuf+1,x
	sta PPUADDR
	lda vbuf+2,x
	sta PPUADDR
	inx
	inx
	inx
@data:
	lda vbuf,x
	sta PPUDATA
	inx
	dey
	bne @data
	beq @next
@end:
	lda #0
	sta vbuf_len
	sta vbuf
	rts

; ---------------------------------------------------- outils de la boucle
wait_nmi:
	lda nmi_count
@w:
	cmp nmi_count
	beq @w
	rts

; Termine la trame courante comme la boucle principale (pour les attentes).
end_frame:
	lda #1
	sta nmi_ready
@w:
	lda nmi_ready
	bne @w
	rts

; Coupe le rendu proprement (au début d'un VBlank).
ppu_off:
	lda #1
	sta render_off
	jsr wait_nmi
	lda #0
	sta PPUMASK
	sta hud_split
	sta MMC3_IRQ_DISABLE
	; L'IRQ du HUD n'écrit qu'une fois dans PPUSCROLL : on remet le verrou
	; d'adresse du PPU à zéro avant toute écriture dans PPUADDR.
	bit PPUSTATUS
	rts

; Rallume le rendu. hud_split doit être réglé avant l'appel.
ppu_on:
	jsr wait_nmi
	bit PPUSTATUS
	lda #CTRL_BASE
	ora cur_nt
	sta PPUCTRL
	lda cur_x
	ldx hud_split
	beq :+
	lda #0
:
	sta PPUSCROLL
	lda #0
	sta PPUSCROLL
	lda #MASK_ON
	sta PPUMASK
	lda #0
	sta render_off
	sta nmi_ready
	rts

.segment "CODE"

; ------------------------------------------------------------- manette
read_pad:
	lda pad
	sta pad_old
@again:
	jsr read_joy
	sta tmp+1
	jsr read_joy
	cmp tmp+1               ; deux lectures identiques (bogue DPCM du 2A03)
	bne @again
	sta pad
	eor pad_old
	and pad
	sta pad_new
	rts

read_joy:
	lda #1
	sta JOY1
	lsr a
	sta JOY1
	ldx #8
@l:
	lda JOY1
	and #3
	cmp #1
	rol tmp
	dex
	bne @l
	lda tmp
	rts

; ----------------------------------------------------------- aléatoire
; LFSR 8 bits (période 255) mélangé à un compteur : rapide (~25 cycles).
rand:
	lda rng
	asl a
	bcc :+
	eor #$1D
:
	sta rng
	inc rng+1
	clc
	adc rng+1
	rts

; ----------------------------------------------------------------- OAM
oam_clear:
	lda #$FF
	ldx #0
@l:
	sta oam,x
	inx
	inx
	inx
	inx
	bne @l
	rts

; Cache les sprites restants à partir de oam_idx.
oam_finish:
	ldx oam_idx
	beq @done_full
	lda #$FF
@l:
	sta oam,x
	inx
	inx
	inx
	inx
	bne @l
	rts
@done_full:
	rts

; -------------------------------------------------------------- palettes
; ptr0 = palette source de 32 octets -> pal_base, puis recalcul.
set_palette:
	ldy #31
@l:
	lda (ptr0),y
	sta pal_base,y
	dey
	bpl @l
	; continue dans refresh_palette

; Recalcule pal_buf : effets de ciel, puis Mode Famille.
refresh_palette:
	ldx #31
@l:
	lda pal_base,x
	sta pal_buf,x
	dex
	bpl @l
	lda fx_sky
	beq @xform
	cmp #2
	beq @flash
	lda #$16                ; ciel « bain de sang »
	sta pal_buf+0
	lda #$06
	sta pal_buf+5
	lda #$16
	sta pal_buf+6
	lda #$26
	sta pal_buf+7
	bne @xform
@flash:
	lda #$26
	sta pal_buf+0
	sta pal_buf+5
	sta pal_buf+6
	sta pal_buf+7
@xform:
	; Mode Famille : SEULES les couleurs de sang $06/$16/$26 changent.
	lda family_mode
	beq @mirror
	ldx #31
@x:
	lda pal_buf,x
	cmp #$30
	bcs @nx
	and #$0F
	cmp #$06
	bne @nx
	lda pal_buf,x
	and #$F0
	ora #$0A
	sta pal_buf,x
@nx:
	dex
	bpl @x
@mirror:
	; $3F10/$14/$18/$1C sont des miroirs de $3F00/$04/$08/$0C
	lda pal_buf+0
	sta pal_buf+16
	lda pal_buf+4
	sta pal_buf+20
	lda pal_buf+8
	sta pal_buf+24
	lda pal_buf+12
	sta pal_buf+28
	lda #1
	sta pal_dirty
	rts

; ------------------------------------------------------- tampon VRAM
; Réserve une entrée de A octets à l'adresse PPU tmp+6 (basse) / tmp+7 (haute).
; Sortie : carry clair et X = index des données, ou carry mis si plus de place.
vbuf_alloc:
	sta tmp+5
	clc
	adc #3
	adc vbuf_len
	sta tmp+4               ; nouvelle fin
	lda #64                 ; budget de base (octets par VBlank)
	ldx col_pending
	beq :+
	lda #32
:
	ldx pal_dirty
	beq :+
	sec
	sbc #16
:
	cmp tmp+4
	bcc @full
	ldx vbuf_len
	lda tmp+5
	sta vbuf,x
	lda tmp+7
	sta vbuf+1,x
	lda tmp+6
	sta vbuf+2,x
	lda tmp+4
	sta vbuf_len
	tay
	lda #0
	sta vbuf,y
	inx
	inx
	inx
	clc
	rts
@full:
	sec
	rts

; Adresse PPU de la table de noms 0 pour (X = colonne, Y = rangée) -> tmp+6/7
nt_addr_xy:
	tya
	lsr a
	lsr a
	lsr a
	ora #$20
	sta tmp+7
	tya
	asl a
	asl a
	asl a
	asl a
	asl a
	stx tmp+6
	ora tmp+6
	sta tmp+6
	rts

; ----------------------------------------------------------------- textes
; A = identifiant de texte -> ptr0 (variante Mode Famille si activé)
text_ptr:
	tax
	lda family_mode
	bne @fam
	lda txt_lo,x
	sta ptr0
	lda txt_hi,x
	sta ptr0+1
	rts
@fam:
	lda txt_fam_lo,x
	sta ptr0
	lda txt_fam_hi,x
	sta ptr0+1
	rts

; Affiche un texte, rendu coupé. A = texte, X = colonne, Y = rangée.
print_at:
	pha
	jsr nt_addr_xy
	lda tmp+7
	sta PPUADDR
	lda tmp+6
	sta PPUADDR
	pla
	jsr text_ptr
	ldy #0
@l:
	lda (ptr0),y
	cmp #$FF
	beq @d
	sta PPUDATA
	iny
	bne @l
@d:
	rts

; Même chose pendant le rendu, via le tampon VRAM. Carry mis si pas de place.
vprint_at:
	pha
	jsr nt_addr_xy
	pla
	jsr text_ptr
	ldy #0
@len:
	lda (ptr0),y
	cmp #$FF
	beq @gotlen
	iny
	bne @len
@gotlen:
	tya
	beq @ok
	jsr vbuf_alloc
	bcs @fail
	ldy #0
@cp:
	lda (ptr0),y
	cmp #$FF
	beq @ok
	sta vbuf,x
	inx
	iny
	bne @cp
@ok:
	clc
@fail:
	rts

; Remplit les deux tables de noms (et attributs) avec la tuile A. Rendu coupé.
clear_nametables:
	ldx #$20
	stx PPUADDR
	ldx #$00
	stx PPUADDR
	ldx #8                  ; 8 x 256 = 2048 octets
	ldy #0
@l:
	sta PPUDATA
	iny
	bne @l
	dex
	bne @l
	rts

; Met les attributs de la table de noms 0 à zéro (rendu coupé)
clear_attrs:
	lda #$23
	sta PPUADDR
	lda #$C0
	sta PPUADDR
	lda #0
	ldx #64
@l:
	sta PPUDATA
	dex
	bne @l
	rts

; Affiche un nombre décimal (A = 0..99) sur 2 chiffres dans tmp+2/tmp+3
two_digits:
	ldx #0
@l:
	cmp #10
	bcc @d
	sbc #10
	inx
	bne @l
@d:
	ora #$30
	sta tmp+3
	txa
	ora #$30
	sta tmp+2
	rts
