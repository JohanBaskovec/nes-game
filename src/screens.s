; Écrans fixes : titre, options, briefing, bilan, game over.

ST_TITLE    = 0
ST_OPTIONS  = 1
ST_BRIEF    = 2
ST_GAME     = 3
ST_RESULTS  = 4
ST_GAMEOVER = 5

.segment "BSS"
attr_shadow: .res 64

.segment "FIXED"

state_lo:
	.byte <(title_update-1), <(options_update-1), <(brief_update-1)
	.byte <(game_update-1), <(results_update-1), <(gameover_update-1)
state_hi:
	.byte >(title_update-1), >(options_update-1), >(brief_update-1)
	.byte >(game_update-1), >(results_update-1), >(gameover_update-1)

; Prépare un écran fixe : rendu coupé, tables vides, palette des écrans.
screen_begin:
	jsr ppu_off
	jsr oam_clear
	lda #0
	jsr clear_nametables
	ldx #63
	lda #0
:
	sta attr_shadow,x
	dex
	bpl :-
	lda #0
	sta fx_sky
	sta cur_x
	sta cur_nt
	sta scroll_x
	sta scroll_nt
	sta vbuf_len
	sta vbuf
	sta col_pending
	lda #CHR_LEVEL_HI
	sta chr_r1
	lda #<pal_screens
	sta ptr0
	lda #>pal_screens
	sta ptr0+1
	jsr set_palette
	jmp upload_palette

screen_end:
	jsr write_attrs
	lda #0
	sta hud_split
	jmp ppu_on

write_attrs:
	lda #$23
	sta PPUADDR
	lda #$C0
	sta PPUADDR
	ldx #0
:
	lda attr_shadow,x
	sta PPUDATA
	inx
	cpx #64
	bne :-
	rts

; Imprime une liste de textes : [id, x, y]..., $FF  (ptr1 = liste)
print_list:
	ldy #0
@l:
	lda (ptr1),y
	cmp #$FF
	beq @d
	pha
	iny
	lda (ptr1),y
	tax
	iny
	lda (ptr1),y
	iny
	sty tmp+5
	tay
	pla
	jsr print_at
	ldy tmp+5
	jmp @l
@d:
	rts

; ---------------------------------------------------------------- TITRE
; Haut de l'écran (logo, paysage) : image complète (title_nt, générée depuis
; assets/title.txt) avec ses deux banques de tuiles. À la rangée de tuiles 20,
; noire, l'IRQ remet la police pour les textes du bas.
TITLE_SPLIT = 160          ; ligne de l'IRQ (rangée de tuiles 20)
TITLE_HERO_X = 56          ; le héros sur la plage
TITLE_BEACH_Y = 157
TITLE_NINJA_X = 196

goto_title:
	jsr screen_begin
	lda #<pal_title
	sta ptr0
	lda #>pal_title
	sta ptr0+1
	jsr set_palette
	jsr upload_palette
	; table de noms 0 + attributs (1024 octets), copie des attributs
	lda #$20
	sta PPUADDR
	lda #$00
	sta PPUADDR
	lda #<title_nt
	sta ptr1
	lda #>title_nt
	sta ptr1+1
	ldx #4
	ldy #0
:
	lda (ptr1),y
	sta PPUDATA
	iny
	bne :-
	inc ptr1+1
	dex
	bne :-
	ldx #63
:
	lda title_nt+960,x
	sta attr_shadow,x
	dex
	bpl :-
	lda #<title_texts
	sta ptr1
	lda #>title_texts
	sta ptr1+1
	jsr print_list
	lda #0
	sta menu_sel
	sta title_timer
	lda #ST_TITLE
	sta state
	lda #MUS_TITLE
	jsr music_play
	; découpage : banques du titre en haut, police en bas
	lda #CHR_TITLE_LO
	sta chr_top
	lda #CHR_FONT
	sta chr_bottom
	lda #CHR_TITLE_HI
	sta chr_r1
	lda #TITLE_SPLIT
	sta split_line
	jsr write_attrs
	lda #1
	sta hud_split
	jmp ppu_on

title_texts:
	.byte TXT_PRESS, 2, 21
	.byte TXT_MENU_START, 12, 23
	.byte TXT_MENU_OPTIONS, 12, 25
	.byte TXT_COPY, 6, 27
	.byte $FF

title_update:
	inc title_timer
	jsr oam_clear
	lda #0
	sta oam_idx
	sta oam_full
	jsr menu_move2
	; « APPUYEZ SUR START » clignote (une demi-seconde sur deux)
	lda title_timer
	and #31
	bne @noblink
	lda title_timer
	and #32
	beq :+
	lda #TXT_BLANK
	.byte $2C               ; bit abs : saute le lda suivant
:
	lda #TXT_PRESS
	ldx #2
	ldy #21
	jsr vprint_at
@noblink:
	; curseur
	lda #84
	sta ms_xl
	lda #0
	sta ms_xh
	sta ms_eor
	lda menu_sel
	asl a
	asl a
	asl a
	asl a
	clc
	adc #184
	sta ms_y
	lda #SPR_CURSOR
	jsr draw_one
	jsr title_actors
	lda pad_new
	and #(BTN_START|BTN_A)
	beq @r
	lda #SFX_SELECT
	jsr sfx_play
	lda menu_sel
	bne :+
	jmp new_game
:
	jmp goto_options
@r:
	rts

; Le héros attend sur la plage. De temps en temps, un ninja apparaît dans
; un nuage de fumée à l'autre bout, puis repart. Sans explication.
title_actors:
	lda #0
	sta ms_xh
	sta ms_eor
	lda #TITLE_BEACH_Y
	sta ms_y
	lda #TITLE_HERO_X
	sta ms_xl
	lda #<ms_hero_fwd
	ldx #>ms_hero_fwd
	jsr title_ms
	lda #<ms_legs_stand
	ldx #>ms_legs_stand
	jsr title_ms
	; cycle de 256 images : 160-175 fumée, 176-239 ninja, 240-255 fumée
	lda title_timer
	cmp #160
	bcc @r
	ldx #TITLE_NINJA_X
	stx ms_xl
	ldx #$40                ; tourné vers le héros
	stx ms_eor
	cmp #176
	bcc @smoke
	cmp #240
	bcs @smoke
	lda #<ms_nin_run1
	ldx #>ms_nin_run1
	jmp title_ms
@smoke:
	and #4
	bne :+
	lda #<ms_smoke1
	ldx #>ms_smoke1
	jmp title_ms
:
	lda #<ms_smoke2
	ldx #>ms_smoke2
	jmp title_ms
@r:
	rts

title_ms:
	sta ptr0
	stx ptr0+1
	jmp draw_ms

; Haut/Bas entre deux entrées (menu_sel 0/1)
menu_move2:
	lda pad_new
	and #(BTN_UP|BTN_DOWN|BTN_SELECT)
	beq @r
	lda menu_sel
	eor #1
	sta menu_sel
	lda #SFX_MENU
	jsr sfx_play
@r:
	rts

; -------------------------------------------------------------- OPTIONS
goto_options:
	jsr screen_begin
	lda #<options_texts
	sta ptr1
	lda #>options_texts
	sta ptr1+1
	jsr print_list
	jsr options_values_direct
	lda #0
	sta menu_sel
	sta text_step
	lda #ST_OPTIONS
	sta state
	jmp screen_end

options_texts:
	.byte TXT_OPT_TITLE, 12, 4
	.byte TXT_OPT_FAMILY, 4, 8
	.byte TXT_OPT_LIVES, 4, 10
	.byte TXT_OPT_BACK, 4, 12
	.byte TXT_FAM_DESC1, 4, 15
	.byte TXT_FAM_DESC2, 4, 16
	.byte $FF

; Textes qui dépendent du Mode Famille / des vies (rendu coupé)
options_values_direct:
	ldx #0
@l:
	stx text_step
	jsr options_line
	jsr print_at
	ldx text_step
	inx
	cpx #6
	bne @l
	rts

; Ligne variable n° X -> A = texte, X = colonne, Y = rangée
options_line:
	cpx #0
	bne :+
	lda #TXT_NON
	ldy family_mode
	beq @fam
	lda #TXT_OUI
@fam:
	ldx #24
	ldy #8
	rts
:
	cpx #1
	bne :+
	lda opt_lives
	clc
	adc #TXT_LIVES3-3
	ldx #24
	ldy #10
	rts
:
	cpx #5
	bne :+
	lda #TXT_BLOOD_COLOR
	ldx #4
	ldy #25
	rts
:
	; lignes du sceau (2, 3, 4)
	txa
	clc
	adc #<(TXT_SEAL1-2)
	ldy family_mode
	beq :+
	clc
	adc #(TXT_SEAL1_ON-TXT_SEAL1)
:
	pha
	txa
	clc
	adc #(19-2)
	tay
	ldx #4
	pla
	rts

options_update:
	; réécrit une ligne variable par trame si besoin
	lda text_step
	cmp #6
	bcs :+
	tax
	jsr options_line
	jsr vprint_at
	bcs :+
	inc text_step
:
	jsr oam_clear
	lda #0
	sta oam_idx
	sta oam_full
	; curseur
	lda #16
	sta ms_xl
	lda #0
	sta ms_xh
	sta ms_eor
	lda menu_sel
	asl a
	asl a
	asl a
	asl a
	clc
	adc #63
	sta ms_y
	lda #SPR_CURSOR
	jsr draw_one
	; échantillon de « sang » : il change de couleur en direct
	ldx #0
@g:
	lda gib_demo_x,x
	sta ms_xl
	lda gib_demo_y,x
	sta ms_y
	lda #3
	sta ms_eor
	lda gib_demo_t,x
	jsr draw_one
	inx
	cpx #5
	bne @g
	; commandes
	lda pad_new
	and #BTN_UP
	beq :+
	lda menu_sel
	beq :+
	dec menu_sel
	lda #SFX_MENU
	jsr sfx_play
:
	lda pad_new
	and #(BTN_DOWN|BTN_SELECT)
	beq :+
	lda menu_sel
	cmp #2
	bcs :+
	inc menu_sel
	lda #SFX_MENU
	jsr sfx_play
:
	lda pad_new
	and #(BTN_A|BTN_START|BTN_LEFT|BTN_RIGHT)
	beq @r
	ldx menu_sel
	beq @family
	dex
	beq @lives
	; RETOUR
	lda pad_new
	and #(BTN_A|BTN_START)
	beq @r
	lda #SFX_SELECT
	jsr sfx_play
	jmp goto_title
@family:
	lda family_mode
	eor #1
	sta family_mode
	jsr refresh_palette
	lda #0
	sta text_step
	lda #SFX_SELECT
	jmp sfx_play
@lives:
	lda opt_lives
	clc
	adc #2
	cmp #9
	bcc :+
	lda #3
:
	sta opt_lives
	lda #0
	sta text_step
	lda #SFX_MENU
	jmp sfx_play
@r:
	rts

gib_demo_x: .byte 176, 186, 194, 204, 214
gib_demo_y: .byte 198, 194, 200, 196, 199
gib_demo_t: .byte SPR_GIB4, SPR_GIB2, SPR_GIB1, SPR_GIB5, SPR_GIB4

; ------------------------------------------------------------- BRIEFING
goto_brief:
	jsr screen_begin
	lda #0
	sta text_step
	lda #20
	sta text_timer
	lda #ST_BRIEF
	sta state
	lda #MUS_NONE
	jsr music_play
	jmp screen_end

brief_texts:
	.byte TXT_BRIEF0, 2, 4
	.byte TXT_BRIEF0B, 2, 5
	.byte TXT_BRIEF1, 2, 9
	.byte TXT_BRIEF2, 2, 11
	.byte TXT_BRIEF3, 2, 14
	.byte TXT_BRIEF4, 4, 15
	.byte TXT_BRIEF5, 4, 16
	.byte TXT_BRIEF6, 2, 21
	.byte $FF

brief_update:
	lda pad_new
	and #BTN_START
	beq :+
	jmp goto_game
:
	dec text_timer
	bne @r
	lda text_step
	asl a
	clc
	adc text_step
	tay
	lda brief_texts,y
	cmp #$FF
	bne :+
	jmp goto_game
:
	pha
	ldx brief_texts+1,y
	lda brief_texts+2,y
	tay
	pla
	jsr vprint_at
	bcs @retry
	inc text_step
	lda text_step
	asl a
	clc
	adc text_step
	tay
	lda #35
	ldx brief_texts,y
	cpx #$FF
	bne :+
	lda #150                ; dernière ligne : on laisse le temps de lire
:
	sta text_timer
	lda #SFX_MENU
	jmp sfx_play
@retry:
	lda #1
	sta text_timer
@r:
	rts

; ---------------------------------------------------------------- BILAN
goto_results:
	jsr screen_begin
	lda #<results_texts
	sta ptr1
	lda #>results_texts
	sta ptr1+1
	jsr print_list
	lda stat_mou
	ldx #26
	ldy #6
	jsr print_num2
	lda stat_nin
	ldx #26
	ldy #9
	jsr print_num2
	lda stat_bik
	ldx #26
	ldy #12
	jsr print_num2
	lda stat_imp
	ldx #26
	ldy #15
	jsr print_num2
	lda best_combo
	ldx #26
	ldy #20
	jsr print_num2
	; litres : nombre 16 bits sur 5 chiffres
	ldx #23
	ldy #18
	jsr nt_addr_xy
	lda tmp+7
	sta PPUADDR
	lda tmp+6
	sta PPUADDR
	lda stat_blood
	sta tmp+0
	lda stat_blood+1
	sta tmp+1
	jsr print_u16
	; score
	ldx #21
	ldy #22
	jsr nt_addr_xy
	lda tmp+7
	sta PPUADDR
	lda tmp+6
	sta PPUADDR
	ldx #0
:
	lda score,x
	ora #$30
	sta PPUDATA
	inx
	cpx #7
	bne :-
	lda #ST_RESULTS
	sta state
	lda #90
	sta text_timer
	jmp screen_end

results_texts:
	.byte TXT_RES_TITLE, 9, 3
	.byte TXT_RES_MOU, 3, 6
	.byte TXT_RES_MOU2, 4, 7
	.byte TXT_RES_NIN, 3, 9
	.byte TXT_RES_NIN2, 4, 10
	.byte TXT_RES_BIK, 3, 12
	.byte TXT_RES_BIK2, 4, 13
	.byte TXT_RES_IMP, 3, 15
	.byte TXT_RES_IMP2, 4, 16
	.byte TXT_RES_BLOOD, 3, 18
	.byte TXT_RES_COMBO, 3, 20
	.byte TXT_RES_SCORE, 3, 22
	.byte TXT_RES_NEXT, 10, 26
	.byte $FF

results_update:
	lda text_timer
	beq :+
	dec text_timer
	rts
:
	lda pad_new
	and #(BTN_START|BTN_A)
	beq :+
	jmp goto_title
:
	rts

; Nombre A (0-99) sur deux chiffres en (X, Y), rendu coupé.
print_num2:
	pha
	jsr nt_addr_xy
	lda tmp+7
	sta PPUADDR
	lda tmp+6
	sta PPUADDR
	pla
	jsr two_digits
	lda tmp+2
	sta PPUDATA
	lda tmp+3
	sta PPUDATA
	rts

; Nombre 16 bits tmp+0/tmp+1 sur 5 chiffres, à l'adresse PPU courante.
print_u16:
	ldy #0
@digit:
	ldx #0
@sub:
	lda tmp+0
	sec
	sbc pow10_lo,y
	sta tmp+2
	lda tmp+1
	sbc pow10_hi,y
	bcc @out
	sta tmp+1
	lda tmp+2
	sta tmp+0
	inx
	bne @sub
@out:
	txa
	ora #$30
	sta PPUDATA
	iny
	cpy #5
	bne @digit
	rts
pow10_lo: .byte <10000, <1000, <100, <10, <1
pow10_hi: .byte >10000, >1000, >100, >10, >1

; ------------------------------------------------------------ GAME OVER
goto_gameover:
	jsr screen_begin
	lda #<gameover_texts
	sta ptr1
	lda #>gameover_texts
	sta ptr1+1
	jsr print_list
	lda continues
	beq @none
	lda #TXT_GO3
	ldx #8
	ldy #16
	jsr print_at
	lda #TXT_GO4
	ldx #10
	ldy #18
	jsr print_at
	lda continues
	ora #$30
	sta PPUDATA
	jmp @end
@none:
	lda #TXT_GO5
	ldx #8
	ldy #16
	jsr print_at
@end:
	lda #ST_GAMEOVER
	sta state
	lda #60
	sta text_timer
	lda #MUS_NONE
	jsr music_play
	jmp screen_end

gameover_texts:
	.byte TXT_GO1, 7, 10
	.byte TXT_GO2, 11, 12
	.byte $FF

gameover_update:
	lda text_timer
	beq :+
	dec text_timer
	rts
:
	lda pad_new
	and #BTN_START
	beq @r
	lda continues
	bne :+
	jmp goto_title
:
	dec continues
	lda opt_lives
	sta lives
	jsr reset_score
	jmp goto_game
@r:
	rts
