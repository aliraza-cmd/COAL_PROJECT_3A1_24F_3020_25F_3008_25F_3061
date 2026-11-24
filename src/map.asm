; ==============================================================================
; map.asm - 60x12 Level Tile Engine & Dual-Map Architecture
; Course: EL2003 Computer Organization & Assembly Language
; Author: Ali Raza (24F-3020) | Group BSE-3A1
; ==============================================================================

; ------------------------------------------------------------------------------
; map_reset
; Purpose : Restore working_map from original_map using REP MOVSB
; Concepts: String operations, direction flag, block memory copy
; Preserves all registers
; ------------------------------------------------------------------------------
map_reset:
    push si
    push di
    push cx
    push ds
    push es

    push cs
    pop ds              ; DS = CS
    push cs
    pop es              ; ES = CS

    lea si, [original_map]
    lea di, [working_map]
    mov cx, MAP_SIZE    ; 720 bytes
    cld                 ; Forward direction
    rep movsb           ; Copy original map to working map

    pop es
    pop ds
    pop cx
    pop di
    pop si
    ret

; ------------------------------------------------------------------------------
; map_get_tile
; Purpose : Get tile code at world pixel coordinate (px, py) from working_map
; Stack   : [bp+6] = px (0 to 959)
;           [bp+4] = py (0 to 191)
; Returns : AL = tile code (0 to 12). If out of bounds, returns TILE_SKY (0).
; Preserves other registers, cleans 4 bytes (ret 4)
; ------------------------------------------------------------------------------
map_get_tile:
    push bp
    mov bp, sp
    push bx
    push dx

    mov ax, [bp+6]      ; ax = px
    mov bx, [bp+4]      ; bx = py

    ; Check bounds: px < 960 (60 * 16), py < 192 (12 * 16)
    cmp ax, WORLD_WIDTH_PX
    jae .out_of_bounds
    cmp bx, 192
    jae .out_of_bounds

    ; col = px >> 4, row = py >> 4
    shr ax, 4           ; ax = col (0 to 59)
    shr bx, 4           ; bx = row (0 to 11)

    ; offset = row * 60 + col = (row << 6) - (row << 2) + col
    mov dx, bx
    shl dx, 6           ; dx = row * 64
    shl bx, 2           ; bx = row * 4
    sub dx, bx          ; dx = row * 60
    add dx, ax          ; dx = row * 60 + col

    mov bx, dx
    mov al, [working_map + bx] ; Read tile code from working map
    jmp .done

.out_of_bounds:
    xor al, al          ; Return 0 (TILE_SKY)

.done:
    pop dx
    pop bx
    pop bp
    ret 4

; ------------------------------------------------------------------------------
; map_set_tile
; Purpose : Write tile code into working_map at (col, row)
; Stack   : [bp+8] = col  (0 to 59)
;           [bp+6] = row  (0 to 11)
;           [bp+4] = tile_code (0 to 12)
; Preserves all registers, cleans 6 bytes (ret 6)
; ------------------------------------------------------------------------------
map_set_tile:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx

    mov ax, [bp+8]      ; col
    mov bx, [bp+6]      ; row
    cmp ax, MAP_COLS
    jae .done
    cmp bx, MAP_ROWS
    jae .done

    mov dx, bx
    shl dx, 6
    shl bx, 2
    sub dx, bx          ; dx = row * 60
    add dx, ax          ; dx = row * 60 + col

    mov bx, dx
    mov al, [bp+4]
    mov [working_map + bx], al

.done:
    pop dx
    pop bx
    pop ax
    pop bp
    ret 6

; ------------------------------------------------------------------------------
; map_draw_tile
; Purpose : Render a 16x16 tile at screen coordinate (x, y) into segment in ES
; Stack   : [bp+8] = screen_x
;           [bp+6] = screen_y
;           [bp+4] = tile_code
; Uses Jump Table for O(1) branch dispatch
; Preserves all registers, cleans 6 bytes (ret 6)
; ------------------------------------------------------------------------------
map_draw_tile:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov bx, [bp+8]      ; bx = x
    mov dx, [bp+6]      ; dx = y
    mov ax, [bp+4]      ; ax = tile_code

    ; Clamp tile code
    cmp ax, 12
    jbe .valid_tile
    jmp .done
.valid_tile:

    ; Jump table dispatch: table base + (tile_code * 2)
    mov si, ax
    shl si, 1
    jmp [cs:.tile_jump_table + si]

.tile_jump_table:
    dw .draw_sky        ; 0
    dw .draw_ground     ; 1
    dw .draw_brick      ; 2
    dw .draw_q_blk      ; 3 (? coin)
    dw .draw_q_blk      ; 4 (? mushroom)
    dw .draw_empty_blk  ; 5
    dw .draw_pipe_tl    ; 6
    dw .draw_pipe_tr    ; 7
    dw .draw_pipe_bl    ; 8
    dw .draw_pipe_br    ; 9
    dw .draw_stair      ; 10
    dw .draw_coin       ; 11
    dw .draw_flagpole   ; 12

.draw_sky:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_SKY
    call vid_fill_rect
    jmp .done

.draw_ground:
    ; Base brown dirt
    push bx
    push dx
    push word 16
    push word 16
    push word COL_GROUND
    call vid_fill_rect

    ; Green grass trim on top edge (2px)
    push bx
    push dx
    push word 16
    push word 2
    push word COL_LIGHT_GREEN
    call vid_fill_rect
    jmp .done

.draw_brick:
    ; Red brick block
    push bx
    push dx
    push word 16
    push word 16
    push word COL_BRICK
    call vid_fill_rect

    ; Horizontal mortar line at y+7
    mov ax, dx
    add ax, 7
    push bx
    push ax
    push word 16
    push word 1
    push word COL_MORTAR
    call vid_fill_rect

    ; Horizontal mortar line at y+15
    mov ax, dx
    add ax, 15
    push bx
    push ax
    push word 16
    push word 1
    push word COL_MORTAR
    call vid_fill_rect

    ; Vertical mortar tick top half at x+7
    mov ax, bx
    add ax, 7
    push ax
    push dx
    push word 1
    push word 7
    push word COL_MORTAR
    call vid_fill_rect

    ; Vertical mortar tick bottom half at x+3
    mov ax, bx
    add ax, 3
    push ax
    mov ax, dx
    add ax, 8
    push ax
    push word 1
    push word 7
    push word COL_MORTAR
    call vid_fill_rect
    jmp .done

.draw_q_blk:
    ; Yellow block body
    push bx
    push dx
    push word 16
    push word 16
    push word COL_YELLOW
    call vid_fill_rect

    ; Dark brown border
    push bx
    push dx
    push word 16
    push word 1
    push word COL_BROWN
    call vid_fill_rect
    push bx
    push dx
    push word 1
    push word 16
    push word COL_BROWN
    call vid_fill_rect

    ; Question mark accent in center
    mov ax, bx
    add ax, 6
    mov cx, dx
    add cx, 4
    push ax
    push cx
    push word 4
    push word 2
    push word COL_WHITE
    call vid_fill_rect

    mov ax, bx
    add ax, 7
    mov cx, dx
    add cx, 11
    push ax
    push cx
    push word 2
    push word 2
    push word COL_WHITE
    call vid_fill_rect
    jmp .done

.draw_empty_blk:
    ; Dark gray block with rivet corners
    push bx
    push dx
    push word 16
    push word 16
    push word COL_DARK_GRAY
    call vid_fill_rect

    push bx
    push dx
    push word 16
    push word 1
    push word COL_LIGHT_GRAY
    call vid_fill_rect

    push bx
    push dx
    push word 1
    push word 16
    push word COL_LIGHT_GRAY
    call vid_fill_rect
    jmp .done

.draw_pipe_tl:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_PIPE
    call vid_fill_rect

    push bx
    push dx
    push word 16
    push word 2
    push word COL_PIPE_LIP
    call vid_fill_rect
    jmp .done

.draw_pipe_tr:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_PIPE
    call vid_fill_rect

    push bx
    push dx
    push word 16
    push word 2
    push word COL_PIPE_LIP
    call vid_fill_rect
    jmp .done

.draw_pipe_bl:
.draw_pipe_br:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_PIPE
    call vid_fill_rect
    jmp .done

.draw_stair:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_BROWN
    call vid_fill_rect

    push bx
    push dx
    push word 16
    push word 1
    push word COL_WHITE
    call vid_fill_rect
    jmp .done

.draw_coin:
    ; Sky background behind coin
    push bx
    push dx
    push word 16
    push word 16
    push word COL_SKY
    call vid_fill_rect

    ; Yellow coin body
    mov ax, bx
    add ax, 4
    mov cx, dx
    add cx, 2
    push ax
    push cx
    push word 8
    push word 12
    push word COL_YELLOW
    call vid_fill_rect

    ; White inner shine
    mov ax, bx
    add ax, 6
    mov cx, dx
    add cx, 4
    push ax
    push cx
    push word 2
    push word 8
    push word COL_WHITE
    call vid_fill_rect
    jmp .done

.draw_flagpole:
    push bx
    push dx
    push word 16
    push word 16
    push word COL_SKY
    call vid_fill_rect

    ; White pole line in center
    mov ax, bx
    add ax, 7
    push ax
    push dx
    push word 2
    push word 16
    push word COL_WHITE
    call vid_fill_rect
    jmp .done

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6

; ------------------------------------------------------------------------------
; map_draw
; Purpose : Render visible viewport of level map (20 visible columns + 1 partial)
; Stack   : [bp+4] = camera_x (0 to 640)
; Segment : Draws into segment in ES
; Preserves all registers, cleans 2 bytes (ret 2)
; ------------------------------------------------------------------------------
map_draw:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, [bp+4]      ; ax = camera_x
    cmp ax, MAX_CAMERA_X
    jbe .cam_ok
    mov ax, MAX_CAMERA_X
.cam_ok:

    ; first_col = camera_x / 16 = camera_x >> 4
    mov si, ax
    shr si, 4           ; si = first_col (0 to 40)

    ; x_offset = -(camera_x mod 16) = -(camera_x & 15)
    and ax, 15
    neg ax
    mov di, ax          ; di = starting screen_x

    ; Loop through 21 columns (col_idx from 0 to 20)
    mov cx, 21
.col_loop:
    push cx             ; Save remaining columns count

    ; Calculate screen_x for current column: di
    ; Calculate map_col: si
    cmp si, MAP_COLS
    jae .next_col       ; Beyond end of level

    ; Loop through rows 1 to 11 (row 0 is HUD strip)
    mov dx, 1           ; dx = row
.row_loop:
    push dx             ; Save current row

    ; Calculate tile index: row * 60 + col
    mov ax, dx
    shl ax, 6           ; ax = row * 64
    mov bx, dx
    shl bx, 2           ; bx = row * 4
    sub ax, bx          ; ax = row * 60
    add ax, si          ; ax = row * 60 + col

    mov bx, ax
    xor ax, ax
    mov al, [working_map + bx] ; al = tile_code

    ; Compute screen_y = row * 16 = row << 4
    pop dx
    push dx
    mov bx, dx
    shl bx, 4           ; bx = screen_y

    ; Push parameters for map_draw_tile(screen_x, screen_y, tile_code)
    push di             ; screen_x
    push bx             ; screen_y
    push ax             ; tile_code
    call map_draw_tile

    pop dx
    inc dx
    cmp dx, MAP_ROWS
    jb .row_loop

.next_col:
    add di, 16          ; screen_x += 16
    inc si              ; map_col++
    pop cx
    dec cx
    jnz .col_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ==============================================================================
; Level 1-1 Master Map Data (60 Columns x 12 Rows = 720 bytes)
; Meets all requirements of Section 5.15
; ==============================================================================
original_map:
    ; Row 0: HUD strip (reserved)
    times 60 db TILE_SKY

    ; Row 1: Sky
    times 60 db TILE_SKY

    ; Row 2: Air + Flagpole Top (col 55)
    times 55 db TILE_SKY
    db TILE_FLAGPOLE
    times 4  db TILE_SKY

    ; Row 3: Air + Flagpole (col 55)
    times 55 db TILE_SKY
    db TILE_FLAGPOLE
    times 4  db TILE_SKY

    ; Row 4: Coins at cols 15-16, Flagpole at col 55
    times 15 db TILE_SKY
    db TILE_COIN, TILE_COIN
    times 38 db TILE_SKY
    db TILE_FLAGPOLE
    times 4  db TILE_SKY

    ; Row 5: Coins at cols 51-52, Flagpole at col 55
    times 51 db TILE_SKY
    db TILE_COIN, TILE_COIN
    times 2  db TILE_SKY
    db TILE_FLAGPOLE
    times 4  db TILE_SKY

    ; Row 6: Interactive Blocks, Bricks, Stairs, Flagpole
    times 8  db TILE_SKY
    db TILE_Q_COIN                          ; col 8 (? coin)
    times 3  db TILE_SKY
    db TILE_Q_MUSHROOM                      ; col 12 (? mushroom)
    db TILE_SKY
    db TILE_BRICK, TILE_Q_COIN, TILE_BRICK, TILE_BRICK ; cols 14-17
    times 10 db TILE_SKY
    db TILE_BRICK, TILE_BRICK, TILE_BRICK   ; cols 28-30
    times 12 db TILE_SKY
    db TILE_Q_MUSHROOM                      ; col 43 (? mushroom)
    db TILE_BRICK, TILE_BRICK, TILE_BRICK, TILE_BRICK ; cols 44-47
    db TILE_SKY
    times 4  db TILE_SKY                    ; cols 49-51
    db TILE_STAIR                           ; col 52 (stair top)
    times 2  db TILE_SKY
    db TILE_FLAGPOLE                        ; col 55
    times 4  db TILE_SKY

    ; Row 7: Coins over pits, Pipe 2 Top, Stairs, Flagpole
    times 18 db TILE_SKY
    db TILE_COIN, TILE_COIN, TILE_COIN      ; cols 18-20 (coins over pit 1)
    times 12 db TILE_SKY
    db TILE_PIPE_TL, TILE_PIPE_TR           ; cols 33-34 (pipe 2 top)
    times 3  db TILE_SKY
    db TILE_COIN, TILE_COIN, TILE_COIN      ; cols 38-40 (coins over pit 2)
    times 10 db TILE_SKY
    db TILE_STAIR, TILE_STAIR               ; cols 51-52 (stairs)
    times 2  db TILE_SKY
    db TILE_FLAGPOLE                        ; col 55
    times 4  db TILE_SKY

    ; Row 8: Pipe 1 Top, Pipe 2 Body, Stairs, Flagpole
    times 24 db TILE_SKY
    db TILE_PIPE_TL, TILE_PIPE_TR           ; cols 24-25 (pipe 1 top)
    times 7  db TILE_SKY
    db TILE_PIPE_BL, TILE_PIPE_BR           ; cols 33-34 (pipe 2 body)
    times 15 db TILE_SKY
    db TILE_STAIR, TILE_STAIR, TILE_STAIR   ; cols 50-52 (stairs)
    times 2  db TILE_SKY
    db TILE_FLAGPOLE                        ; col 55
    times 4  db TILE_SKY

    ; Row 9: Surface level (walk surface, pipe bodies, stairs base, castle)
    times 24 db TILE_SKY
    db TILE_PIPE_BL, TILE_PIPE_BR           ; cols 24-25 (pipe 1 body)
    times 7  db TILE_SKY
    db TILE_PIPE_BL, TILE_PIPE_BR           ; cols 33-34 (pipe 2 body)
    times 14 db TILE_SKY
    db TILE_STAIR, TILE_STAIR, TILE_STAIR, TILE_STAIR ; cols 49-52
    times 2  db TILE_SKY
    db TILE_STAIR                           ; col 55 (flagpole base block)
    db TILE_SKY
    db TILE_BRICK, TILE_BRICK, TILE_BRICK   ; cols 57-59 (castle)

    ; Row 10: Ground Layer 1 (Ground everywhere EXCEPT Pit 1 and Pit 2)
    times 18 db TILE_GROUND                 ; cols 0-17
    times 3  db TILE_SKY                    ; cols 18-20 (PIT 1)
    times 17 db TILE_GROUND                 ; cols 21-37
    times 3  db TILE_SKY                    ; cols 38-40 (PIT 2)
    times 19 db TILE_GROUND                 ; cols 41-59

    ; Row 11: Ground Layer 2 (Bedrock)
    times 18 db TILE_GROUND                 ; cols 0-17
    times 3  db TILE_SKY                    ; cols 18-20 (PIT 1)
    times 17 db TILE_GROUND                 ; cols 21-37
    times 3  db TILE_SKY                    ; cols 38-40 (PIT 2)
    times 19 db TILE_GROUND                 ; cols 41-59

; Runtime working copy of the level map (dynamically modified during play)
working_map:
    times MAP_SIZE db 0
