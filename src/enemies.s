; Ennemis : apparition, comportements, dégâts, barils et explosions.

ENT_NONE       = 0
ENT_MOU_ROSE   = 1
ENT_MOU_MENTHE = 2
ENT_NINJA      = 3
ENT_BIKER      = 4
ENT_BIKER_FOOT = 5
ENT_IMPRUDENT  = 6
ENT_BARREL     = 7
ENT_EXPLOSION  = 8
ENT_SMOKE      = 9
ENT_LEVEL_END  = 10
ENT_HERO       = 11    ; seulement pour choisir les objets des gerbes

.segment "CODE"

clear_entities:
	lda #0
	ldx #MAX_ENEMY-1
:
	sta e_type,x
	dex
	bpl :-
	ldx #MAX_EBUL-1
:
	sta eb_kind,x
	dex
	bpl :-
	ldx #MAX_PBUL-1
:
	sta pb_on,x
	dex
	bpl :-
	ldx #MAX_PART-1
:
	sta pt_life,x
	dex
	bpl :-
	rts

; Emplacement libre -> X, carry clair. Carry mis si aucun.
find_enemy_slot:
	ldx #MAX_ENEMY-1
@l:
	lda e_type,x
	beq @ok
	dex
	bpl @l
	sec
	rts
@ok:
	clc
	rts

; Crée un ennemi de type A dans l'emplacement X, à (tmp+0/tmp+1, tmp+2).
; Initialise les champs communs.
init_enemy:
	sta e_type,x
	lda tmp+0
	sta e_xl,x
	lda tmp+1
	sta e_xh,x
	lda tmp+2
	sta e_y,x
	lda #0
	sta e_state,x
	sta e_ys,x
	sta e_vx,x
	sta e_vyl,x
	sta e_vyh,x
	sta e_timer,x
	sta e_timer2,x
	sta e_hit,x
	sta e_ground,x
	sta e_doom,x
	sta e_pal,x
	lda #1
	sta e_hp,x
	jsr face_player
	ldy e_type,x
	lda type_init_lo,y
	sta ptr1
	lda type_init_hi,y
	sta ptr1+1
	jmp (ptr1)

; ------------------------------------------------------------ apparitions
spawn_update:
	lda level_done
	bne @done
@loop:
	ldy spawn_idx
	lda level1_spawns,y
	cmp #$FF
	beq @done
	sta tmp+3               ; colonne
	lda cam_col
	clc
	adc #16
	cmp tmp+3
	bcc @done               ; pas encore à l'écran
	; position : x = col*16 + 8, y = rangée*16 + 48
	lda tmp+3
	asl a
	asl a
	asl a
	asl a
	ora #8
	sta tmp+0
	lda tmp+3
	lsr a
	lsr a
	lsr a
	lsr a
	sta tmp+1
	lda level1_spawns+1,y
	asl a
	asl a
	asl a
	asl a
	clc
	adc #48
	sta tmp+2
	lda level1_spawns+2,y
	iny
	iny
	iny
	sty spawn_idx
	cmp #ENT_LEVEL_END
	bne @enemy
	lda tmp+0
	sta end_xl
	lda tmp+1
	sta end_xh
	jmp @loop
@enemy:
	cmp #ENT_BIKER
	bne :+
	pha                     ; les motards arrivent du bord droit
	lda cam_xl
	clc
	adc #8
	sta tmp+0
	lda cam_xh
	adc #1
	sta tmp+1
	pla
:
	pha
	jsr find_enemy_slot
	pla
	bcs @loop               ; plus de place : tant pis
	jsr init_enemy
	jmp @loop
@done:
	rts

; Les ninjas apparaissent régulièrement, n'importe où, sans explication.
ninja_spawner:
	lda level_done
	jne @no
	dec ninja_timer
	jne @no
	jsr rand
	and #$7F
	clc
	adc #150
	sta ninja_timer
	; deux ninjas maximum
	ldy #0
	ldx #MAX_ENEMY-1
:
	lda e_type,x
	cmp #ENT_NINJA
	bne :+
	iny
:
	dex
	bpl :--
	cpy #2
	bcs @no
	; x au hasard dans l'écran, loin du héros
	jsr rand
	and #$7F
	clc
	adc #64
	sta tmp+4               ; x écran 64..191
	clc
	adc cam_xl
	sta tmp+0
	lda cam_xh
	adc #0
	sta tmp+1
	lda tmp+0
	sec
	sbc p_xl
	lda tmp+1
	sbc p_xh
	bcc @left               ; ninja à gauche du héros
	lda tmp+0
	sec
	sbc p_xl
	cmp #48
	bcs @ground
	bcc @push
@left:
	lda p_xl
	sec
	sbc tmp+0
	cmp #48
	bcs @ground
@push:
	lda tmp+4
	cmp #128
	lda #64
	bcc :+
	lda #<-64
:
	sta tmp+5
	clc
	adc tmp+0
	sta tmp+0
	lda #0
	bit tmp+5
	bpl :+
	lda #$FF
:
	adc tmp+1
	sta tmp+1
@ground:
	; cherche un sol dans cette colonne
	lda tmp+0
	sta cl_xl
	lda tmp+1
	sta cl_xh
	lda #33
@scan:
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @found
	cmp #COLL_PLAT
	beq @found
	lda cl_y
	clc
	adc #16
	cmp #240
	bcc @scan
@no:
	rts
@found:
	lda cl_y
	sec
	sbc #1
	sta tmp+2
	cmp #48
	bcc @no
	jsr find_enemy_slot
	bcs @no
	lda #ENT_NINJA
	jmp init_enemy

; ------------------------------------------------------------- outils
; Tourne l'ennemi X vers le héros. A = 1 (droite) ou $FF (gauche).
face_player:
	lda p_xl
	sec
	sbc e_xl,x
	lda p_xh
	sbc e_xh,x
	bmi @left
	lda #0
	sta e_flip,x
	lda #1
	rts
@left:
	lda #$40
	sta e_flip,x
	lda #$FF
	rts

; Distance horizontale |héros - ennemi X| (plafonnée à 255) -> A
dist_x:
	lda p_xl
	sec
	sbc e_xl,x
	sta tmp+6
	lda p_xh
	sbc e_xh,x
	bmi @neg
	bne @far
	lda tmp+6
	rts
@neg:
	cmp #$FF
	bne @far
	lda tmp+6
	eor #$FF
	clc
	adc #1
	bne :+
	lda #255
:
	rts
@far:
	lda #255
	rts

; Carry mis si l'ennemi X est visible (x écran entre 8 et 247).
on_screen:
	lda e_xl,x
	sec
	sbc cam_xl
	sta tmp+6
	lda e_xh,x
	sbc cam_xh
	bne @no
	lda tmp+6
	cmp #8
	bcc @no
	cmp #248
	bcs @no
	sec
	rts
@no:
	clc
	rts

; Supprime l'ennemi X s'il est loin derrière ou loin devant la caméra.
despawn_check:
	lda e_xl,x
	sec
	sbc cam_xl
	sta tmp+6
	lda e_xh,x
	sbc cam_xh
	beq @ok
	cmp #1
	bne @kill               ; derrière la caméra ($FF) ou très loin
	lda tmp+6
	cmp #80                 ; jusqu'à 336 px devant
	bcc @ok
@kill:
	lda e_xh,x
	sec
	sbc cam_xh
	cmp #$FF
	bne @really
	lda tmp+6
	cmp #$E0                ; tolère 32 px à gauche
	bcs @ok
@really:
	lda #0
	sta e_type,x
@ok:
	rts

; Déplace l'ennemi X horizontalement de e_vx.
move_x:
	lda e_vx,x
	beq @r
	sta tmp+6
	clc
	adc e_xl,x
	sta e_xl,x
	lda #0
	bit tmp+6
	bpl :+
	lda #$FF
:
	adc e_xh,x
	sta e_xh,x
@r:
	rts

; Bloc solide devant l'ennemi X (dans le sens de e_vx) ? Carry mis si oui.
wall_ahead:
	lda e_vx,x
	bmi :+
	lda #7
	bne :++
:
	lda #<-7
:
	sta tmp+6
	clc
	adc e_xl,x
	sta cl_xl
	lda #0
	bit tmp+6
	bpl :+
	lda #$FF
:
	adc e_xh,x
	sta cl_xh
	lda e_y,x
	sec
	sbc #8
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @yes
	clc
	rts
@yes:
	sec
	rts

; Gravité et sol pour l'ennemi X.
enemy_fall:
	lda e_xl,x
	sta cl_xl
	lda e_xh,x
	sta cl_xh
	lda e_ground,x
	beq @air
	lda e_y,x
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	jeq @r
	cmp #COLL_PLAT
	jeq @r
	lda #0
	sta e_ground,x
	sta e_vyl,x
	sta e_vyh,x
@air:
	lda e_vyl,x
	clc
	adc #GRAVITY
	sta e_vyl,x
	lda e_vyh,x
	adc #0
	bmi :+
	cmp #4
	bcc :+
	lda #4
:
	sta e_vyh,x
	lda e_y,x
	sta tmp+5
	lda e_ys,x
	clc
	adc e_vyl,x
	sta e_ys,x
	lda e_y,x
	adc e_vyh,x
	sta e_y,x
	cmp #240
	bcc :+
	lda #0                  ; tombé dans le vide
	sta e_type,x
	rts
:
	lda e_vyh,x
	bmi @r
	lda e_y,x
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @land
	cmp #COLL_PLAT
	bne @r
@land:
	lda e_y,x
	sec
	sbc #32
	and #$F0
	clc
	adc #32
	sta tmp+4
	lda tmp+5
	cmp tmp+4
	beq :+
	bcs @r
:
	lda tmp+4
	sta e_y,x
	lda #0
	sta e_vyl,x
	sta e_vyh,x
	sta e_ys,x
	lda #1
	sta e_ground,x
@r:
	rts

; Tir ennemi depuis X : paramètres nb_*. Préserve X.
enemy_fire:
	ldy #MAX_EBUL-1
@l:
	lda eb_kind,y
	beq @got
	dey
	bpl @l
	rts
@got:
	lda nb_kind
	sta eb_kind,y
	lda e_xl,x
	sta eb_xl,y
	lda e_xh,x
	sta eb_xh,y
	lda e_y,x
	clc
	adc nb_dy
	sta eb_y,y
	lda #$80
	sta eb_xs,y
	sta eb_ys,y
	lda nb_vxl
	sta eb_vxl,y
	lda nb_vxh
	sta eb_vxh,y
	lda nb_vyl
	sta eb_vyl,y
	lda nb_vyh
	sta eb_vyh,y
	rts

; Tir horizontal vers l'avant à la vitesse 2 (balle), hauteur A.
fire_forward:
	sta nb_dy
	lda #0
	sta nb_vxl
	sta nb_vyl
	sta nb_vyh
	lda #2
	ldy e_flip,x
	beq :+
	lda #$FE
:
	sta nb_vxh
	lda #1
	sta nb_kind
	lda #SFX_ESHOT
	jsr sfx_play
	jmp enemy_fire

; Contact avec le héros (pour les ennemis qui se touchent).
contact_check:
	lda p_state
	bne @no
	jsr dist_x
	ldy e_type,x
	sec
	sbc hb_w,y
	bcc :+
	cmp #6
	bcs @no
:
	; vertical : les deux boîtes se chevauchent ?
	lda p_y
	sec
	sbc #24
	cmp e_y,x
	bcs @no                 ; tête du héros sous les pieds de l'ennemi
	lda e_y,x
	sec
	sbc hb_h,y
	cmp p_y
	bcs @no                 ; tête de l'ennemi sous les pieds du héros
	jmp player_hit
@no:
	rts

; ------------------------------------------------------------ mise à jour
update_enemies:
	ldx #MAX_ENEMY-1
@loop:
	lda e_type,x
	beq @next
	stx cur_slot
	lda e_hit,x
	beq :+
	dec e_hit,x
:
	lda e_doom,x            ; soufflé par une explosion
	beq @alive
	dec e_doom,x
	bne @alive
	jsr kill_enemy
	ldx cur_slot
	jmp @next
@alive:
	ldy e_type,x
	lda type_update_lo,y
	sta ptr1
	lda type_update_hi,y
	sta ptr1+1
	jsr @call
	ldx cur_slot
	lda e_type,x
	beq @next
	jsr despawn_check
@next:
	dex
	bpl @loop
	rts
@call:
	jmp (ptr1)

; --- Moustachu rose : court tout droit vers le héros, tire de temps en temps
init_rose:
	jsr face_player
	sta e_vx,x
	lda #40
	sta e_timer,x
	rts
upd_rose:
	jsr wall_ahead
	bcc :+
	lda e_vx,x
	eor #$FF
	clc
	adc #1
	sta e_vx,x
	lda e_flip,x
	eor #$40
	sta e_flip,x
:
	jsr move_x
	jsr enemy_fall
	lda e_type,x
	beq @r
	lda e_timer2,x          ; posture de tir
	beq :+
	dec e_timer2,x
:
	dec e_timer,x
	bne @c
	lda #90
	sta e_timer,x
	jsr on_screen
	bcc @c
	lda e_ground,x
	beq @c
	lda #10
	sta e_timer2,x
	lda #<-21
	jsr fire_forward
@c:
	jmp contact_check
@r:
	rts

; --- Moustachu menthe : reste sur place, rafales de 3 balles
init_menthe:
	lda #3                  ; palette 2
	sta e_pal,x
	lda #60
	sta e_timer,x
	rts
upd_menthe:
	jsr enemy_fall
	lda e_type,x
	beq @r
	jsr face_player
	lda e_timer2,x
	beq @wait
	; rafale en cours : une balle toutes les 8 trames
	dec e_timer2,x
	lda e_timer2,x
	and #7
	bne @c
	lda #<-21
	jsr fire_forward
	jmp @c
@wait:
	dec e_timer,x
	bne @c
	lda #110
	sta e_timer,x
	jsr on_screen
	bcc @c
	lda #24
	sta e_timer2,x
@c:
	jmp contact_check
@r:
	rts

; --- Ninja : fumée, (saut), lancer de shurikens, disparition
init_ninja:
	lda #0
	sta e_vx,x
	lda #16
	sta e_timer,x
	rts
upd_ninja:
	lda e_state,x
	bne @visible
	dec e_timer,x
	bne @r
	lda #1
	sta e_state,x
	lda #120
	sta e_timer,x
	jsr rand
	bmi @r
	; un ninja sur deux saute vers le héros
	jsr face_player
	asl a
	sta e_vx,x
	lda #<-$0380
	sta e_vyl,x
	lda #>-$0380
	sta e_vyh,x
	lda #0
	sta e_ground,x
@r:
	rts
@visible:
	lda e_ground,x
	beq :+
	lda #0
	sta e_vx,x
:
	jsr move_x
	jsr enemy_fall
	lda e_type,x
	beq @r
	lda e_timer2,x
	beq :+
	dec e_timer2,x
:
	dec e_timer,x
	beq @vanish
	lda e_timer,x
	cmp #90
	beq @throw
	cmp #40
	beq @throw
	jmp contact_check
@throw:
	lda e_ground,x
	beq @c
	jsr on_screen
	bcc @c
	jsr face_player
	lda #12
	sta e_timer2,x
	lda #2
	sta nb_kind
	lda #<-22
	sta nb_dy
	; shuriken horizontal
	lda #$80
	sta nb_vxl
	lda #0
	sta nb_vyl
	sta nb_vyh
	lda #2
	ldy e_flip,x
	beq :+
	lda #$80
	sta nb_vxl
	lda #$FD
:
	sta nb_vxh
	jsr enemy_fire
	; shuriken en diagonale (vers le haut si le héros saute, sinon vers le bas)
	lda #$C0
	sta nb_vyl
	lda #0
	sta nb_vyh
	lda p_ground
	bne :+
	lda #$40
	sta nb_vyl
	lda #$FF
	sta nb_vyh
:
	jsr enemy_fire
	lda #SFX_ESHOT
	jsr sfx_play
@c:
	jmp contact_check
@vanish:
	lda #ENT_SMOKE
	sta e_type,x
	lda #16
	sta e_timer,x
	rts

; --- Motard : fonce, 2 points de vie, continue à pied
init_biker:
	lda #3
	sta e_hp,x
	lda #$FD
	sta e_vx,x
	lda #$40
	sta e_flip,x
	lda #SFX_BIKE
	jsr sfx_play
	rts
upd_biker:
	jsr move_x
	jsr enemy_fall
	lda e_type,x
	beq @r
	jmp contact_check
@r:
	rts

init_foot:
	lda #8
	sta e_timer,x
	rts
upd_foot:
	jsr face_player
	lda frame
	and #1
	beq :+
	jsr face_player
	sta e_vx,x
	jsr wall_ahead
	bcs :+
	jsr move_x
:
	lda #0
	sta e_vx,x
	jsr enemy_fall
	lda e_type,x
	beq @r
	jmp contact_check
@r:
	rts

; --- Imprudent : va se placer à côté du baril le plus proche
IMP_SEEK  = 0
IMP_POSE  = 1
IMP_CARRY = 2
init_imp:
	lda #60
	sta e_timer,x
	rts
upd_imp:
	jsr enemy_fall
	lda e_type,x
	bne :+
	rts
:
	lda e_state,x
	cmp #IMP_CARRY
	bne :+
	jmp @carry
:
	; cherche le baril le plus proche
	lda #$FF
	sta tmp+3               ; meilleure distance
	sta tmp+4               ; meilleur emplacement
	ldy #MAX_ENEMY-1
@scan:
	lda e_type,y
	cmp #ENT_BARREL
	bne @snext
	lda e_xl,y
	sec
	sbc e_xl,x
	sta tmp+5
	lda e_xh,y
	sbc e_xh,x
	beq @pos
	cmp #$FF
	bne @snext
	lda tmp+5
	eor #$FF
	clc
	adc #1
	jmp @cmp
@pos:
	lda tmp+5
@cmp:
	cmp tmp+3
	bcs @snext
	sta tmp+3
	sty tmp+4
@snext:
	dey
	bpl @scan
	lda tmp+4
	bpl @have
	; pas de baril : il en apporte un
	lda e_state,x
	cmp #IMP_POSE
	jeq @pose
	lda #IMP_CARRY
	sta e_state,x
	lda #48
	sta e_timer2,x
	rts
@have:
	; cible : 12 px du bon côté du baril
	tay
	lda e_xl,x
	sec
	sbc e_xl,y
	lda e_xh,x
	sbc e_xh,y
	lda #12
	bcs :+
	lda #<-12
:
	sta tmp+5
	clc
	adc e_xl,y
	sta tmp+0
	lda #0
	bit tmp+5
	bpl :+
	lda #$FF
:
	adc e_xh,y
	sta tmp+1
	; écart avec la cible
	lda tmp+0
	sec
	sbc e_xl,x
	sta tmp+5
	lda tmp+1
	sbc e_xh,x
	bmi @goleft
	bne @goright
	lda tmp+5
	cmp #2
	bcc @arrived
@goright:
	lda #1
	sta e_vx,x
	lda #0
	sta e_flip,x
	lda #IMP_SEEK
	sta e_state,x
	jsr move_x
	jmp contact_check
@goleft:
	cmp #$FF
	bne :+
	lda tmp+5
	cmp #$FF
	bcs @arrived
:
	lda #$FF
	sta e_vx,x
	lda #$40
	sta e_flip,x
	lda #IMP_SEEK
	sta e_state,x
	jsr move_x
	jmp contact_check
@arrived:
	lda #IMP_POSE
	sta e_state,x
@pose:
	jsr face_player
	dec e_timer,x
	bne @c
	lda #100
	sta e_timer,x
	jsr on_screen
	bcc @c
	lda #<-18
	jsr fire_forward
@c:
	jmp contact_check
@carry:
	jsr face_player
	sta e_vx,x
	jsr wall_ahead
	bcs @drop
	lda frame
	and #1
	beq :+
	jsr move_x
:
	dec e_timer2,x
	bne @c
@drop:
	; pose le baril devant lui
	lda e_xl,x
	sta tmp+0
	lda e_xh,x
	sta tmp+1
	lda #12
	ldy e_flip,x
	beq :+
	lda #<-12
:
	sta tmp+5
	clc
	adc tmp+0
	sta tmp+0
	lda #0
	bit tmp+5
	bpl :+
	lda #$FF
:
	adc tmp+1
	sta tmp+1
	lda e_y,x
	sta tmp+2
	lda #IMP_POSE
	sta e_state,x
	lda #30
	sta e_timer,x
	jsr find_enemy_slot
	bcs @nob
	lda #ENT_BARREL
	jsr init_enemy
@nob:
	ldx cur_slot
	rts

; --- Baril
init_barrel:
	lda #3
	sta e_hp,x
	rts
upd_barrel:
	jsr enemy_fall
	lda e_type,x
	beq @r
	lda e_state,x
	beq @r
	dec e_timer,x
	bne @r
	jmp explode
@r:
	rts

; --- Explosion et fumée (décor animé)
init_none:
	rts
upd_explosion:
	inc e_timer,x
	lda e_timer,x
	cmp #24
	bcc :+
	lda #0
	sta e_type,x
:
	rts
upd_smoke:
	dec e_timer,x
	bne :+
	lda #0
	sta e_type,x
:
	rts

; ------------------------------------------------------- dégâts et morts
; La balle X du héros touche-t-elle un ennemi ? Carry mis si oui.
pbullet_hits:
	ldy #MAX_ENEMY-1
@loop:
	lda e_type,y
	beq @next
	sta tmp+3
	tax
	lda hb_w,x
	beq @nextx
	cpx #ENT_NINJA
	bne :+
	ldx cur_pb
	lda e_state,y
	beq @nextx              ; ninja encore dans sa fumée
:
	ldx cur_pb
	; |bx - ex| < largeur
	lda pb_xl,x
	sec
	sbc e_xl,y
	sta tmp+4
	lda pb_xh,x
	sbc e_xh,y
	beq @pos
	cmp #$FF
	bne @nextx
	lda tmp+4
	eor #$FF
	clc
	adc #1
	sta tmp+4
@pos:
	ldx tmp+3
	lda tmp+4
	cmp hb_w,x
	bcs @nextx
	; ey - h <= by < ey
	ldx cur_pb
	lda pb_y,x
	cmp e_y,y
	bcs @nextx
	ldx tmp+3
	lda e_y,y
	sec
	sbc hb_h,x
	ldx cur_pb
	cmp pb_y,x
	beq @hit
	bcs @nextx
@hit:
	; touché
	tya
	tax
	jsr damage_enemy
	ldx cur_pb
	sec
	rts
@nextx:
	ldx cur_pb
@next:
	dey
	bpl @loop
	clc
	rts

; Un point de dégât sur l'ennemi X.
damage_enemy:
	lda #4
	sta e_hit,x
	dec e_hp,x
	bne @alive
	jmp kill_enemy
@alive:
	lda #SFX_HIT
	jmp sfx_play

; Tue l'ennemi X : gerbe, combo, score, statistiques.
kill_enemy:
	lda e_type,x
	cmp #ENT_BARREL
	bne :+
	jmp explode
:
	cmp #ENT_EXPLOSION
	bcc :+
	rts
:
	stx cur_kill
	sta gib_kind
	lda e_xl,x
	sta gib_xl
	lda e_xh,x
	sta gib_xh
	lda e_y,x
	sec
	sbc #16
	sta gib_y
	lda e_pal,x
	eor #1                  ; palette 1 ou 2 selon la variante
	ldy e_type,x
	cpy #ENT_BIKER
	bcc :+
	lda #2                  ; motards et imprudents : palette 2
:
	sta gib_pal
	; statistiques
	ldy e_type,x
	lda type_stat,y
	tay
	lda stat_mou,y
	cmp #99
	bcs :+
	adc #1
	sta stat_mou,y
:
	; points et combo
	ldy e_type,x
	lda type_points,y
	jsr on_kill
	; la gerbe
	ldy tier
	lda tier_gibs,y
	jsr spawn_gibs
	lda #SFX_SPLAT
	jsr sfx_play
	; le motard continue à pied
	ldx cur_kill
	lda e_type,x
	cmp #ENT_BIKER
	bne @free
	lda #ENT_BIKER_FOOT
	sta e_type,x
	lda #1
	sta e_hp,x
	lda #<-$0300
	sta e_vyl,x
	lda #>-$0300
	sta e_vyh,x
	lda #0
	sta e_ground,x
	sta e_hit,x
	rts
@free:
	lda #0
	sta e_type,x
	rts

; Le baril X explose.
explode:
	stx cur_kill
	lda #ENT_EXPLOSION
	sta e_type,x
	lda #0
	sta e_timer,x
	lda #8
	sta shake
	lda #SFX_BOOM
	jsr sfx_play
	lda #5
	jsr add_points
	; souffle : ennemis à moins de 32 px
	ldy #MAX_ENEMY-1
@loop:
	sty ex_i
	lda e_type,y
	beq @next
	cmp #ENT_EXPLOSION
	bcs @next
	ldx cur_kill
	lda e_xl,y
	sec
	sbc e_xl,x
	sta tmp+4
	lda e_xh,y
	sbc e_xh,x
	beq @pos
	cmp #$FF
	bne @next
	lda tmp+4
	eor #$FF
	clc
	adc #1
	sta tmp+4
@pos:
	lda tmp+4
	cmp #36
	bcs @next
	lda e_y,y
	sec
	sbc e_y,x
	bcs :+
	eor #$FF
	adc #1
:
	cmp #36
	bcs @next
	lda e_type,y
	cmp #ENT_BARREL
	bne @kill
	lda e_state,y
	bne @next
	lda #1                  ; réaction en chaîne, avec un petit délai
	sta e_state,y
	lda #8
	sta e_timer,y
	bne @next
@kill:
	; condamné : il éclatera dans quelques trames (cascade, et le coût
	; des gerbes est réparti sur plusieurs trames)
	lda e_doom,y
	bne @next
	tya
	and #3
	clc
	adc #2
	sta e_doom,y
@next:
	ldy ex_i
	dey
	bpl @loop
	; le héros aussi, s'il est trop près
	ldx cur_kill
	jsr dist_x
	cmp #22
	bcs @done
	lda p_y
	sec
	sbc e_y,x
	bcs :+
	eor #$FF
	adc #1
:
	cmp #30
	bcs @done
	jsr player_hit
@done:
	ldx cur_kill
	rts

; ------------------------------------------------------------ affichage
draw_enemies:
	lda en_rot
	clc
	adc #3
	and #7
	sta en_rot
	tax
	lda #MAX_ENEMY
	sta tmp+7
@loop:
	lda e_type,x
	beq @next
	stx cur_slot
	jsr draw_enemy
	ldx cur_slot
@next:
	inx
	txa
	and #7
	tax
	dec tmp+7
	bne @loop
	rts

draw_enemy:
	lda e_xl,x
	ldy e_xh,x
	jsr to_screen
	lda e_y,x
	sta ms_y
	lda e_hit,x
	beq :+
	ldy e_type,x
	lda type_hit_eor,y
	bne :++
:
	lda e_pal,x
:
	ora e_flip,x
	sta ms_eor
	ldy e_type,x
	lda type_draw_lo,y
	sta ptr1
	lda type_draw_hi,y
	sta ptr1+1
	jmp (ptr1)

; Choisit le métasprite A/Y (bas/haut) et dessine.
ms_go:
	sta ptr0
	sty ptr0+1
	jmp draw_ms

walk_phase:
	lda frame
	lsr a
	lsr a
	lsr a
	and #1
	rts

drw_mou:
	lda e_timer2,x
	beq :+
	lda #<ms_mou_shoot
	ldy #>ms_mou_shoot
	jmp ms_go
:
	lda e_type,x
	cmp #ENT_MOU_MENTHE
	beq @stand
	jsr walk_phase
	beq @stand
	lda #<ms_mou_walk1
	ldy #>ms_mou_walk1
	jmp ms_go
@stand:
	lda #<ms_mou_walk2
	ldy #>ms_mou_walk2
	jmp ms_go

drw_ninja:
	lda e_state,x
	bne :+
	jmp drw_smoke
:
	lda e_timer2,x
	beq :+
	lda #<ms_nin_throw
	ldy #>ms_nin_throw
	jmp ms_go
:
	jsr walk_phase
	beq :+
	lda #<ms_nin_run1
	ldy #>ms_nin_run1
	jmp ms_go
:
	lda #<ms_nin_run2
	ldy #>ms_nin_run2
	jmp ms_go

drw_biker:
	lda #<ms_bik_ride
	ldy #>ms_bik_ride
	jmp ms_go

drw_foot:
	jsr walk_phase
	beq :+
	lda #<ms_bik_walk1
	ldy #>ms_bik_walk1
	jmp ms_go
:
	lda #<ms_bik_walk2
	ldy #>ms_bik_walk2
	jmp ms_go

drw_imp:
	lda e_state,x
	cmp #IMP_POSE
	bne :+
	lda #<ms_imp_thumb
	ldy #>ms_imp_thumb
	jmp ms_go
:
	cmp #IMP_CARRY
	bne @walk
	; le baril qu'il apporte, devant lui
	lda #<ms_barrel
	sta ptr0
	lda #>ms_barrel
	sta ptr0+1
	lda ms_xl
	pha
	lda ms_xh
	pha
	lda ms_eor
	pha
	lda #10
	ldy e_flip,x
	beq :+
	lda #<-10
:
	sta tmp+5
	clc
	adc ms_xl
	sta ms_xl
	lda #0
	bit tmp+5
	bpl :+
	lda #$FF
:
	adc ms_xh
	sta ms_xh
	lda e_flip,x
	sta ms_eor
	jsr draw_ms
	pla
	sta ms_eor
	pla
	sta ms_xh
	pla
	sta ms_xl
	ldx cur_slot
@walk:
	jsr walk_phase
	beq :+
	lda #<ms_imp_walk1
	ldy #>ms_imp_walk1
	jmp ms_go
:
	lda #<ms_imp_walk2
	ldy #>ms_imp_walk2
	jmp ms_go

drw_barrel:
	lda e_flip,x
	and #0
	sta ms_eor
	lda e_hit,x
	bne :+
	lda e_state,x
	beq @n
	lda frame
	and #2
	beq @n
:
	lda #<ms_barrel_hit
	ldy #>ms_barrel_hit
	jmp ms_go
@n:
	lda #<ms_barrel
	ldy #>ms_barrel
	jmp ms_go

drw_explosion:
	lda #0
	sta ms_eor
	lda e_timer,x
	cmp #5
	bcs :+
	lda #<ms_exp1
	ldy #>ms_exp1
	jmp ms_go
:
	cmp #15
	bcs :+
	lda #<ms_exp2
	ldy #>ms_exp2
	jmp ms_go
:
	lda #<ms_exp3
	ldy #>ms_exp3
	jmp ms_go

drw_smoke:
	lda #0
	sta ms_eor
	lda e_timer,x
	and #4
	beq :+
	lda #<ms_smoke1
	ldy #>ms_smoke1
	jmp ms_go
:
	lda #<ms_smoke2
	ldy #>ms_smoke2
	jmp ms_go

; ---------------------------------------------------- projectiles ennemis
update_ebullets:
	ldx #MAX_EBUL-1
@loop:
	lda eb_kind,x
	jeq @next
	lda eb_xs,x
	clc
	adc eb_vxl,x
	sta eb_xs,x
	lda eb_xl,x
	adc eb_vxh,x
	sta eb_xl,x
	lda eb_vxh,x
	and #$80
	beq :+
	lda #$FF
:
	adc eb_xh,x
	sta eb_xh,x
	lda eb_ys,x
	clc
	adc eb_vyl,x
	sta eb_ys,x
	lda eb_y,x
	adc eb_vyh,x
	sta eb_y,x
	cmp #24
	bcc @kill
	cmp #232
	bcs @kill
	lda eb_xl,x
	sec
	sbc cam_xl
	sta tmp+6
	lda eb_xh,x
	sbc cam_xh
	bne @kill
	; touche le héros ?
	lda p_state
	bne @next
	lda eb_xl,x
	sec
	sbc p_xl
	sta tmp+6
	lda eb_xh,x
	sbc p_xh
	beq @px
	cmp #$FF
	bne @next
	lda tmp+6
	eor #$FF
	clc
	adc #1
	sta tmp+6
@px:
	ldy p_pose
	lda tmp+6
	cmp pose_hw,y
	bcs @next
	lda p_y
	sec
	sbc pose_top,y
	cmp eb_y,x
	bcs @next
	lda p_y
	sec
	sbc pose_bot,y
	cmp eb_y,x
	bcc @next
	stx tmp+7
	jsr player_hit
	ldx tmp+7
	lda p_state
	beq @next
@kill:
	lda #0
	sta eb_kind,x
@next:
	dex
	jpl @loop
	rts

; Boîte du héros selon la posture : demi-largeur, haut, bas (au-dessus des pieds)
pose_hw:
	.byte 6, 6, 6, 6, 6, 14, 7
pose_top:
	.byte 28, 28, 28, 28, 28, 11, 22
pose_bot:
	.byte 0, 0, 0, 0, 0, 0, 6

draw_ebullets:
	ldx #MAX_EBUL-1
@loop:
	lda eb_kind,x
	beq @next
	lda eb_xl,x
	ldy eb_xh,x
	jsr to_screen
	lda ms_xl
	sec
	sbc #4
	sta ms_xl
	bcs :+
	dec ms_xh
:
	lda eb_y,x
	sec
	sbc #4
	sta ms_y
	lda eb_kind,x
	cmp #2
	beq @shur
	lda #3
	sta ms_eor
	lda #SPR_EBULLET
	jsr draw_one
	jmp @next
@shur:
	lda #1
	sta ms_eor
	lda frame
	and #4
	beq :+
	lda #SPR_SHURIKEN1
	jsr draw_one
	jmp @next
:
	lda #SPR_SHURIKEN2
	jsr draw_one
@next:
	dex
	bpl @loop
	rts

; ------------------------------------------------------- tables par type
;                none rose menthe ninja biker foot  imp barrel expl smoke end hero
type_init_lo:
	.byte <init_none, <init_rose, <init_menthe, <init_ninja, <init_biker, <init_foot, <init_imp, <init_barrel, <init_none, <init_none
type_init_hi:
	.byte >init_none, >init_rose, >init_menthe, >init_ninja, >init_biker, >init_foot, >init_imp, >init_barrel, >init_none, >init_none
type_update_lo:
	.byte <init_none, <upd_rose, <upd_menthe, <upd_ninja, <upd_biker, <upd_foot, <upd_imp, <upd_barrel, <upd_explosion, <upd_smoke
type_update_hi:
	.byte >init_none, >upd_rose, >upd_menthe, >upd_ninja, >upd_biker, >upd_foot, >upd_imp, >upd_barrel, >upd_explosion, >upd_smoke
type_draw_lo:
	.byte <init_none, <drw_mou, <drw_mou, <drw_ninja, <drw_biker, <drw_foot, <drw_imp, <drw_barrel, <drw_explosion, <drw_smoke
type_draw_hi:
	.byte >init_none, >drw_mou, >drw_mou, >drw_ninja, >drw_biker, >drw_foot, >drw_imp, >drw_barrel, >drw_explosion, >drw_smoke
hb_w:
	.byte 0, 7, 7, 7, 14, 7, 7, 8, 0, 0
hb_h:
	.byte 0, 30, 30, 30, 28, 30, 30, 15, 0, 0
type_points:                       ; en dizaines de points
	.byte 0, 10, 10, 20, 30, 15, 10, 5, 0, 0
type_stat:                         ; décalage depuis stat_mou
	.byte 0, 0, 0, 1, 2, 2, 3, 0, 0, 0
type_hit_eor:                      ; palette 3 quand l'ennemi est touché
	.byte 0, 2, 2, 2, 1, 1, 1, 0, 0, 0
