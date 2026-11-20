; Niveau : colonnes de décor, collisions, caméra.
;
; Données : une colonne = 16 octets (13 métatuiles + 3 de remplissage), en
; $8000 (banque 0). Colonne c -> level1_map + c*16.

LEVEL_ROWS = 13
CAM_MAX    = (LEVEL1_COLS - 16) * 16

COLL_EMPTY = 0
COLL_SOLID = 1
COLL_PLAT  = 2
COLL_WATER = 3

.segment "CODE"

; Prépare la colonne A pour l'envoi pendant le VBlank (col_pending = 1).
; Met aussi à jour la copie de la table de noms en PRG-RAM.
prepare_column:
	sta tmp+0
	asl a
	asl a
	asl a
	asl a
	sta ptr1
	lda tmp+0
	lsr a
	lsr a
	lsr a
	lsr a
	clc
	adc #>level1_map
	sta ptr1+1
	lda tmp+0
	and #31
	sta tmp+1               ; emplacement dans les tables de noms (0-31)
	and #16
	lsr a
	lsr a
	ora #$20
	sta col_addr_hi         ; $20 ou $24
	ora #$03
	sta col_attr_hi         ; $23 ou $27
	lda tmp+1
	and #15
	asl a
	ora #$80                ; rangée de tuiles 4
	sta col_addr_lo
	lda tmp+1
	and #15
	lsr a
	sta col_attr_x
	; copie en PRG-RAM : nt_shadow + emplacement*64 + 4
	lda tmp+1
	lsr a
	lsr a
	clc
	adc #>nt_shadow
	sta ptr2+1
	lda tmp+1
	and #3
	tax
	lda shift6_tab,x
	ora #4
	sta ptr2
	; tuiles
	ldy #0
	ldx #0
@row:
	sty tmp+2
	lda (ptr1),y
	tay
	lda mt_tl,y
	sta col_left,x
	lda mt_bl,y
	sta col_left+1,x
	lda mt_tr,y
	sta col_right,x
	lda mt_br,y
	sta col_right+1,x
	inx
	inx
	ldy tmp+2
	iny
	cpy #LEVEL_ROWS
	bne @row
	ldy #25
@sh1:
	lda col_left,y
	sta (ptr2),y
	dey
	bpl @sh1
	lda ptr2
	clc
	adc #32
	sta ptr2
	ldy #25
@sh2:
	lda col_right,y
	sta (ptr2),y
	dey
	bpl @sh2
	; attributs : colonne paire (ptr1) et impaire (ptr1+16)
	lda ptr1
	and #$EF
	sta ptr1
	lda #0
	sta tmp+3
	ldy #0
@attr:
	sty tmp+2               ; rangée A (haut du bloc 32x32)
	iny
	tya
	ora #$10
	tay
	lda (ptr1),y            ; impaire, rangée B -> bas droite
	tax
	lda mt_pal,x
	asl a
	asl a
	sta tmp+4
	ldy tmp+2
	iny
	lda (ptr1),y            ; paire, rangée B -> bas gauche
	tax
	lda mt_pal,x
	ora tmp+4
	asl a
	asl a
	sta tmp+4
	lda tmp+2
	ora #$10
	tay
	lda (ptr1),y            ; impaire, rangée A -> haut droite
	tax
	lda mt_pal,x
	ora tmp+4
	asl a
	asl a
	sta tmp+4
	ldy tmp+2
	lda (ptr1),y            ; paire, rangée A -> haut gauche
	tax
	lda mt_pal,x
	ora tmp+4
	ldx tmp+3
	sta col_attr,x
	inx
	stx tmp+3
	iny
	iny
	cpx #7
	bne @attr
	lda #1
	sta col_pending
	rts

shift6_tab:
	.byte $00, $40, $80, $C0

; Type de collision au point (cl_xl/cl_xh, cl_y). Résultat dans A.
; Préserve X.
get_coll:
	lda cl_y
	sec
	sbc #32
	bcc @empty
	cmp #LEVEL_ROWS*16
	bcs @empty
	lsr a
	lsr a
	lsr a
	lsr a
	tay
	lda cl_xh
	cmp #(LEVEL1_COLS / 16)
	bcs @empty              ; hors du niveau (ou négatif)
	adc #>level1_map
	sta cl_ptr+1
	lda cl_xl
	and #$F0
	sta cl_ptr
	lda (cl_ptr),y
	tay
	lda mt_coll,y
	rts
@empty:
	lda #COLL_EMPTY
	rts

; Charge l'écran de départ (rendu coupé) : colonnes 0 à 17.
load_level_start:
	lda #0
	sta cam_xl
	sta cam_xh
	sta cam_col
	sta next_col
@l:
	lda next_col
	jsr prepare_column
	jsr upload_column
	inc next_col
	lda next_col
	cmp #18
	bne @l
	rts

; Avance la caméra pour suivre le héros, et prépare une colonne si besoin.
camera_update:
	lda p_xl
	sec
	sbc cam_xl
	sta tmp
	lda p_xh
	sbc cam_xh
	bne @stream
	lda tmp
	cmp #120
	bcc @stream
	sbc #120
	cmp #3
	bcc :+
	lda #3
:
	clc
	adc cam_xl
	sta cam_xl
	lda cam_xh
	adc #0
	sta cam_xh
	; plafond
	lda cam_xh
	cmp #>CAM_MAX
	bcc @col
	bne @cap
	lda cam_xl
	cmp #<CAM_MAX
	bcc @col
@cap:
	lda #<CAM_MAX
	sta cam_xl
	lda #>CAM_MAX
	sta cam_xh
@col:
	lda cam_xl
	lsr a
	lsr a
	lsr a
	lsr a
	sta tmp
	lda cam_xh
	asl a
	asl a
	asl a
	asl a
	ora tmp
	sta cam_col
@stream:
	lda col_pending
	bne @done
	lda next_col
	cmp #LEVEL1_COLS
	bcs @done
	lda cam_col
	clc
	adc #17
	cmp next_col
	bcc @done
	lda next_col
	jsr prepare_column
	inc next_col
@done:
	rts

; Calcule le défilement demandé (avec tremblement d'écran).
compute_scroll:
	lda cam_xl
	sta tmp
	lda cam_xh
	sta tmp+1
	lda shake
	beq @set
	dec shake
	lda frame
	and #2
	beq @set
	lda tmp
	clc
	adc #3
	sta tmp
	bcc @set
	inc tmp+1
@set:
	lda tmp
	sta scroll_x
	lda tmp+1
	and #1
	sta scroll_nt
	rts

; Tache de sang : la tuile sous le point (cl_xl/cl_xh, cl_y) devient sa
; variante plus tachée, si elle en a une et s'il reste de la place.
; Préserve X.
add_stain:
	lda cl_y
	cmp #32
	bcc @no
	cmp #240
	bcs @no
	lsr a
	lsr a
	lsr a
	sta tmp+2               ; ty (0-29)
	; tx = (x / 8) & 63
	lda cl_xh
	sta tmp+3
	lda cl_xl
	lsr tmp+3
	ror a
	lsr tmp+3
	ror a
	lsr tmp+3
	ror a
	and #63
	sta tmp+3               ; tx
	; adresse en PRG-RAM : nt_shadow + tx*32 + ty
	lsr a
	lsr a
	lsr a
	clc
	adc #>nt_shadow
	sta ptr2+1
	lda tmp+3
	asl a
	asl a
	asl a
	asl a
	asl a
	ora tmp+2
	sta ptr2
	ldy #0
	lda (ptr2),y
	tay
	lda stain_next,y
	beq @no
	sta tmp+1
	; adresse PPU : $2000 ou $2400 + ty*32 + (tx & 31)
	lda tmp+3
	and #32
	lsr a
	lsr a
	lsr a                   ; 0 ou 4
	sta tmp+7
	lda tmp+2
	lsr a
	lsr a
	lsr a
	ora #$20
	ora tmp+7
	sta tmp+7
	lda tmp+2
	asl a
	asl a
	asl a
	asl a
	asl a
	sta tmp+6
	lda tmp+3
	and #31
	ora tmp+6
	sta tmp+6
	txa
	pha
	lda #1
	jsr vbuf_alloc
	bcs @full
	lda tmp+1
	sta vbuf,x
	ldy #0
	sta (ptr2),y
@full:
	pla
	tax
@no:
	rts
