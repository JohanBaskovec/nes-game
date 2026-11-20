; Construction de la liste de sprites (OAM) avec priorités et rotation.

.segment "CODE"

; Dessine le métasprite ptr0 à (ms_xl/ms_xh, ms_y).
; Format : [dy, tuile, attributs, dx]... $80
draw_ms:
	lda oam_full
	bne @done
	ldy #0
@loop:
	ldx oam_idx
	lda (ptr0),y
	cmp #$80
	beq @done
	clc
	adc ms_y
	cmp #224
	bcs @skip
	cmp #24
	bcc @skip
	sbc #1                  ; (carry mis) : l'OAM attend y - 1
	sta oam,x
	iny
	lda (ptr0),y
	sta oam+1,x
	iny
	lda (ptr0),y
	eor ms_eor
	sta oam+2,x
	iny
	lda (ptr0),y
	bit ms_eor
	bvc :+
	eor #$FF                ; miroir : dx' = -dx - 8
	sec
	sbc #7
:
	sta ms_dx
	clc
	adc ms_xl
	sta oam+3,x
	lda #0
	bit ms_dx
	bpl :+
	lda #$FF
:
	adc ms_xh
	bne @next               ; hors écran horizontalement : on n'avance pas
	iny
	txa
	clc
	adc #4
	sta oam_idx
	bne @loop
	lda #1
	sta oam_full
@done:
	rts
@next:
	iny
	jmp @loop
@skip:
	iny
	iny
	iny
	iny
	jmp @loop

; Un seul sprite : A = tuile, ms_eor = attributs, (ms_xl/ms_xh, ms_y) = coin
; haut gauche. Préserve X.
draw_one:
	ldy oam_full
	bne @no
	ldy ms_xh
	bne @no
	ldy ms_y
	cpy #224
	bcs @no
	cpy #24
	bcc @no
	sty tmp+7
	ldy oam_idx
	sta oam+1,y
	lda tmp+7
	sec
	sbc #1
	sta oam,y
	lda ms_eor
	sta oam+2,y
	lda ms_xl
	sta oam+3,y
	tya
	clc
	adc #4
	sta oam_idx
	bne @no
	lda #1
	sta oam_full
@no:
	rts

; Construit toute l'OAM de l'écran de jeu.
build_oam:
	lda #0
	sta oam_idx
	sta oam_full
	jsr draw_player
	jsr draw_ebullets
	jsr draw_enemies
	jsr draw_pbullets
	jsr draw_particles
	lda oam_full
	bne :+
	jmp oam_finish
:
	rts

; Position écran d'une entité : A = x bas, Y = x haut -> ms_xl/ms_xh
to_screen:
	sec
	sbc cam_xl
	sta ms_xl
	tya
	sbc cam_xh
	sta ms_xh
	rts
