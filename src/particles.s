; Gerbes de fragments de pixels et taches de sang.

GRAV_PART  = $30
PT_BOUNCED = $10       ; bit d'attribut ignoré par le PPU, sert de drapeau
GIB_BUDGET = 16        ; fragments créés au maximum par trame (évite tout ralentissement)

.segment "CODE"

; Crée A fragments en (gib_xl/gib_xh, gib_y).
spawn_gibs:
	cmp gib_budget
	bcc :+
	lda gib_budget
:
	sta gib_n
	jeq @done
	lda gib_budget
	sec
	sbc gib_n
	sta gib_budget
	; litres de sang (un fragment = un litre, c'est scientifique)
	lda gib_n
	clc
	adc stat_blood
	sta stat_blood
	bcc :+
	inc stat_blood+1
:
@loop:
	lda pt_next
	clc
	adc #1
	and #MAX_PART-1
	sta pt_next
	tax
	lda gib_xl
	sta pt_xl,x
	lda gib_xh
	sta pt_xh,x
	lda gib_y
	sta pt_y,x
	jsr rand
	sta pt_vxl,x
	sta pt_xs,x
	and #$1F
	adc #70
	sta pt_life,x
	lda pt_vxl,x
	and #3
	sec
	sbc #2                  ; vitesse x : -2 .. +2
	sta pt_vxh,x
	jsr rand
	sta pt_vyl,x
	sta pt_ys,x
	lsr a
	lsr a
	and #3
	eor #$FF
	sec
	sbc #1                  ; vitesse y : -5 .. -2
	sta pt_vyh,x
	lda pt_vyl,x
	cmp #$40                ; un quart des fragments : objet absurde
	bcs @gib
	and #3
	ldy gib_kind
	clc
	adc kind_obj_ofs,y
	tay
	lda obj_tiles,y
	sta pt_tile,x
	lda gib_pal
	sta pt_attr,x
	jmp @next
@gib:
	lsr a
	lsr a
	lsr a
	lsr a
	and #7
	tay
	lda gib_tiles,y
	sta pt_tile,x
	lda #3
	sta pt_attr,x
@next:
	dec gib_n
	bne @loop
@done:
	rts

gib_tiles:
	.byte SPR_GIB1, SPR_GIB2, SPR_GIB3, SPR_GIB4, SPR_GIB5, SPR_GIBW, SPR_GIB1, SPR_GIB4
; décalage dans obj_tiles selon le type (index = ENT_*)
kind_obj_ofs:
	.byte 0, 0, 0, 4, 8, 8, 12, 0, 0, 0, 0, 16
obj_tiles:
	.byte SPR_O_MOUSTACHE, SPR_O_GLASSES, SPR_O_CASSETTE, SPR_O_MOUSTACHE   ; moustachus
	.byte SPR_SHURIKEN1, SPR_O_SUSHI, SPR_O_SUSHI, SPR_SHURIKEN2           ; ninjas
	.byte SPR_O_CHAIN, SPR_O_CHAIN, SPR_O_SHOE, SPR_O_GLASSES              ; motards
	.byte SPR_O_CAP, SPR_O_SHOE, SPR_O_DUCK, SPR_O_CAP                      ; imprudents
	.byte SPR_O_GLASSES, SPR_O_CASSETTE, SPR_O_DUCK, SPR_O_SHOE            ; héros

update_particles:
	lda #GIB_BUDGET
	sta gib_budget
	ldx #MAX_PART-1
@loop:
	lda pt_life,x
	bne :+
	jmp @next
:
	dec pt_life,x
	bne :+
	jmp @next
:
	lda pt_vyl,x
	clc
	adc #GRAV_PART
	sta pt_vyl,x
	lda pt_vyh,x
	adc #0
	sta pt_vyh,x
	lda pt_ys,x
	clc
	adc pt_vyl,x
	sta pt_ys,x
	lda pt_y,x
	adc pt_vyh,x
	sta pt_y,x
	cmp #236
	jcs @kill
	lda pt_xs,x
	clc
	adc pt_vxl,x
	sta pt_xs,x
	lda pt_xl,x
	adc pt_vxh,x
	sta pt_xl,x
	lda pt_vxh,x
	and #$80
	beq :+
	lda #$FF
:
	adc pt_xh,x
	sta pt_xh,x
	; collisions : seulement en descendant, une trame sur deux
	lda pt_vyh,x
	jmi @next
	txa
	eor frame
	and #1
	jne @next
	lda pt_xl,x
	sta cl_xl
	lda pt_xh,x
	sta cl_xh
	lda pt_y,x
	clc
	adc #2
	sta cl_y
	jsr get_coll
	cmp #COLL_WATER
	beq @kill
	cmp #COLL_EMPTY
	beq @next
	; sol ou plateforme : haut de la métatuile
	lda cl_y
	sec
	sbc #32
	and #$F0
	clc
	adc #32
	sta tmp+0
	lda pt_attr,x
	and #PT_BOUNCED
	bne @land
	; premier contact : rebond
	lda pt_attr,x
	ora #PT_BOUNCED
	sta pt_attr,x
	lda tmp+0
	sec
	sbc #3
	sta pt_y,x
	lda pt_vyl,x            ; vy = -vy / 2
	eor #$FF
	sta pt_vyl,x
	lda pt_vyh,x
	eor #$FF
	cmp #$80
	ror a
	sta pt_vyh,x
	ror pt_vyl,x
	lda pt_vxh,x            ; vx = vx / 2
	cmp #$80
	ror a
	sta pt_vxh,x
	ror pt_vxl,x
	jmp @next
@land:
	; second contact : tache (à partir du palier 1), puis disparition
	lda tier
	beq @kill
	lda pt_attr,x
	and #3
	cmp #3
	bne @kill               ; les objets absurdes ne tachent pas
	lda tmp+0
	clc
	adc #1
	sta cl_y
	jsr add_stain
@kill:
	lda #0
	sta pt_life,x
@next:
	dex
	bmi :+
	jmp @loop
:
	rts

draw_particles:
	lda pt_rot
	clc
	adc #11
	and #MAX_PART-1
	sta pt_rot
	tax
	lda oam_full
	bne @done
	lda #MAX_PART
	sta gib_n
	ldy oam_idx             ; Y = position dans l'OAM (boucle sans sous-programme)
@loop:
	lda pt_life,x
	beq @next
	cmp #12                 ; clignote juste avant de disparaître
	bcs @vis
	lda frame
	lsr a
	bcs @next
@vis:
	lda pt_xl,x
	sec
	sbc cam_xl
	sta tmp
	lda pt_xh,x
	sbc cam_xh
	bne @next
	lda pt_y,x
	cmp #224
	bcs @next
	cmp #24
	bcc @next
	sbc #1                  ; carry mis : y - 1 pour l'OAM
	sta oam,y
	lda pt_tile,x
	sta oam+1,y
	lda pt_attr,x
	sta oam+2,y
	lda tmp
	sta oam+3,y
	iny
	iny
	iny
	iny
	beq @full
@next:
	inx
	txa
	and #MAX_PART-1
	tax
	dec gib_n
	bne @loop
	sty oam_idx
@done:
	rts
@full:
	sty oam_idx
	lda #1
	sta oam_full
	rts
