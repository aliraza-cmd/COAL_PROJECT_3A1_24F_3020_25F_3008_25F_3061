; ==============================================================================
; video.asm - VGA Mode 13h Primitives & Double Buffering
; Course: EL2003 Computer Organization & Assembly Language
; Author: Ali Raza (24F-3020) | Group BSE-3A1
; ==============================================================================

; ------------------------------------------------------------------------------
; vid_set_mode_13h
; Switch to 320x200 256-color Mode 13h
; ------------------------------------------------------------------------------
vid_set_mode_13h:
    push ax
    mov ax, 0x0013
    int 0x10
    pop ax
    ret

; ------------------------------------------------------------------------------
; vid_restore_text_mode
; Restore 80x25 text mode (Mode 03h)
; ------------------------------------------------------------------------------
vid_restore_text_mode:
    push ax
    mov ax, 0x0003
    int 0x10
    pop ax
    ret

; ------------------------------------------------------------------------------
; vid_put_pixel
; Stack : [bp+8] = x, [bp+6] = y, [bp+4] = color
; Target: Segment in ES
; ------------------------------------------------------------------------------
vid_put_pixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push di

    mov ax, [bp+8]          ; x
    cmp ax, SCREEN_WIDTH
    jae .done

    mov bx, [bp+6]          ; y
    cmp bx, SCREEN_HEIGHT
    jae .done

    ; Offset = (y << 8) + (y << 6) + x
    mov ax, bx
    shl ax, 8
    shl bx, 6
    add ax, bx
    add ax, [bp+8]
    mov di, ax

    mov al, [bp+4]          ; color
    mov [es:di], al

.done:
    pop di
    pop bx
    pop ax
    pop bp
    ret 6

; ------------------------------------------------------------------------------
; vid_fill_rect
; Stack : [bp+12] = x, [bp+10] = y, [bp+8] = w, [bp+6] = h, [bp+4] = color
; Target: Segment in ES
; ------------------------------------------------------------------------------
vid_fill_rect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di

    mov dx, [bp+6]          ; h
    test dx, dx
    jle .exit
    mov bx, [bp+8]          ; w
    test bx, bx
    jle .exit

    ; Clip top/left if negative
    mov ax, [bp+10]         ; y
    cmp ax, SCREEN_HEIGHT
    jge .exit

    mov cx, [bp+12]         ; x
    cmp cx, SCREEN_WIDTH
    jge .exit

    ; Calculate start offset: (y << 8) + (y << 6) + x
    mov bx, ax
    shl ax, 8
    shl bx, 6
    add ax, bx
    add ax, cx
    mov di, ax

    mov al, [bp+4]          ; color
    cld

.row_loop:
    mov cx, [bp+8]          ; width
    push di
    rep stosb
    pop di
    add di, SCREEN_WIDTH    ; next row
    dec dx
    jnz .row_loop

.exit:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; ------------------------------------------------------------------------------
; vid_clear_buffer
; Stack : [bp+4] = color (word)
; Target: Segment in frame_buffer_seg
; ------------------------------------------------------------------------------
vid_clear_buffer:
    push bp
    mov bp, sp
    push ax
    push cx
    push di
    push es

    mov es, [cs:frame_buffer_seg]
    xor di, di

    mov al, [bp+4]
    mov ah, al              ; Word of 2 pixels (e.g. 0909h)
    mov cx, 32000           ; 32,000 words = 64,000 bytes
    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------------------------
; vid_blit_buffer
; Copies frame_buffer_seg:0000 -> 0A000h:0000
; ------------------------------------------------------------------------------
vid_blit_buffer:
    push ds
    push es
    push si
    push di
    push cx
    push ax

    mov ax, 0x0A000
    mov es, ax
    xor di, di

    mov ds, [cs:frame_buffer_seg]
    xor si, si

    mov cx, 32000
    cld
    rep movsw

    pop ax
    pop cx
    pop di
    pop si
    pop es
    pop ds
    ret

; ------------------------------------------------------------------------------
; vid_wait_vsync
; Wait for vertical blanking interval (port 03DAh bit 3)
; ------------------------------------------------------------------------------
vid_wait_vsync:
    push ax
    push dx
    mov dx, 0x03DA
.v_end:
    in al, dx
    test al, 8
    jnz .v_end
.v_start:
    in al, dx
    test al, 8
    jz .v_start
    pop dx
    pop ax
    ret
