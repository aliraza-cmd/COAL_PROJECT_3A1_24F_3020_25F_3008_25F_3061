; ==============================================================================
; mario.asm - Super Mario Engine Entry Point & Ali's Complete Engine Showcase
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
    ; --------------------------------------------------------------------------
    ; Step 1: Shrink current memory block to 64 KB (4096 paragraphs = 1000h)
    ; --------------------------------------------------------------------------
    mov bx, 0x1000          ; 4096 paragraphs = 65,536 bytes (64 KB)
    mov ah, 0x4A            ; DOS function: resize allocated memory block
    int 0x21
    jnc .shrink_ok
    jmp memory_allocation_failed
.shrink_ok:

    ; --------------------------------------------------------------------------
    ; Step 2: Allocate dedicated segment for off-screen backbuffer (64,000 bytes)
    ; --------------------------------------------------------------------------
    mov bx, FRAME_PARAS     ; 4000 paragraphs = 64,000 bytes
    mov ah, 0x48            ; DOS function: allocate memory block
    int 0x21
    jnc .alloc_ok
    jmp memory_allocation_failed
.alloc_ok:
    mov [frame_buffer_seg], ax

    ; --------------------------------------------------------------------------
    ; Step 3: Initialize Level Map
    ; Reset working_map from original_map using REP MOVSB
    ; --------------------------------------------------------------------------
    call map_reset

    ; --------------------------------------------------------------------------
    ; Step 4: Switch to VGA Mode 13h Graphics (320x200, 256 colors)
    ; --------------------------------------------------------------------------
    call vid_set_mode_13h

    ; ==========================================================================
    ; DEMO PART A: Sprite Exhibition, Mirroring & 4-Edge Clipping (Milestone 4)
    ; All rendering is drawn into off-screen backbuffer in ES = frame_buffer_seg
    ; ==========================================================================
    mov ax, [frame_buffer_seg]
    mov es, ax

    ; 1. Clear off-screen backbuffer to sky color using REP STOSW
    push word COL_SKY
    call vid_clear_buffer

    ; 2. Render visible level map into backbuffer
    push word 0             ; camera_x = 0
    call map_draw

    ; 3. Draw Small Mario (16x16) - Standing facing RIGHT
    push word 32            ; x
    push word 128           ; y
    push word spr_mario_stand ; sprite ptr
    push word 16            ; height
    push word SPR_FLAG_NORMAL ; normal (right)
    call draw_sprite

    ; 4. Draw Small Mario (16x16) - Running facing LEFT (Mirrored!)
    push word 64            ; x
    push word 128           ; y
    push word spr_mario_run
    push word 16
    push word SPR_FLAG_MIRROR ; mirrored (left)
    call draw_sprite

    ; 5. Draw Small Mario (16x16) - Jumping
    push word 96            ; x
    push word 80            ; y
    push word spr_mario_jump
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 6. Draw Super Mario (16x32) - Standing (Tall hero form)
    push word 128           ; x
    push word 112           ; y (feet at y=144, so top is 144 - 32 = 112)
    push word spr_super_stand
    push word 32            ; 32 pixels tall!
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 7. Draw Goomba (16x16) - Walking
    push word 160           ; x
    push word 128           ; y
    push word spr_goomba_walk
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 8. Draw Goomba (16x16) - Flat / Stomped
    push word 184           ; x
    push word 128           ; y
    push word spr_goomba_flat
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 9. Draw Koopa Troopa (16x16) - Walking facing LEFT (Mirrored!)
    push word 210           ; x
    push word 128           ; y
    push word spr_koopa_walk
    push word 16
    push word SPR_FLAG_MIRROR
    call draw_sprite

    ; 10. Draw Koopa Shell (16x16)
    push word 234           ; x
    push word 128           ; y
    push word spr_koopa_shell
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 11. Draw Super Mushroom (16x16)
    push word 112           ; x
    push word 80            ; y (on top of block)
    push word spr_mushroom
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 12. Draw Collectible Coin (16x16)
    push word 144           ; x
    push word 80            ; y
    push word spr_coin
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 13. Test 4-Edge Clipping (Partial off-screen sprites)
    ; Left edge clip: x = -6
    push word -6
    push word 128
    push word spr_mario_stand
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; Right edge clip: x = 312
    push word 312
    push word 128
    push word spr_mario_stand
    push word 16
    push word SPR_FLAG_MIRROR
    call draw_sprite

    ; 14. Blit backbuffer to video memory using high-speed REP MOVSW
    call vid_blit_buffer

    ; Wait for key press before starting motion demo
    mov ah, 0x00
    int 0x16

    ; ==========================================================================
    ; DEMO PART B: Flicker-Free Double Buffering Animation (Milestone 5)
    ; Smoothly animates Mario running across the screen with zero screen flicker!
    ; ==========================================================================
    mov si, 16              ; si = mario_x (moves from 16 to 280)
    mov di, 280             ; di = goomba_x (moves from 280 down to 16)

.motion_loop:
    ; 1. Clear backbuffer
    push word COL_SKY
    call vid_clear_buffer

    ; 2. Render level map into backbuffer
    push word 0             ; camera_x = 0
    call map_draw

    ; 3. Draw Mario running at current X position
    push si                 ; x
    push word 128           ; y
    push word spr_mario_run
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 4. Draw Goomba walking at current X position
    push di                 ; x
    push word 128           ; y
    push word spr_goomba_walk
    push word 16
    push word SPR_FLAG_NORMAL
    call draw_sprite

    ; 5. Wait for vertical retrace to prevent scanline tearing
    call vid_wait_vsync

    ; 6. Blit entire backbuffer to screen
    call vid_blit_buffer

    ; Update positions
    add si, 2               ; Mario moves right by 2 pixels
    sub di, 1               ; Goomba moves left by 1 pixel

    ; Wrap around when Mario reaches end
    cmp si, 280
    jb .check_input
    mov si, 16
    mov di, 280

.check_input:
    ; Check if user pressed any key to exit (non-blocking check: INT 16h, AH=01h)
    mov ah, 0x01
    int 0x16
    jnz .motion_done        ; Key was pressed! Exit demo

    ; Add tiny delay between frames (~30 FPS pacing)
    mov cx, 0x5FFF
.delay_loop:
    loop .delay_loop

    jmp .motion_loop

.motion_done:
    ; Clear the key from BIOS keyboard buffer
    mov ah, 0x00
    int 0x16

    ; --------------------------------------------------------------------------
    ; Step 5: Clean Shutdown
    ; Restore text mode, free memory segment, and return cleanly to DOS
    ; --------------------------------------------------------------------------
    call vid_restore_text_mode

    mov es, [frame_buffer_seg]
    mov ah, 0x49            ; Free allocated memory
    int 0x21

    mov ax, 0x4C00          ; Clean exit to DOS
    int 0x21

memory_allocation_failed:
    mov dx, msg_mem_err
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C01
    int 0x21
