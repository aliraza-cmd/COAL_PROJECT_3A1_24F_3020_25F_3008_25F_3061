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

; ------------------------------------------------------------------------------
; Main Program Entry Point
; ------------------------------------------------------------------------------
start_program:
    ; Print Title Banner
    mov dx, msg_title
    mov ah, 0x09
    int 0x21

    ; --------------------------------------------------------------------------
    ; Step 1: Shrink current memory block to 64 KB (4096 paragraphs = 1000h)
    ; In DOS, a .COM file is initially allocated all available conventional memory.
    ; To allocate a second segment cleanly with AH=48h, we must first release the
    ; unused memory back to DOS using AH=4Ah.
    ; Inputs:
    ;   AH = 4Ah (Modify Allocated Memory Block)
    ;   ES = Segment of memory block to resize (current PSP segment = CS)
    ;   BX = New size in paragraphs (64 KB / 16 = 4096 = 1000h paragraphs)
    ; --------------------------------------------------------------------------
    mov bx, 0x1000          ; 4096 paragraphs = 65,536 bytes (64 KB)
    mov ah, 0x4A            ; DOS function: resize allocated memory block
    int 0x21
    jc memory_allocation_failed

    ; --------------------------------------------------------------------------
    ; Step 2: Allocate dedicated segment for off-screen backbuffer (64,000 bytes)
    ; A 320x200 Mode 13h frame requires 64,000 bytes (4000 paragraphs = 0x0FA0).
    ; Inputs:
    ;   AH = 48h (Allocate Memory)
    ;   BX = Number of paragraphs to allocate (4000 paragraphs = 64,000 bytes)
    ; Outputs:
    ;   AX = Base segment address of allocated block (stored in frame_buffer_seg)
    ; --------------------------------------------------------------------------
    mov bx, FRAME_PARAS     ; 4000 paragraphs = 64,000 bytes
    mov ah, 0x48            ; DOS function: allocate memory block
    int 0x21
    jc memory_allocation_failed

    ; Save the allocated segment base address for double buffering
    mov [frame_buffer_seg], ax

    ; Print initialization success message
    mov dx, msg_success
    mov ah, 0x09
    int 0x21

    ; Wait for user keystroke (BIOS INT 16h, AH=00h)
    mov ah, 0x00
    int 0x16

    ; --------------------------------------------------------------------------
    ; Step 3: Clean Exit & Resource Deallocation
    ; Free the allocated backbuffer segment before terminating.
    ; Inputs:
    ;   AH = 49h (Free Allocated Memory)
    ;   ES = Segment of the block to free
    ; --------------------------------------------------------------------------
    mov dx, msg_exit
    mov ah, 0x09
    int 0x21

    mov es, [frame_buffer_seg]
    mov ah, 0x49            ; DOS function: free memory block
    int 0x21

    ; Terminate program cleanly with exit code 0
    mov ax, 0x4C00          ; DOS function: terminate with return code
    int 0x21

memory_allocation_failed:
    mov dx, msg_mem_err
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C01          ; Terminate with error code 1
    int 0x21

