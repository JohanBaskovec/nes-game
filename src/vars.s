; Variables en RAM.

MAX_PBUL  = 6          ; balles du héros
MAX_ENEMY = 8          ; ennemis, barils, explosions
MAX_EBUL  = 8          ; projectiles ennemis
MAX_PART  = 32         ; fragments des gerbes

VBUF_SIZE = 96

.segment "ZEROPAGE"
; --- système
nmi_ready:   .res 1    ; 1 = la boucle principale a fini sa trame
nmi_count:   .res 1
lag_count:   .res 1    ; trames où la boucle principale était en retard
render_off:  .res 1    ; 1 = la NMI ne touche pas au PPU
hud_split:   .res 1    ; 1 = écran de jeu (HUD fixe + IRQ MMC3)
scroll_x:    .res 1    ; défilement demandé (préparé par la boucle principale)
scroll_nt:   .res 1
cur_x:       .res 1    ; défilement validé (utilisé par la NMI)
cur_nt:      .res 1
irq_ctrl:    .res 1
split_line:  .res 1    ; ligne de l'IRQ (découpage de l'écran)
chr_top:     .res 1    ; banque CHR R0 au-dessus de la ligne de l'IRQ
chr_bottom:  .res 1    ; banque CHR R0 en dessous
chr_r1:      .res 1    ; banque CHR R1 de l'écran (réglée par ppu_on)
pal_dirty:   .res 1
col_pending: .res 1
vbuf_len:    .res 1
pad:         .res 1
pad_old:     .res 1
pad_new:     .res 1
tmp:         .res 8
ptr0:        .res 2
ptr1:        .res 2
ptr2:        .res 2
rng:         .res 2
state:       .res 1
frame:       .res 1
family_mode: .res 1
oam_idx:     .res 1
cam_xl:      .res 1    ; caméra : position monde du bord gauche
cam_xh:      .res 1
cam_col:     .res 1    ; cam_x / 16
next_col:    .res 1    ; prochaine colonne de métatuiles à écrire
spawn_idx:   .res 1

; --- héros
p_xs:        .res 1    ; sous-pixel
p_xl:        .res 1
p_xh:        .res 1
p_ys:        .res 1
p_y:         .res 1    ; y des pieds
p_vyl:       .res 1    ; vitesse verticale 8.8 signée
p_vyh:       .res 1
p_flip:      .res 1    ; 0 = regarde à droite, $40 = à gauche
p_state:     .res 1
p_ground:    .res 1
p_anim:      .res 1
p_fire_cd:   .res 1
p_invuln:    .res 1
p_aim:       .res 1    ; direction de tir 0-7 (0 = droite, sens horaire)
p_pose:      .res 1
p_drop:      .res 1
p_timer:     .res 1

; --- partie
lives:       .res 1
combo:       .res 1
combo_timer: .res 1
tier:        .res 1
shake:       .res 1
fx_sky:      .res 1    ; 0 normal, 1 rouge, 2 flash
fx_timer:    .res 1
ninja_timer: .res 1
level_done:  .res 1
paused:      .res 1
hud_dirty:   .res 1    ; bits : 1 score, 2 combo, 4 message, 8 vies
msg_id:      .res 1
msg_timer:   .res 1
pal_req:     .res 1    ; 1 = recalculer la palette en fin de trame

; --- variables des modules
; --- level.s
cl_xl:   .res 1        ; point testé par get_coll
cl_xh:   .res 1
cl_y:    .res 1
cl_ptr:  .res 2

; --- oam.s
ms_xl:    .res 1       ; ancre, x écran (16 bits signé)
ms_xh:    .res 1
ms_y:     .res 1       ; ancre, y écran
ms_eor:   .res 1       ; XOR appliqué aux attributs (bit 6 = miroir, bits 0-1 = palette)
ms_dx:    .res 1
oam_full: .res 1

; --- enemies.s
nb_vxl:  .res 1        ; paramètres de enemy_fire
nb_vxh:  .res 1
nb_vyl:  .res 1
nb_vyh:  .res 1
nb_dy:   .res 1
nb_kind: .res 1
end_xl:  .res 1        ; position de la fin du niveau
end_xh:  .res 1
cur_slot: .res 1
cur_pb:   .res 1
cur_kill: .res 1
ex_i:     .res 1

; --- particles.s
gib_xl:     .res 1
gib_xh:     .res 1
gib_y:      .res 1
gib_kind:   .res 1     ; type d'ennemi -> table d'objets absurdes
gib_pal:    .res 1     ; palette des objets absurdes
gib_n:      .res 1
gib_budget: .res 1

; --- game.s
end_timer: .res 1

; --- audio.s
au_ptr:     .res 2
sfx_req_n:  .res 1     ; demandes (écrites par la boucle principale)
sfx_req_p:  .res 1
mus_req:    .res 1     ; 0 = rien, sinon morceau + 1

.segment "OAM"
oam:         .res 256

.segment "BSS"
vbuf:        .res VBUF_SIZE
pal_base:    .res 32
pal_buf:     .res 32
; colonne de décor à envoyer pendant le VBlank
col_left:    .res 26
col_right:   .res 26
col_attr:    .res 7
col_addr_hi: .res 1
col_addr_lo: .res 1
col_attr_hi: .res 1
col_attr_x:  .res 1

score:       .res 7    ; chiffres décimaux, poids fort en premier
best_combo:  .res 1
stat_mou:    .res 1
stat_nin:    .res 1
stat_bik:    .res 1
stat_imp:    .res 1
stat_blood:  .res 2    ; litres (BCD : 4 chiffres)
continues:   .res 1
opt_lives:   .res 1
menu_sel:    .res 1
text_step:   .res 1
title_timer: .res 1
text_timer:  .res 1

; balles du héros
pb_xl:       .res MAX_PBUL
pb_xh:       .res MAX_PBUL
pb_y:        .res MAX_PBUL
pb_dx:       .res MAX_PBUL
pb_dy:       .res MAX_PBUL
pb_on:       .res MAX_PBUL

; ennemis
e_type:      .res MAX_ENEMY  ; 0 = libre
e_state:     .res MAX_ENEMY
e_xl:        .res MAX_ENEMY
e_xh:        .res MAX_ENEMY
e_y:         .res MAX_ENEMY
e_ys:        .res MAX_ENEMY
e_vx:        .res MAX_ENEMY  ; pixels par trame, signé
e_vyl:       .res MAX_ENEMY
e_vyh:       .res MAX_ENEMY
e_timer:     .res MAX_ENEMY
e_timer2:    .res MAX_ENEMY
e_hp:        .res MAX_ENEMY
e_flip:      .res MAX_ENEMY
e_pal:       .res MAX_ENEMY
e_hit:       .res MAX_ENEMY  ; clignotement quand touché
e_ground:    .res MAX_ENEMY
e_doom:      .res MAX_ENEMY  ; > 0 : éclate quand le compteur arrive à 0

; projectiles ennemis (positions et vitesses 8.8)
eb_xs:       .res MAX_EBUL
eb_xl:       .res MAX_EBUL
eb_xh:       .res MAX_EBUL
eb_ys:       .res MAX_EBUL
eb_y:        .res MAX_EBUL
eb_vxl:      .res MAX_EBUL
eb_vxh:      .res MAX_EBUL
eb_vyl:      .res MAX_EBUL
eb_vyh:      .res MAX_EBUL
eb_kind:     .res MAX_EBUL   ; 0 libre, 1 balle, 2 shuriken

; fragments
pt_life:     .res MAX_PART   ; 0 = libre
pt_xs:       .res MAX_PART
pt_xl:       .res MAX_PART
pt_xh:       .res MAX_PART
pt_ys:       .res MAX_PART
pt_y:        .res MAX_PART
pt_vxl:      .res MAX_PART
pt_vxh:      .res MAX_PART
pt_vyl:      .res MAX_PART
pt_vyh:      .res MAX_PART
pt_tile:     .res MAX_PART
pt_attr:     .res MAX_PART   ; bit 7 de pt_attr réservé : déjà rebondi
pt_next:     .res 1          ; prochain emplacement à recycler
pt_rot:      .res 1          ; rotation de l'ordre d'affichage
en_rot:      .res 1

.segment "WRAM"
; copie des deux tables de noms du terrain, colonne par colonne :
; nt_shadow + tx*32 + ty, tx = 0..63, ty = 0..29
nt_shadow:   .res 2048
