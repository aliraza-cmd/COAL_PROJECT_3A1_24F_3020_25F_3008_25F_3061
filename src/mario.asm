; ==============================================================================
; mario.asm - Super Mario Engine Entry Point & Game Loop
; Course: EL2003 Computer Organization & Assembly Language
; Author: Ali Raza (24F-3020) | Group: Ali, Umama, Aiza (BSE-3A1)
; ==============================================================================
[org 0x0100]

jmp start_program

; --- Architecture & Global Inclusions ---
%include "src\const.inc"
%include "src\data.inc"
%include "src\video.asm"
%include "src\map.asm"
%include "src\sprites.asm"

; ------------------------------------------------------------------------------
; Main Program Entry Point
; ------------------------------------------------------------------------------
start_program:
    ; 1. Shrink current memory block to 64 KB
    mov bx, 0x1000
    mov ah, 0x4A
    int 0x21
    jnc .shrink_ok
    jmp memory_allocation_failed
.shrink_ok:

    ; 2. Allocate 64,000-byte segment for off-screen backbuffer
    mov bx, FRAME_PARAS
    mov ah, 0x48
    int 0x21
    jnc .alloc_ok
    jmp memory_allocation_failed
.alloc_ok:
    mov [frame_buffer_seg], ax

    ; 3. Initialize Level Map
    call map_reset

    ; 4. Switch to VGA Mode 13h (320x200, 256 colors)
    call vid_set_mode_13h

    ; Target segment for all rendering routines is the off-screen backbuffer
    mov ax, [frame_buffer_seg]
    mov es, ax

    ; --------------------------------------------------------------------------
    ; Interactive Engine Loop (Ali's Completed Foundation & Graphics)
    ; Mario starts on the ground at (x=40, y=144)
    ; --------------------------------------------------------------------------
    mov word [plr_x], 40
    mov word [plr_y], 144
    mov word [plr_facing], SPR_FLAG_NORMAL

.main_game_loop:
    ; 1. Clear backbuffer to Sky Blue
    push word COL_SKY
    call vid_clear_buffer

    ; 2. Render Level 1-1 Map into backbuffer
    push word 0             ; camera_x = 0
    call map_draw

    ; 3. Draw Goomba on ground (x=176, y=144)
    push word 176
    push word 144
    push word spr_goomba_walk
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 4. Draw Koopa Troopa on ground (x=240, y=144, facing left)
    push word 240
    push word 144
    push word spr_koopa_walk
    push word 16
    push word SPR_FLAG_MIRROR
    call draw_sprite

    ; 5. Draw Super Mushroom on top of block (x=192, y=80)
    push word 192
    push word 80
    push word spr_mushroom
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 6. Draw Collectible Coin in air (x=112, y=64)
    push word 112
    push word 64
    push word spr_coin
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 7. Draw Player Mario at (plr_x, plr_y) with current facing direction
    push word [plr_x]
    push word [plr_y]
    push word spr_mario_stand
    push word 16
    push word [plr_facing]
    call draw_sprite

    ; 8. Draw Top HUD Bar
    ; Draw dark HUD banner strip across top (row 0: 320x16)
    push word 0
    push word 0
    push word 320
    push word 16
    push word COL_DARK_GRAY
    call vid_fill_rect

    ; Draw 2 Health Hearts in HUD
    push word 280
    push word 4
    push word 6
    push word 6
    push word COL_RED
    call vid_fill_rect

    push word 292
    push word 4
    push word 6
    push word 6
    push word COL_RED
    call vid_fill_rect

    ; 9. Wait for vertical retrace (prevents screen tearing)
    call vid_wait_vsync

    ; 10. Blit completed backbuffer to VGA Video Memory (0A000h:0000)
    call vid_blit_buffer

    ; --------------------------------------------------------------------------
    ; Handle Keyboard Input (BIOS INT 16h)
    ; --------------------------------------------------------------------------
    mov ah, 0x01            ; Check if keystroke is pending
    int 0x16
    jz .frame_delay         ; No key pressed -> continue loop

    mov ah, 0x00            ; Read keystroke (AH = scan code, AL = ASCII)
    int 0x16

    ; Esc key (Scan code 01h or ASCII 27) -> Exit game
    cmp al, 27
    je .exit_game
    cmp ah, 0x01
    je .exit_game

    ; Left Arrow (Scan code 4Bh) -> Move Mario Left & Mirror Sprite
    cmp ah, 0x4B
    jne .check_right
    cmp word [plr_x], 8
    jle .frame_delay
    sub word [plr_x], 4
    mov word [plr_facing], SPR_FLAG_MIRROR
    jmp .frame_delay

.check_right:
    ; Right Arrow (Scan code 4Dh) -> Move Mario Right & Normal Sprite
    cmp ah, 0x4D
    jne .check_space
    cmp word [plr_x], 296
    jge .frame_delay
    add word [plr_x], 4
    mov word [plr_facing], SPR_FLAG_NORMAL
    jmp .frame_delay

.check_space:
    ; Spacebar (ASCII 32 or scan code 39h) -> Jump hop!
    cmp al, 32
    jne .frame_delay
    sub word [plr_y], 24    ; Jump hop upwards
    call vid_wait_vsync
    ; Delay slightly then land
    add word [plr_y], 24

.frame_delay:
    ; Small pacing delay (~30 FPS)
    mov cx, 0x3FFF
.delay_loop:
    loop .delay_loop

    jmp .main_game_loop

.exit_game:
    ; --------------------------------------------------------------------------
    ; Clean Shutdown: Restore text mode, free memory, return to DOS
    ; --------------------------------------------------------------------------
    call vid_restore_text_mode

    mov es, [frame_buffer_seg]
    mov ah, 0x49            ; Free allocated memory segment
    int 0x21

    mov ax, 0x4C00          ; Clean exit to DOS prompt
    int 0x21

memory_allocation_failed:
    mov dx, msg_mem_err
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C01
    int 0x21

; ------------------------------------------------------------------------------
; Local Variables
; ------------------------------------------------------------------------------
plr_x       dw 40
plr_y       dw 144
plr_facing  dw 0
