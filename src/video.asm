; ==============================================================================
; video.asm - VGA Mode 13h Primitives & Drawing Engine
; Course: EL2003 Computer Organization & Assembly Language
; Author: Ali Raza (24F-3020) | Group BSE-3A1
; ==============================================================================

; ------------------------------------------------------------------------------
; vid_set_mode_13h
; Purpose : Switch video subsystem to VGA Mode 13h (320x200, 256 colors)
; Inputs  : None
; Outputs : Screen switched to 320x200 256-color graphics mode
; Preserves all registers
; ------------------------------------------------------------------------------
vid_set_mode_13h:
    push ax
    mov ax, 0x0013      ; AH=00h (Set Video Mode), AL=13h (320x200 256-color)
    int 0x10
    pop ax
    ret

; ------------------------------------------------------------------------------
; vid_restore_text_mode
; Purpose : Restore standard 80x25 16-color text mode (Mode 03h)
; Inputs  : None
; Outputs : Screen restored to DOS text mode
; Preserves all registers
; ------------------------------------------------------------------------------
vid_restore_text_mode:
    push ax
    mov ax, 0x0003      ; AH=00h (Set Video Mode), AL=03h (80x25 Color Text)
    int 0x10
    pop ax
    ret

; ------------------------------------------------------------------------------
; vid_put_pixel
; Purpose : Draw a single pixel at (x, y) with color into segment in ES
; Stack   : [bp+8] = x coordinate (0 to 319)
;           [bp+6] = y coordinate (0 to 199)
;           [bp+4] = color index  (0 to 255)
; Formula : offset = (y * 320) + x = (y << 8) + (y << 6) + x
; Preserves all registers, cleans 6 bytes from stack (ret 6)
; ------------------------------------------------------------------------------
vid_put_pixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push di

    ; Boundary check: x in [0, 319], y in [0, 199]
    mov ax, [bp+8]      ; ax = x
    cmp ax, SCREEN_WIDTH
    jae .done           ; Unsigned check covers both < 0 (high value) and >= 320

    mov bx, [bp+6]      ; bx = y
    cmp bx, SCREEN_HEIGHT
    jae .done           ; Unsigned check covers < 0 and >= 200

    ; Fast linear offset calculation: (y << 8) + (y << 6) + x
    mov ax, bx          ; ax = y
    shl ax, 8           ; ax = y * 256
    shl bx, 6           ; bx = y * 64
    add ax, bx          ; ax = y * 320
    add ax, [bp+8]      ; ax = y * 320 + x
    mov di, ax          ; di = offset in ES segment

    ; Write pixel byte
    mov al, [bp+4]      ; al = color
    mov [es:di], al

.done:
    pop di
    pop bx
    pop ax
    pop bp
    ret 6

; ------------------------------------------------------------------------------
; vid_fill_rect
; Purpose : Draw a filled rectangle of size (w, h) at (x, y) in segment ES
; Stack   : [bp+12] = x coordinate (top-left)
;           [bp+10] = y coordinate (top-left)
;           [bp+8]  = width  (w)
;           [bp+6]  = height (h)
;           [bp+4]  = color index
; Uses REP STOSB for row filling
; Preserves all registers, cleans 10 bytes from stack (ret 10)
; ------------------------------------------------------------------------------
vid_fill_rect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di

    ; Validate height and width
    mov dx, [bp+6]      ; dx = rows remaining (h)
    test dx, dx
    jle .done
    mov bx, [bp+8]      ; bx = width (w)
    test bx, bx
    jle .done

    ; Calculate initial top-left offset: (y << 8) + (y << 6) + x
    mov ax, [bp+10]     ; ax = y
    mov cx, ax          ; cx = y
    shl ax, 8           ; ax = y * 256
    shl cx, 6           ; cx = y * 64
    add ax, cx          ; ax = y * 320
    add ax, [bp+12]     ; ax = (y * 320) + x
    mov di, ax          ; di = starting offset in ES

    mov al, [bp+4]      ; al = color byte
    cld                 ; String direction forward (increment DI)

.row_loop:
    mov cx, [bp+8]      ; cx = width of row
    push di             ; Save starting offset of current row
    rep stosb           ; Draw row of pixels into ES:[di]
    pop di              ; Restore starting offset
    add di, SCREEN_WIDTH ; Advance to start of next scanline
    dec dx              ; Decrement remaining row count
    jnz .row_loop

.done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10
