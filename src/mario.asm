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
    ; Step 3: Milestone 2 Test Harness - VGA Mode 13h & Drawing Primitives
    ; Switch to graphics mode 13h and render test scene
    ; --------------------------------------------------------------------------
    call vid_set_mode_13h

    ; Set ES to point to Video Memory segment (0A000h) for direct display
    mov ax, 0x0A000
    mov es, ax

    ; 1. Draw Sky Background: FillRect(0, 0, 320, 200, COL_SKY)
    push word 0             ; x = 0
    push word 0             ; y = 0
    push word SCREEN_WIDTH  ; w = 320
    push word SCREEN_HEIGHT ; h = 200
    push word COL_SKY       ; color = 9 (Light Blue)
    call vid_fill_rect

    ; 2. Draw Ground Base: FillRect(0, 160, 320, 40, COL_GROUND)
    push word 0             ; x = 0
    push word 160           ; y = 160
    push word SCREEN_WIDTH  ; w = 320
    push word 40            ; h = 40
    push word COL_GROUND    ; color = 6 (Brown)
    call vid_fill_rect

    ; 3. Draw Grass Trim: FillRect(0, 160, 320, 3, COL_LIGHT_GREEN)
    push word 0
    push word 160
    push word SCREEN_WIDTH
    push word 3
    push word COL_LIGHT_GREEN ; color = 10 (Light Green)
    call vid_fill_rect

    ; 4. Draw Test Brick Block 1: FillRect(50, 100, 32, 16, COL_BRICK)
    push word 50
    push word 100
    push word 32
    push word 16
    push word COL_BRICK     ; color = 4 (Red Brick)
    call vid_fill_rect

    ; 5. Draw Test Question Block: FillRect(100, 100, 16, 16, COL_YELLOW)
    push word 100
    push word 100
    push word 16
    push word 16
    push word COL_YELLOW    ; color = 14 (Yellow)
    call vid_fill_rect

    ; 6. Draw Test Brick Block 2: FillRect(134, 100, 32, 16, COL_BRICK)
    push word 134
    push word 100
    push word 32
    push word 16
    push word COL_BRICK
    call vid_fill_rect

    ; 7. Draw Test Green Pipe Stem: FillRect(210, 120, 32, 40, COL_PIPE)
    push word 210
    push word 120
    push word 32
    push word 40
    push word COL_PIPE      ; color = 2 (Green)
    call vid_fill_rect

    ; 8. Draw Test Green Pipe Lip: FillRect(206, 114, 40, 8, COL_LIGHT_GREEN)
    push word 206
    push word 114
    push word 40
    push word 8
    push word COL_LIGHT_GREEN
    call vid_fill_rect

    ; 9. Draw Test Color Palette Swatches across bottom (Colors 0 to 15)
    mov cx, 16              ; 16 standard VGA colors
    xor bx, bx              ; bx = color index (0..15)
.palette_loop:
    push bx                 ; Save loop register

    ; Compute swatch x = 16 + (bx * 18)
    mov ax, bx
    mov dx, 18
    mul dx
    add ax, 16              ; ax = x position

    push ax                 ; x
    push word 176           ; y = 176
    push word 14            ; w = 14
    push word 12            ; h = 12
    push bx                 ; color = bx
    call vid_fill_rect

    pop bx
    inc bx
    loop .palette_loop

    ; 10. Test PutPixel with single dot accents on the Question block
    push word 108           ; x = 108
    push word 108           ; y = 108
    push word COL_WHITE     ; color = 15 (White)
    call vid_put_pixel

    push word 107           ; x = 107
    push word 107           ; y = 107
    push word COL_WHITE
    call vid_put_pixel

    ; --------------------------------------------------------------------------
    ; Wait for keypress before exiting (BIOS INT 16h, AH=00h)
    ; --------------------------------------------------------------------------
    mov ah, 0x00
    int 0x16

    ; --------------------------------------------------------------------------
    ; Clean Shutdown: Restore text mode, free memory, and exit to DOS
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
