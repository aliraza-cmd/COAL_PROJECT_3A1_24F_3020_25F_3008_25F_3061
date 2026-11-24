; ==============================================================================
; mario.asm - Super Mario Engine Entry Point & Lifecycle Controller
; Course: EL2003 Computer Organization & Assembly Language
; Group: Ali Raza (24F-3020), Umama (25F-3008), Aiza (25F-3061)
; Section: BSE-3A1 | Fall 2026
; ==============================================================================
[org 0x0100]

jmp start_program

; --- Architecture & Global Inclusions ---
%include "src\const.inc"
%include "src\data.inc"
%include "src\video.asm"
%include "src\map.asm"

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
    ; Step 4: Milestone 3 Test Harness - Render Level 1-1 Viewport
    ; Switch to VGA Mode 13h and render map at Camera X = 0
    ; --------------------------------------------------------------------------
    call vid_set_mode_13h

    ; Point ES to Video Memory (0A000h)
    mov ax, 0x0A000
    mov es, ax

    ; Draw Screen 1 (camera_x = 0): Start area, ? blocks, Pipe 1, Pit 1
    push word 0
    call map_draw

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Draw Screen 2 (camera_x = 240): Mid area, Pipe 2, Pit 2, Bricks
    push word 240
    call map_draw

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Draw Screen 3 (camera_x = 480): End area, Stairs, Flagpole, Castle
    push word 480
    call map_draw

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Test Dynamic Tile Modification & ResetMap:
    ; 1. Break brick at (col 14, row 6) by turning it to TILE_SKY (0)
    push word 14            ; col = 14
    push word 6             ; row = 6
    push word TILE_SKY      ; tile = 0
    call map_set_tile

    ; Redraw view 1 with broken brick
    push word 0
    call map_draw

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; 2. Call map_reset to restore original_map -> brick reappears!
    call map_reset
    push word 0
    call map_draw

    ; Wait for final key press before exiting
    mov ah, 0x00
    int 0x16

    ; --------------------------------------------------------------------------
    ; Step 5: Clean Shutdown
    ; Restore text mode, free memory segment, and return to DOS
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
