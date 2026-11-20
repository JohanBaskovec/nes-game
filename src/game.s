; Écran de jeu : initialisation, boucle, combo, score, HUD.

HUD_SCORE = 1
HUD_COMBO = 2
HUD_MSG   = 4
HUD_LIVES = 8

COMBO_TIME = 90        ; 1,5 s pour enchaîner

.segment "CODE"

; Nouvelle partie : remet le score et les vies à zéro.
new_game:
	lda opt_lives
	sta lives
	lda #3
	sta continues
	jsr reset_score
	jmp goto_brief

reset_score:
	lda #0
	ldx #6
:
	sta score,x
	dex
	bpl :-
	rts

goto_game:
	jsr ppu_off
	jsr oam_clear
	lda #0
	jsr clear_nametables
	; bandeau noir du HUD : rangées 0 à 3 des deux tables de noms
	lda #$20
	jsr fill_hud_band
	lda #$24
	jsr fill_hud_band
	; textes fixes du HUD
	lda #$69                ; coeur
	ldx #11
	ldy #1
	jsr put_tile_xy
	lda #TXT_HUD_AMMO
	ldx #18
	ldy #1
	jsr print_at
	lda #TXT_HUD_COMBO
	ldx #2
	ldy #2
	jsr print_at
	; état de la partie
	lda #0
	sta combo
	sta combo_timer
	sta tier
	sta shake
	sta fx_sky
	sta fx_timer
	sta level_done
	sta paused
	sta spawn_idx
	sta msg_timer
	sta best_combo
	sta stat_mou
	sta stat_nin
	sta stat_bik
	sta stat_imp
	sta stat_blood
	sta stat_blood+1
	sta pt_next
	sta lag_count
	lda #$FF
	sta end_xh
	lda #200
	sta ninja_timer
	lda #TXT_MSG_NONE
	sta msg_id
	jsr clear_entities
	jsr player_init
	jsr load_level_start
	lda #<pal_level1
	sta ptr0
	lda #>pal_level1
	sta ptr0+1
	jsr set_palette
	jsr upload_palette
	; HUD complet tout de suite
	jsr hud_draw_score_direct
	lda #0
	sta hud_dirty
	jsr hud_lives_direct
	jsr hud_combo_direct
	lda #0
	sta cur_x
	sta cur_nt
	sta scroll_x
	sta scroll_nt
	sta col_pending
	sta vbuf_len
	sta vbuf
	lda #1
	sta hud_split
	lda #CHR_FONT           ; HUD : police ; terrain : décor
	sta chr_top
	lda #CHR_LEVEL_LO
	sta chr_bottom
	lda #CHR_LEVEL_HI
	sta chr_r1
	lda #IRQ_LINE
	sta split_line
	lda #ST_GAME
	sta state
	lda #MUS_LEVEL
	jsr music_play
	jsr ppu_on
	lda #0
	sta lag_count
	rts

; Rangées 0-3 de la table de noms (A = $20 ou $24) en noir (tuile 2).
fill_hud_band:
	sta PPUADDR
	lda #0
	sta PPUADDR
	lda #2
	ldx #128
:
	sta PPUDATA
	dex
	bne :-
	rts

; Une tuile A en (X, Y) dans la table de noms 0, rendu coupé.
put_tile_xy:
	pha
	jsr nt_addr_xy
	lda tmp+7
	sta PPUADDR
	lda tmp+6
	sta PPUADDR
	pla
	sta PPUDATA
	rts

game_update:
	; pause
	lda pad_new
	and #BTN_START
	beq @np
	lda level_done
	bne @np
	lda paused
	eor #1
	sta paused
	ldx #TXT_MSG_PAUSE
	cmp #0
	bne :+
	ldx #TXT_MSG_NONE
:
	stx msg_id
	lda #0
	sta msg_timer
	lda hud_dirty
	ora #HUD_MSG
	sta hud_dirty
@np:
	lda paused
	beq :+
	jmp hud_update
:
	jsr player_update
	lda state
	cmp #ST_GAME
	bne @out
	jsr camera_update
	jsr spawn_update
	jsr ninja_spawner
	jsr update_enemies
	jsr update_pbullets
	jsr update_ebullets
	jsr update_particles
	jsr combo_update
	jsr level_end_check
	lda state
	cmp #ST_GAME
	bne @out
	jsr hud_update
	; palette recalculée au plus une fois par trame
	lda pal_req
	beq :+
	lda #0
	sta pal_req
	jsr refresh_palette
:
	jsr build_oam
	jsr compute_scroll
@out:
	rts

level_end_check:
	lda level_done
	bne @running
	lda p_state
	bne @r
	lda p_xl
	sec
	sbc end_xl
	lda p_xh
	sbc end_xh
	bcc @r
	lda #1
	sta level_done
	lda #180
	sta end_timer
	lda #TXT_MSG_END
	sta msg_id
	lda #0
	sta msg_timer
	lda hud_dirty
	ora #HUD_MSG
	sta hud_dirty
	lda #MUS_CLEAR
	jsr music_play
@r:
	rts
@running:
	dec end_timer
	bne @r
	jmp goto_results

; ----------------------------------------------------------- combo/score
; Un ennemi vient de mourir. A = points (dizaines).
on_kill:
	pha
	lda combo
	cmp #99
	bcs :+
	inc combo
:
	lda #COMBO_TIME
	sta combo_timer
	lda combo
	cmp best_combo
	bcc :+
	sta best_combo
:
	ldx #0
	lda combo
	cmp #5
	bcc @t
	inx
	cmp #10
	bcc @t
	inx
	cmp #20
	bcc @t
	inx
	cmp #50
	bcc @t
	inx
@t:
	cpx tier
	beq @same
	bcc @same
	stx tier
	lda tier_msg,x
	sta msg_id
	lda #120
	sta msg_timer
	lda hud_dirty
	ora #HUD_MSG
	sta hud_dirty
	cpx #4
	bne @same
	lda #1                  ; MAXIMUM JUSTICE : le ciel saigne
	sta fx_sky
	sta pal_req
	lda #SFX_MAX
	jsr sfx_play
@same:
	lda tier
	cmp #3
	bcc @nofx
	lda #8
	sta shake
	lda tier
	cmp #4
	beq @nofx
	lda #2                  ; flash rouge
	sta fx_sky
	lda #4
	sta fx_timer
	lda #1
	sta pal_req
@nofx:
	lda hud_dirty
	ora #HUD_COMBO
	sta hud_dirty
	; points x multiplicateur, en une seule addition (plafonné à 255 dizaines)
	pla
	sta tmp+0
	ldx tier
	ldy tier_mult,x
	lda #0
@m:
	clc
	adc tmp+0
	bcs @cap
	dey
	bne @m
	jmp add_points
@cap:
	lda #255
	jmp add_points

tier_msg:
	.byte TXT_MSG_NONE, TXT_MSG_JOLI, TXT_MSG_BAIN, TXT_MSG_CARNAGE, TXT_MSG_MAX
tier_mult:
	.byte 1, 2, 3, 5, 10
tier_gibs:
	.byte 4, 6, 8, 12, 16

; Ajoute A dizaines de points (0-255). Préserve Y.
add_points:
	ldx #0
@div:
	cmp #10
	bcc @d
	sbc #10
	inx
	bne @div
@d:
	clc
	adc score+5
	sta score+5
	txa
	clc
	adc score+4
	sta score+4
	ldx #5
@n:
	lda score,x
	cmp #10
	bcc @nx
	sbc #10
	sta score,x
	cpx #0
	beq @max
	inc score-1,x
	jmp @n
@nx:
	dex
	bpl @n
	bmi @ok
@max:
	ldx #5
	lda #9
:
	sta score,x
	dex
	bpl :-
@ok:
	lda hud_dirty
	ora #HUD_SCORE
	sta hud_dirty
	rts

combo_update:
	lda combo_timer
	beq @c2
	dec combo_timer
	bne @c2
	lda #0
	sta combo
	sta tier
	lda hud_dirty
	ora #HUD_COMBO
	sta hud_dirty
	lda fx_sky
	beq @c2
	lda fx_timer
	bne @c2
	lda #0
	sta fx_sky
	lda #1
	sta pal_req
@c2:
	lda fx_timer
	beq @c3
	dec fx_timer
	bne @c3
	lda #0
	ldx tier
	cpx #4
	bne :+
	lda #1
:
	sta fx_sky
	lda #1
	sta pal_req
@c3:
	lda msg_timer
	beq @c4
	dec msg_timer
	bne @c4
	lda #TXT_MSG_NONE
	sta msg_id
	lda hud_dirty
	ora #HUD_MSG
	sta hud_dirty
@c4:
	rts

; ------------------------------------------------------------------ HUD
; Une mise à jour par trame au plus, pour rester dans le budget du VBlank.
hud_update:
	lda hud_dirty
	beq @r
	lsr a
	bcs @score
	lsr a
	bcs @combo
	lsr a
	bcs @msg
	lsr a
	bcs @lives
@r:
	rts
@score:
	lda #$22                ; rangée 1, colonne 2 : $2022
	sta tmp+6
	lda #$20
	sta tmp+7
	lda #7
	jsr vbuf_alloc
	bcs @r
	ldy #0
:
	lda score,y
	ora #$30
	sta vbuf,x
	inx
	iny
	cpy #7
	bne :-
	lda hud_dirty
	and #<~HUD_SCORE
	sta hud_dirty
	rts
@combo:
	lda #$48                ; rangée 2, colonne 8 : $2048
	sta tmp+6
	lda #$20
	sta tmp+7
	lda #2
	jsr vbuf_alloc
	bcs @r
	stx tmp+0
	lda combo
	jsr two_digits
	ldx tmp+0
	lda tmp+2
	sta vbuf,x
	lda tmp+3
	sta vbuf+1,x
	lda hud_dirty
	and #<~HUD_COMBO
	sta hud_dirty
	rts
@msg:
	lda msg_id
	ldx #12
	ldy #2
	jsr vprint_at
	bcs @r
	lda hud_dirty
	and #<~HUD_MSG
	sta hud_dirty
	rts
@lives:
	lda #$2C                ; rangée 1, colonne 12 : $202C
	sta tmp+6
	lda #$20
	sta tmp+7
	lda #1
	jsr vbuf_alloc
	bcs @r
	lda lives
	ora #$30
	sta vbuf,x
	lda hud_dirty
	and #<~HUD_LIVES
	sta hud_dirty
	rts

hud_draw_score_direct:
	lda #$20
	sta PPUADDR
	lda #$22
	sta PPUADDR
	ldx #0
:
	lda score,x
	ora #$30
	sta PPUDATA
	inx
	cpx #7
	bne :-
	rts

hud_lives_direct:
	lda #$20
	sta PPUADDR
	lda #$2C
	sta PPUADDR
	lda lives
	ora #$30
	sta PPUDATA
	rts

hud_combo_direct:
	lda #$20
	sta PPUADDR
	lda #$48
	sta PPUADDR
	lda #$30
	sta PPUDATA
	sta PPUDATA
	rts

; ------------------------------------------------------------- palettes
; Fond : 0 HUD, 1 ciel et hôtels (pêche $37), 2 mer et palmes, 3 sable
; (jaune pâle $38, différent de la peau des sprites $37). Sprites : héros,
; moustachu rose, menthe (et imprudents, motards), effets.
pal_level1:
	.byte $25,$30,$0F,$16, $25,$13,$27,$37, $25,$01,$21,$1A, $25,$38,$17,$16
	.byte $25,$37,$12,$0F, $25,$37,$35,$0F, $25,$37,$3A,$0F, $25,$16,$27,$30
; Palette 1 des écrans : l'orange du ciel devient noir, pour que le soleil
; du titre n'ait pas de halo carré (seul le titre utilise cette palette).
pal_screens:
	.byte $0F,$30,$0F,$16, $0F,$13,$0F,$38, $0F,$01,$21,$1A, $0F,$28,$0F,$16
	.byte $0F,$37,$12,$0F, $0F,$37,$35,$0F, $0F,$37,$3A,$0F, $0F,$16,$27,$30
; Écran titre (voir tools/gen_title.py) : textes, ciel/soleil/plage,
; chrome et mer, néon « III » et MAXIMUM JUSTICE. Sprites comme en jeu.
pal_title:
	.byte $0F,$30,$0F,$10, $0F,$14,$27,$38, $0F,$01,$21,$30, $0F,$28,$0F,$15
	.byte $0F,$37,$12,$0F, $0F,$37,$35,$0F, $0F,$37,$3A,$0F, $0F,$16,$27,$30
