; Moteur audio maison : bruitages + musique, 2A03 uniquement.
; Appelé dans la NMI (audio_update). La boucle principale ne fait que des
; demandes d'un octet (sfx_play, music_play) : aucune course possible.
;
; Musique : carré 1 (mélodie), carré 2 (arpèges, cédé aux bruitages),
; triangle (basse), bruit (batterie, cédé aux bruitages).
; Format d'une piste :
;   0-62  note (voir notes.inc)     63  silence
;   $80+d durée des notes suivantes (d trames)
;   $F0 v volume/rapport cyclique (valeur du registre $4000)
;   $FE   fin                        $FF lo hi  saut (boucle)

.include "notes.inc"

SFX_SHOT   = 1
SFX_SPLAT  = 2
SFX_BOOM   = 3
SFX_HIT    = 4
SFX_JUMP   = 5
SFX_ESHOT  = 6
SFX_DEATH  = 7
SFX_BIKE   = 8
SFX_MENU   = 9
SFX_SELECT = 10
SFX_MAX    = 11
SFX_FIRST_PULSE = SFX_JUMP

MUS_NONE  = 0
MUS_TITLE = 1
MUS_LEVEL = 2
MUS_CLEAR = 3

.segment "BSS"
sfx_n_ptr:  .res 2     ; bruitage en cours sur le canal de bruit (0 = aucun)
sfx_n_pri:  .res 1
sfx_p_ptr:  .res 2     ; bruitage en cours sur le carré 2
sfx_p_pri:  .res 1
mus_on:     .res 1
; pistes : 0 = carré 1, 1 = carré 2, 2 = triangle, 3 = bruit
tr_ptr_lo:  .res 4
tr_ptr_hi:  .res 4
tr_timer:   .res 4
tr_dur:     .res 4
tr_vol:     .res 4
tr_env:     .res 4     ; volume courant (enveloppe)
tr_note:    .res 4
tr_lasthi:  .res 4
drum_ptr:   .res 2     ; son de batterie en cours

.segment "FIXED"

audio_init:
	lda #$0F
	sta SND_CHN
	lda #$30
	sta SQ1_VOL
	sta SQ2_VOL
	sta NOISE_VOL
	lda #$80
	sta TRI_LINEAR
	lda #$08                ; balayage désactivé (évite le silence des notes graves)
	sta SQ1_SWEEP
	sta SQ2_SWEEP
	lda #0
	sta mus_on
	sta sfx_n_ptr+1
	sta sfx_p_ptr+1
	sta drum_ptr+1
	rts

; A = bruitage (appel depuis la boucle principale)
sfx_play:
	cmp #SFX_FIRST_PULSE
	bcs :+
	sta sfx_req_n
	rts
:
	sta sfx_req_p
	rts

; A = morceau (MUS_*)
music_play:
	clc
	adc #1
	sta mus_req
	rts

; ------------------------------------------------------------------ NMI
audio_update:
	lda mus_req
	beq :+
	jsr music_start
	lda #0
	sta mus_req
:
	lda sfx_req_n
	beq :+
	jsr sfx_start_n
	lda #0
	sta sfx_req_n
:
	lda sfx_req_p
	beq :+
	jsr sfx_start_p
	lda #0
	sta sfx_req_p
:
	lda mus_on
	beq :+
	jsr music_tick
:
	jsr sfx_tick_n
	jmp sfx_tick_p

sfx_start_n:
	tax
	lda sfx_pri,x
	ldy sfx_n_ptr+1
	beq :+
	cmp sfx_n_pri
	bcc @no
:
	sta sfx_n_pri
	lda sfx_lo,x
	sta sfx_n_ptr
	lda sfx_hi,x
	sta sfx_n_ptr+1
@no:
	rts

sfx_start_p:
	tax
	lda sfx_pri,x
	ldy sfx_p_ptr+1
	beq :+
	cmp sfx_p_pri
	bcc @no
:
	sta sfx_p_pri
	lda sfx_lo,x
	sta sfx_p_ptr
	lda sfx_hi,x
	sta sfx_p_ptr+1
	lda #$FF                ; forcer la réécriture de la période haute
	sta tr_lasthi+1
@no:
	rts

; Bruitage sur le canal de bruit : [volume, période]... $FF
sfx_tick_n:
	lda sfx_n_ptr+1
	beq @drum
	sta au_ptr+1
	lda sfx_n_ptr
	sta au_ptr
	ldy #0
	lda (au_ptr),y
	cmp #$FF
	beq @end
	sta NOISE_VOL
	iny
	lda (au_ptr),y
	sta NOISE_LO
	lda #$08
	sta NOISE_HI
	lda sfx_n_ptr
	clc
	adc #2
	sta sfx_n_ptr
	bcc :+
	inc sfx_n_ptr+1
:
	rts
@end:
	lda #0
	sta sfx_n_ptr+1
	lda #$30
	sta NOISE_VOL
	rts
@drum:
	; pas de bruitage : la batterie de la musique
	lda drum_ptr+1
	beq @r
	sta au_ptr+1
	lda drum_ptr
	sta au_ptr
	ldy #0
	lda (au_ptr),y
	cmp #$FF
	beq @dend
	sta NOISE_VOL
	iny
	lda (au_ptr),y
	sta NOISE_LO
	lda #$08
	sta NOISE_HI
	lda drum_ptr
	clc
	adc #2
	sta drum_ptr
	bcc @r
	inc drum_ptr+1
@r:
	rts
@dend:
	lda #0
	sta drum_ptr+1
	lda #$30
	sta NOISE_VOL
	rts

; Bruitage sur le carré 2 : [volume, période basse, période haute]... $FF
sfx_tick_p:
	lda sfx_p_ptr+1
	beq @r
	sta au_ptr+1
	lda sfx_p_ptr
	sta au_ptr
	ldy #0
	lda (au_ptr),y
	cmp #$FF
	beq @end
	sta SQ2_VOL
	iny
	lda (au_ptr),y
	sta SQ2_LO
	iny
	lda (au_ptr),y
	sta SQ2_HI
	lda sfx_p_ptr
	clc
	adc #3
	sta sfx_p_ptr
	bcc @r
	inc sfx_p_ptr+1
@r:
	rts
@end:
	lda #0
	sta sfx_p_ptr+1
	lda #$30
	sta SQ2_VOL
	lda #$FF
	sta tr_lasthi+1
	rts

; --------------------------------------------------------------- musique
music_start:
	sec
	sbc #1
	sta mus_on
	lda #$30
	sta SQ1_VOL
	sta SQ2_VOL
	lda #$80
	sta TRI_LINEAR
	lda #0
	sta drum_ptr+1
	lda mus_on
	beq @r
	asl a
	asl a
	asl a                   ; 8 octets par morceau
	tay
	ldx #0
@l:
	lda songs-8,y
	sta tr_ptr_lo,x
	lda songs-7,y
	sta tr_ptr_hi,x
	lda #1
	sta tr_timer,x
	lda #12
	sta tr_dur,x
	lda #$BF
	sta tr_vol,x
	lda #$FF
	sta tr_lasthi,x
	iny
	iny
	inx
	cpx #4
	bne @l
@r:
	rts

music_tick:
	ldx #0
@track:
	lda tr_ptr_hi,x
	beq @next
	dec tr_timer,x
	bne @env
	jsr track_read
	jmp @next
@env:
	; enveloppe : le volume baisse d'un cran toutes les 4 trames (carrés)
	cpx #2
	bcs @next
	lda tr_timer,x
	and #3
	bne @next
	lda tr_env,x
	and #$0F
	cmp #3
	bcc @next
	dec tr_env,x
	jsr write_vol
@next:
	inx
	cpx #4
	bne @track
	rts

; Lit les commandes de la piste X jusqu'à une note ou un silence.
track_read:
	lda tr_ptr_lo,x
	sta au_ptr
	lda tr_ptr_hi,x
	sta au_ptr+1
	ldy #0
@cmd:
	lda (au_ptr),y
	iny
	cmp #$FF
	beq @jump
	cmp #$FE
	beq @stop
	cmp #$F0
	beq @vol
	cmp #$80
	bcc @note
	and #$7F
	sta tr_dur,x
	jmp @cmd
@vol:
	lda (au_ptr),y
	iny
	sta tr_vol,x
	jmp @cmd
@jump:
	lda (au_ptr),y
	pha
	iny
	lda (au_ptr),y
	sta au_ptr+1
	pla
	sta au_ptr
	ldy #0
	jmp @cmd
@stop:
	lda #0
	sta tr_ptr_hi,x
	jmp silence_track
@note:
	sta tr_note,x
	tya
	clc
	adc au_ptr
	sta tr_ptr_lo,x
	lda au_ptr+1
	adc #0
	sta tr_ptr_hi,x
	lda tr_dur,x
	sta tr_timer,x
	lda tr_note,x
	cmp #N_REST
	beq silence_track
	cpx #3
	beq @drum
	lda tr_vol,x
	sta tr_env,x
	cpx #2
	beq @tri
	jsr write_vol
	jmp write_period
@tri:
	lda #$FF
	sta TRI_LINEAR
	ldy tr_note,x
	lda note_lo,y
	sta TRI_LO
	lda note_hi,y
	sta TRI_HI
	rts
@drum:
	ldy tr_note,x
	lda drum_lo-1,y
	sta drum_ptr
	lda drum_hi-1,y
	sta drum_ptr+1
	rts

silence_track:
	cpx #2
	beq @tri
	cpx #3
	beq @r
	lda tr_vol,x
	and #$C0
	ora #$30
	sta tr_env,x
	jmp write_vol
@tri:
	lda #$80
	sta TRI_LINEAR
	lda #0
	sta TRI_HI
@r:
	rts

; Volume de la piste carrée X (sauf si un bruitage occupe le carré 2)
write_vol:
	lda tr_env,x
	cpx #1
	beq :+
	sta SQ1_VOL
	rts
:
	ldy sfx_p_ptr+1
	bne :+
	sta SQ2_VOL
:
	rts

write_period:
	ldy tr_note,x
	cpx #1
	beq @sq2
	lda note_lo,y
	sta SQ1_LO
	lda note_hi,y
	cmp tr_lasthi,x
	beq :+
	sta tr_lasthi,x
	sta SQ1_HI
:
	rts
@sq2:
	lda sfx_p_ptr+1
	bne @r
	lda note_lo,y
	sta SQ2_LO
	lda note_hi,y
	cmp tr_lasthi,x
	beq @r
	sta tr_lasthi,x
	sta SQ2_HI
@r:
	rts

; --------------------------------------------------------------- données
sfx_lo:
	.byte 0, <sfx_shot, <sfx_splat, <sfx_boom, <sfx_hit, <sfx_jump, <sfx_eshot
	.byte <sfx_death, <sfx_bike, <sfx_menu, <sfx_select, <sfx_max
sfx_hi:
	.byte 0, >sfx_shot, >sfx_splat, >sfx_boom, >sfx_hit, >sfx_jump, >sfx_eshot
	.byte >sfx_death, >sfx_bike, >sfx_menu, >sfx_select, >sfx_max
sfx_pri:
	.byte 0, 1, 3, 5, 2, 2, 1, 6, 3, 2, 3, 7

sfx_shot:
	.byte $38,$03, $35,$04, $33,$05, $31,$06, $FF
sfx_hit:
	.byte $38,$02, $35,$03, $32,$04, $FF
sfx_splat:
	.byte $3F,$06, $3D,$07, $3C,$08, $3A,$09, $38,$0A, $36,$0A, $34,$0B, $33,$0B, $32,$0C, $31,$0C, $FF
sfx_boom:
	.byte $3F,$0C, $3F,$0D, $3F,$0D, $3E,$0D, $3E,$0E, $3D,$0E, $3C,$0E, $3B,$0E
	.byte $3A,$0F, $39,$0F, $38,$0F, $37,$0F, $36,$0F, $35,$0F, $35,$0F, $34,$0F
	.byte $34,$0F, $33,$0F, $33,$0F, $32,$0F, $32,$0F, $31,$0F, $31,$0F, $FF
sfx_jump:
	.byte $B8,$80,$01, $B7,$60,$01, $B6,$40,$01, $B5,$20,$01, $B4,$00,$01, $B3,$F0,$00, $B2,$E0,$00, $FF
sfx_eshot:
	.byte $76,$90,$00, $75,$B0,$00, $74,$D0,$00, $73,$F0,$00, $72,$10,$01, $FF
sfx_death:
	.byte $BA,$00,$01, $BA,$20,$01, $B9,$40,$01, $B9,$60,$01, $B8,$80,$01, $B8,$A0,$01
	.byte $B7,$C0,$01, $B7,$E0,$01, $B6,$00,$02, $B6,$40,$02, $B5,$80,$02, $B5,$C0,$02
	.byte $B4,$00,$03, $B4,$40,$03, $B3,$80,$03, $B3,$C0,$03, $B2,$00,$04, $B2,$40,$04, $FF
sfx_bike:
	.byte $36,$00,$05, $36,$80,$04, $37,$00,$05, $37,$60,$04, $37,$C0,$04, $36,$40,$04
	.byte $36,$A0,$04, $35,$20,$04, $35,$80,$04, $34,$00,$04, $33,$60,$04, $32,$C0,$03, $FF
sfx_menu:
	.byte $B6,$A0,$00, $B4,$A0,$00, $B2,$A0,$00, $FF
sfx_select:
	.byte $B8,$70,$00, $B8,$70,$00, $B7,$70,$00, $B8,$54,$00, $B7,$54,$00, $B6,$54,$00, $B4,$54,$00, $B2,$54,$00, $FF
sfx_max:
	.byte $BC,$D5,$00, $BC,$D5,$00, $BC,$A9,$00, $BC,$A9,$00, $BC,$8E,$00, $BC,$8E,$00
	.byte $BB,$6A,$00, $BB,$6A,$00, $BB,$6A,$00, $BA,$6A,$00, $B9,$6A,$00, $B8,$6A,$00
	.byte $B7,$6A,$00, $B6,$6A,$00, $B5,$6A,$00, $B4,$6A,$00, $B3,$6A,$00, $B2,$6A,$00, $FF

; batterie : 1 grosse caisse, 2 caisse claire, 3 charleston
drum_lo:
	.byte <drum_kick, <drum_snare, <drum_hat
drum_hi:
	.byte >drum_kick, >drum_snare, >drum_hat
drum_kick:
	.byte $3C,$0D, $3A,$0E, $36,$0E, $33,$0F, $FF
drum_snare:
	.byte $3B,$05, $39,$06, $37,$06, $35,$07, $33,$07, $31,$08, $FF
drum_hat:
	.byte $34,$01, $31,$01, $FF

; Morceaux : 4 pointeurs (carré 1, carré 2, triangle, bruit)
songs:
	.word title_sq1, title_sq2, title_tri, title_drm
	.word level_sq1, level_sq2, level_tri, level_drm
	.word clear_sq1, clear_sq2, clear_tri, clear_drm

.macro DUR d
	.byte $80 | (d)
.endmacro
.macro VOL v
	.byte $F0, v
.endmacro
.macro LOOP l
	.byte $FF, <l, >l
.endmacro
.macro ARP4 n1, n2, n3, n4
	.byte n1, n2, n3, n4
.endmacro

; ------------------------------------------------ THÈME DU TITRE (La mineur)
title_sq1:
	VOL $B9
	DUR 96
	.byte N_REST
@loop:
	DUR 24
	.byte N_E5, N_A4
	DUR 48
	.byte N_C5
	DUR 24
	.byte N_F5, N_E5
	DUR 48
	.byte N_C5
	DUR 24
	.byte N_E5, N_G5
	DUR 36
	.byte N_E5
	DUR 12
	.byte N_D5
	DUR 72
	.byte N_D5
	DUR 24
	.byte N_REST
	LOOP @loop
title_sq2:
	VOL $34
	DUR 6
@loop:
	.repeat 4
	ARP4 N_A3, N_C4, N_E4, N_A4
	.endrep
	.repeat 4
	ARP4 N_F3, N_A3, N_C4, N_F4
	.endrep
	.repeat 4
	ARP4 N_C4, N_E4, N_G4, N_C5
	.endrep
	.repeat 4
	ARP4 N_G3, N_B3, N_D4, N_G4
	.endrep
	LOOP @loop
title_tri:
	DUR 24
@loop:
	.byte N_A3, N_A3, N_A4, N_A3
	.byte N_F3, N_F3, N_F4, N_F3
	.byte N_C4, N_C4, N_C5, N_C4
	.byte N_G3, N_G3, N_G4, N_G3
	LOOP @loop
title_drm:
	DUR 96
	.byte N_REST
	DUR 24
@loop:
	.byte 1, 3, 2, 3
	LOOP @loop

; ------------------------------------------- THÈME DU NIVEAU (Mi mineur)
level_sq1:
	VOL $BA
@loop:
	DUR 24
	.byte N_B4
	DUR 12
	.byte N_G4, N_A4
	DUR 24
	.byte N_B4, N_D5
	.byte N_C5
	DUR 12
	.byte N_B4, N_A4
	DUR 24
	.byte N_G4, N_E4
	.byte N_FS4, N_A4, N_D5
	DUR 12
	.byte N_C5, N_B4
	DUR 72
	.byte N_B4
	DUR 12
	.byte N_A4, N_B4
	; variation
	DUR 12
	.byte N_E5, N_REST, N_E5, N_D5, N_B4, N_REST, N_G4, N_A4
	.byte N_C5, N_REST, N_C5, N_B4, N_A4, N_REST, N_G4, N_E4
	.byte N_D5, N_REST, N_D5, N_C5, N_A4, N_REST, N_FS4, N_A4
	DUR 48
	.byte N_B4
	DUR 24
	.byte N_DS5, N_FS5
	LOOP @loop
level_sq2:
	VOL $33
	DUR 6
@loop:
	.repeat 2
	.repeat 4
	ARP4 N_E4, N_G4, N_B4, N_E5
	.endrep
	.repeat 4
	ARP4 N_C4, N_E4, N_G4, N_C5
	.endrep
	.repeat 4
	ARP4 N_D4, N_FS4, N_A4, N_D5
	.endrep
	.repeat 4
	ARP4 N_B3, N_DS4, N_FS4, N_B4
	.endrep
	.endrep
	LOOP @loop
level_tri:
	DUR 12
@loop:
	.repeat 2
	.byte N_E3, N_E3, N_E4, N_E3, N_E3, N_E4, N_E3, N_D3
	.byte N_C3, N_C3, N_C4, N_C3, N_C3, N_C4, N_C3, N_D3
	.byte N_D3, N_D3, N_D4, N_D3, N_D3, N_D4, N_D3, N_FS3
	.byte N_B2, N_B2, N_B3, N_B2, N_B2, N_B3, N_CS3, N_DS3
	.endrep
	LOOP @loop
level_drm:
	DUR 12
@loop:
	.byte 1, 3, 2, 3, 1, 1, 2, 3
	LOOP @loop

; --------------------------------------------- JINGLE DE FIN DE NIVEAU
clear_sq1:
	VOL $BC
	DUR 8
	.byte N_C5, N_E5, N_G5, N_C5, N_E5, N_G5
	DUR 16
	.byte N_C6
	DUR 8
	.byte N_AS5, N_A5, N_AS5
	DUR 64
	.byte N_C6
	.byte $FE
clear_sq2:
	VOL $B6
	DUR 8
	.byte N_G4, N_C5, N_E5, N_G4, N_C5, N_E5
	DUR 16
	.byte N_E5
	DUR 8
	.byte N_F5, N_F5, N_F5
	DUR 64
	.byte N_E5
	.byte $FE
clear_tri:
	DUR 16
	.byte N_C4, N_C4, N_C4
	DUR 8
	.byte N_C4
	.byte N_AS3, N_AS3, N_AS3
	DUR 64
	.byte N_C4
	.byte $FE
clear_drm:
	DUR 8
	.byte 1, 3, 2, 3, 1, 3
	DUR 16
	.byte 2
	DUR 8
	.byte 2, 2, 2
	DUR 64
	.byte 1
	.byte $FE
