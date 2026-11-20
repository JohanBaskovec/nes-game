; Le héros : déplacements, saut, tir, mort.

PS_NORMAL = 0
PS_DEAD   = 1

POSE_STAND   = 0
POSE_UP      = 1
POSE_RUN     = 2
POSE_RUN_DUP = 3
POSE_RUN_DDN = 4
POSE_PRONE   = 5
POSE_BALL    = 6

AIM_FWD  = 0
AIM_DUP  = 1
AIM_UP   = 2
AIM_DDN  = 3
AIM_DOWN = 4

GRAVITY    = $2E       ; 0,18 px/trame²
JUMP_SPEED = $0480     ; 4,5 px/trame
WALK_SUB   = $40       ; 1,25 px/trame
FIRE_DELAY = 6         ; 10 tirs par seconde

.segment "CODE"

player_init:
	lda #0
	sta p_xs
	sta p_xh
	sta p_ys
	sta p_vyl
	sta p_vyh
	sta p_flip
	sta p_state
	sta p_ground
	sta p_fire_cd
	sta p_drop
	sta p_anim
	lda #40
	sta p_xl
	lda #120
	sta p_y
	lda #60
	sta p_invuln
	rts

player_update:
	lda p_state
	cmp #PS_DEAD
	bne :+
	jmp player_dead
:
	lda p_invuln
	beq :+
	dec p_invuln
:
	lda pad
	and #BTN_RIGHT
	beq :+
	lda #0
	sta p_flip
:
	lda pad
	and #BTN_LEFT
	beq :+
	lda #$40
	sta p_flip
:
	lda p_ground
	bne @ground
	jmp @air
@ground:
	lda pad
	and #BTN_DOWN
	beq @notprone
	lda pad
	and #(BTN_LEFT|BTN_RIGHT)
	bne @notprone
	; couché
	lda #POSE_PRONE
	sta p_pose
	lda #AIM_FWD
	sta p_aim
	lda pad_new
	and #BTN_A
	jeq @vert
	jsr coll_under_player
	cmp #COLL_PLAT
	jne @vert
	lda #10                 ; Bas + A : on traverse la plateforme
	sta p_drop
	jmp @vert
@notprone:
	jsr move_horizontal
	; visée et posture
	lda pad
	and #BTN_UP
	beq @noup
	lda tmp+0               ; en mouvement ?
	beq @standup
	lda #AIM_DUP
	ldx #POSE_RUN_DUP
	bne @setaim
@standup:
	lda #AIM_UP
	ldx #POSE_UP
	bne @setaim
@noup:
	lda pad
	and #BTN_DOWN
	beq @fwd
	lda #AIM_DDN
	ldx #POSE_RUN_DDN
	bne @setaim
@fwd:
	lda #AIM_FWD
	ldx #POSE_STAND
	ldy tmp+0
	beq @setaim
	ldx #POSE_RUN
@setaim:
	sta p_aim
	stx p_pose
	lda pad_new
	and #BTN_A
	beq @vert
	lda #<(-JUMP_SPEED)
	sta p_vyl
	lda #>(-JUMP_SPEED)
	sta p_vyh
	lda #0
	sta p_ground
	lda #SFX_JUMP
	jsr sfx_play
	jmp @vert
@air:
	jsr move_horizontal
	lda #POSE_BALL
	sta p_pose
	ldx #AIM_FWD
	lda pad
	and #BTN_UP
	beq @aup
	ldx #AIM_UP
	lda pad
	and #(BTN_LEFT|BTN_RIGHT)
	beq @aset
	ldx #AIM_DUP
	bne @aset
@aup:
	lda pad
	and #BTN_DOWN
	beq @aset
	ldx #AIM_DOWN
	lda pad
	and #(BTN_LEFT|BTN_RIGHT)
	beq @aset
	ldx #AIM_DDN
@aset:
	stx p_aim
@vert:
	jsr player_vertical
	jsr player_fire
	inc p_anim
	rts

; Déplacement horizontal. tmp+0 = 1 si le héros a bougé.
move_horizontal:
	lda #0
	sta tmp+0
	lda p_xs
	sta tmp+1
	lda p_xl
	sta tmp+2
	lda p_xh
	sta tmp+3
	lda pad
	and #BTN_RIGHT
	beq @left
	lda p_xs
	clc
	adc #WALK_SUB
	sta p_xs
	lda p_xl
	adc #1
	sta p_xl
	lda p_xh
	adc #0
	sta p_xh
	lda #6
	jsr wall_check
	bcs @revert
	; limite droite : 16 px avant le bord de l'écran
	lda p_xl
	sec
	sbc cam_xl
	tax
	lda p_xh
	sbc cam_xh
	bne @revert
	cpx #240
	bcs @revert
	inc tmp+0
	rts
@left:
	lda pad
	and #BTN_LEFT
	beq @none
	lda p_xs
	sec
	sbc #WALK_SUB
	sta p_xs
	lda p_xl
	sbc #1
	sta p_xl
	lda p_xh
	sbc #0
	sta p_xh
	lda #<(-6)
	jsr wall_check
	bcs @revert
	; limite gauche : 12 px après le bord de l'écran
	lda p_xl
	sec
	sbc cam_xl
	tax
	lda p_xh
	sbc cam_xh
	bne @revert
	cpx #12
	bcc @revert
	inc tmp+0
	rts
@revert:
	lda tmp+1
	sta p_xs
	lda tmp+2
	sta p_xl
	lda tmp+3
	sta p_xh
@none:
	rts

; Mur à p_x + A (signé) ? Carry mis si bloqué.
wall_check:
	sta tmp+4
	clc
	adc p_xl
	sta cl_xl
	lda #0
	bit tmp+4
	bpl :+
	lda #$FF
:
	adc p_xh
	sta cl_xh
	lda p_y
	sec
	sbc #6
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @blocked
	lda p_y
	sec
	sbc #22
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @blocked
	clc
	rts
@blocked:
	sec
	rts

coll_under_player:
	lda p_xl
	sta cl_xl
	lda p_xh
	sta cl_xh
	lda p_y
	sta cl_y
	jmp get_coll

player_vertical:
	lda p_drop
	beq :+
	dec p_drop
:
	lda p_ground
	beq @fall
	jsr coll_under_player
	cmp #COLL_SOLID
	beq @ok
	cmp #COLL_PLAT
	bne @startfall
	lda p_drop
	bne @startfall
@ok:
	rts
@startfall:
	lda #0
	sta p_ground
	sta p_vyl
	sta p_vyh
@fall:
	lda p_vyl
	clc
	adc #GRAVITY
	sta p_vyl
	lda p_vyh
	adc #0
	sta p_vyh
	bmi :+
	cmp #4
	bcc :+
	lda #4
	sta p_vyh
	lda #0
	sta p_vyl
:
	lda p_y
	sta tmp+5               ; ancien y
	lda p_ys
	clc
	adc p_vyl
	sta p_ys
	lda p_y
	adc p_vyh
	sta p_y
	lda p_vyh
	bmi @rising
	lda p_y
	cmp #240
	bcc :+
	jmp player_kill         ; chute dans le vide
:
	jsr coll_under_player
	cmp #COLL_SOLID
	beq @land
	cmp #COLL_PLAT
	bne @water
	lda p_drop
	bne @noland
@land:
	lda p_y
	sec
	sbc #32
	and #$F0
	clc
	adc #32
	sta tmp+6               ; haut de la métatuile
	lda tmp+5
	cmp tmp+6
	beq :+
	bcs @noland             ; on venait d'en dessous
:
	lda tmp+6
	sta p_y
	lda #0
	sta p_vyl
	sta p_vyh
	sta p_ys
	lda #1
	sta p_ground
	rts
@water:
	cmp #COLL_WATER
	bne @noland
	lda p_y
	sec
	sbc #32
	and #$0F
	cmp #6
	bcc @noland
	jmp player_kill
@rising:
	lda p_y
	sec
	sbc #30
	bcc @noland
	sta cl_y
	lda p_xl
	sta cl_xl
	lda p_xh
	sta cl_xh
	jsr get_coll
	cmp #COLL_SOLID
	bne @noland
	lda #0                  ; tête contre un bloc
	sta p_vyl
	sta p_vyh
@noland:
	rts

player_fire:
	lda p_fire_cd
	beq :+
	dec p_fire_cd
	rts
:
	lda pad
	and #BTN_B
	beq @no
	ldy #MAX_PBUL-1
@find:
	lda pb_on,y
	beq @got
	dey
	bpl @find
@no:
	rts
@got:
	lda #FIRE_DELAY
	sta p_fire_cd
	; direction absolue
	lda p_aim
	ldx p_flip
	beq :+
	clc
	adc #5
:
	tax
	lda aim_to_dir,x
	tax
	lda dir_dx,x
	sta pb_dx,y
	lda dir_dy,x
	sta pb_dy,y
	; point de départ selon la posture
	ldx p_aim
	lda p_pose
	cmp #POSE_PRONE
	bne :+
	ldx #5
	bne @ofs
:
	cmp #POSE_BALL
	bne @ofs
	ldx #6
@ofs:
	lda shot_dx,x
	ldx p_flip
	beq :+
	eor #$FF
	clc
	adc #1
:
	sta tmp+4
	clc
	adc p_xl
	sta pb_xl,y
	lda #0
	bit tmp+4
	bpl :+
	lda #$FF
:
	adc p_xh
	sta pb_xh,y
	ldx p_aim
	lda p_pose
	cmp #POSE_PRONE
	bne :+
	ldx #5
	bne @ofsy
:
	cmp #POSE_BALL
	bne @ofsy
	ldx #6
@ofsy:
	lda shot_dy,x
	clc
	adc p_y
	sta pb_y,y
	lda #1
	sta pb_on,y
	lda #SFX_SHOT
	jmp sfx_play

; visée relative -> direction absolue (0 = droite, sens horaire)
aim_to_dir:
	.byte 0, 7, 6, 1, 2     ; vers la droite
	.byte 4, 5, 6, 3, 2     ; vers la gauche
dir_dx:
	.byte 5, 4, 0, <-4, <-5, <-4, 0, 4
dir_dy:
	.byte 0, 4, 5, 4, 0, <-4, <-5, <-4
; décalage du canon : fwd, dup, up, ddn, down(air), couché, en l'air
shot_dx:
	.byte 13, 12, 3, 12, 0, 17, 0
shot_dy:
	.byte <-23, <-33, <-37, <-15, <-16, <-6, <-16

player_dead:
	dec p_timer
	bne @r
	lda lives
	bne @respawn
	jmp goto_gameover
@respawn:
	lda cam_xl
	clc
	adc #40
	sta p_xl
	lda cam_xh
	adc #0
	sta p_xh
	; cherche vers la droite une colonne qui a un sol (pas au-dessus de l'eau)
	lda #12
	sta tmp+5
@scan:
	lda p_xl
	sta cl_xl
	lda p_xh
	sta cl_xh
	lda #33
@row:
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	beq @safe
	cmp #COLL_PLAT
	beq @safe
	lda cl_y
	clc
	adc #16
	cmp #240
	bcc @row
	lda p_xl
	clc
	adc #16
	sta p_xl
	bcc :+
	inc p_xh
:
	dec tmp+5
	bne @scan
@safe:
	lda #48
	sta p_y
	lda #0
	sta p_vyl
	sta p_vyh
	sta p_ground
	sta p_state
	lda #120
	sta p_invuln
@r:
	rts

; Touché par un ennemi (ignoré pendant l'invincibilité).
player_hit:
	lda p_state
	bne @no
	lda p_invuln
	bne @no
	jmp player_kill
@no:
	rts

; Mort immédiate (chute, eau, ou touché).
player_kill:
	lda p_state
	bne @no
	lda #PS_DEAD
	sta p_state
	lda #90
	sta p_timer
	dec lives
	lda hud_dirty
	ora #HUD_LIVES
	sta hud_dirty
	lda #0
	sta combo_timer
	lda p_xl
	sta gib_xl
	lda p_xh
	sta gib_xh
	lda p_y
	sec
	sbc #16
	sta gib_y
	lda #ENT_HERO
	sta gib_kind
	lda #0
	sta gib_pal
	lda #14
	jsr spawn_gibs
	lda #SFX_DEATH
	jsr sfx_play
@no:
	rts

; ------------------------------------------------------------ affichage
draw_player:
	lda p_state
	bne @no
	lda p_invuln
	beq :+
	lda frame
	and #2
	bne @no
:
	lda p_xl
	ldy p_xh
	jsr to_screen
	lda p_y
	sta ms_y
	lda p_flip
	sta ms_eor
	ldx p_pose
	cpx #POSE_BALL
	beq @ball
	cpx #POSE_PRONE
	beq @prone
	lda pose_upper_lo,x
	sta ptr0
	lda pose_upper_hi,x
	sta ptr0+1
	jsr draw_ms
	; jambes
	ldx p_pose
	cpx #POSE_RUN
	bcs @run
	lda #<ms_legs_stand
	sta ptr0
	lda #>ms_legs_stand
	sta ptr0+1
	jmp draw_ms
@run:
	lda p_anim
	lsr a
	lsr a
	lsr a
	and #3
	tax
	lda run_lo,x
	sta ptr0
	lda run_hi,x
	sta ptr0+1
	jmp draw_ms
@prone:
	lda #<ms_hero_prone
	sta ptr0
	lda #>ms_hero_prone
	sta ptr0+1
	jmp draw_ms
@ball:
	lda p_anim
	lsr a
	lsr a
	and #3
	tax
	lda ball_lo,x
	sta ptr0
	lda ball_hi,x
	sta ptr0+1
	lda ball_eor,x
	eor p_flip
	sta ms_eor
	jmp draw_ms
@no:
	rts

pose_upper_lo:
	.byte <ms_hero_fwd, <ms_hero_up, <ms_hero_fwd, <ms_hero_dup, <ms_hero_ddn
pose_upper_hi:
	.byte >ms_hero_fwd, >ms_hero_up, >ms_hero_fwd, >ms_hero_dup, >ms_hero_ddn
run_lo:
	.byte <ms_legs_run1, <ms_legs_run2, <ms_legs_run3, <ms_legs_run2
run_hi:
	.byte >ms_legs_run1, >ms_legs_run2, >ms_legs_run3, >ms_legs_run2
ball_lo:
	.byte <ms_hero_ball1, <ms_hero_ball2, <ms_hero_ball1, <ms_hero_ball2
ball_hi:
	.byte >ms_hero_ball1, >ms_hero_ball2, >ms_hero_ball1, >ms_hero_ball2
ball_eor:
	.byte $00, $00, $C0, $C0

; ------------------------------------------------------- balles du héros
update_pbullets:
	ldx #MAX_PBUL-1
@loop:
	lda pb_on,x
	beq @next
	; x += dx (signé)
	lda pb_dx,x
	sta tmp
	clc
	adc pb_xl,x
	sta pb_xl,x
	lda #0
	bit tmp
	bpl :+
	lda #$FF
:
	adc pb_xh,x
	sta pb_xh,x
	lda pb_y,x
	clc
	adc pb_dy,x
	sta pb_y,x
	cmp #24
	bcc @kill
	cmp #232
	bcs @kill
	; hors écran ?
	lda pb_xl,x
	sec
	sbc cam_xl
	lda pb_xh,x
	sbc cam_xh
	bne @kill
	; collision avec les ennemis
	stx cur_pb
	jsr pbullet_hits
	bcs @kill
	; collision avec un bloc solide
	lda pb_xl,x
	sta cl_xl
	lda pb_xh,x
	sta cl_xh
	lda pb_y,x
	sta cl_y
	jsr get_coll
	cmp #COLL_SOLID
	bne @next
@kill:
	lda #0
	sta pb_on,x
@next:
	dex
	bpl @loop
	rts

draw_pbullets:
	ldx #MAX_PBUL-1
@loop:
	lda pb_on,x
	beq @next
	lda pb_xl,x
	ldy pb_xh,x
	jsr to_screen
	lda ms_xl
	sec
	sbc #4
	sta ms_xl
	bcs :+
	dec ms_xh
:
	lda pb_y,x
	sec
	sbc #4
	sta ms_y
	lda #3
	sta ms_eor
	lda #SPR_BULLET
	jsr draw_one
@next:
	dex
	bpl @loop
	rts
