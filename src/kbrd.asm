; ==============================================================================
; kbrd.asm - Custom Hardware Keyboard Interrupt Handler (Port 60h, INT 09h)
; Course: EL2003 Computer Organization & Assembly Language
; Author: Umama (25F-3008) | Group BSE-3A1
; ==============================================================================

; Scan Code Constants (Appendix A.3)
KEY_ESC         equ 0x01
KEY_P           equ 0x19
KEY_ENTER       equ 0x1C
KEY_LSHIFT      equ 0x2A
KEY_SPACE       equ 0x39
KEY_UP          equ 0x48
KEY_LEFT        equ 0x4B
KEY_RIGHT       equ 0x4D
KEY_DOWN        equ 0x50

; ------------------------------------------------------------------------------
; kbrd_install
; Purpose : Save original INT 09h vector and hook custom keyboard ISR
; Concepts: IVT manipulation via DOS services AH=35h (get) and AH=25h (set)
; Preserves all registers
; ------------------------------------------------------------------------------
kbrd_install:
    push ax
    push bx
    push dx
    push es

    ; Step 1: Save current INT 09h vector
    mov ax, 0x3509          ; AH = 35h (Get Interrupt Vector), AL = 09h
    int 0x21
    mov [cs:old_int09_off], bx
    mov [cs:old_int09_seg], es

    ; Step 2: Install our custom keyboard ISR
    push cs
    pop ds
    mov dx, kbrd_isr        ; DS:DX points to new handler
    mov ax, 0x2509          ; AH = 25h (Set Interrupt Vector), AL = 09h
    int 0x21

    pop es
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------------------------
; kbrd_uninstall
; Purpose : Restore original INT 09h vector before returning to DOS
; Mandatory on EVERY program exit path!
; Preserves all registers
; ------------------------------------------------------------------------------
kbrd_uninstall:
    push ax
    push dx
    push ds

    ; Only restore if we saved a non-zero vector
    cmp word [cs:old_int09_seg], 0
    jz .skip_restore

    mov dx, [cs:old_int09_off]
    mov ds, [cs:old_int09_seg]
    mov ax, 0x2509          ; Restore vector from DS:DX
    int 0x21

    mov word [cs:old_int09_seg], 0

.skip_restore:
    pop ds
    pop dx
    pop ax
    ret

; ------------------------------------------------------------------------------
; kbrd_isr
; Purpose : Custom Hardware Keyboard Interrupt Service Routine
; Reads raw scan code from I/O port 60h, updates key_table, sends EOI
; ------------------------------------------------------------------------------
kbrd_isr:
    push ax
    push bx
    push ds

    push cs
    pop ds                  ; Ensure DS points to our data segment

    ; Read scan code from keyboard controller data port 60h
    in al, 0x60

    ; Check for extended key prefix (E0h sent before arrow keys)
    cmp al, 0xE0
    je .eoi_exit            ; Ignore E0h prefix; process the following code

    ; Check bit 7 (Make code vs Break code):
    ; Bit 7 = 0 -> Key Pressed
    ; Bit 7 = 1 -> Key Released
    test al, 0x80
    jnz .key_released

    ; --- Key Pressed (Make Code) ---
    and al, 0x7F            ; Ensure index in range 0..127
    xor ah, ah
    mov bx, ax
    mov byte [key_table + bx], 1
    jmp .eoi_exit

.key_released:
    ; --- Key Released (Break Code) ---
    and al, 0x7F            ; Strip release bit (bit 7)
    xor ah, ah
    mov bx, ax
    mov byte [key_table + bx], 0

.eoi_exit:
    ; Acknowledge hardware interrupt to 8259 PIC (End Of Interrupt = 20h)
    mov al, 0x20
    out 0x20, al

    pop ds
    pop bx
    pop ax
    iret                    ; Return from interrupt (pops IP, CS, FLAGS)

; ------------------------------------------------------------------------------
; Keyboard Variables
; ------------------------------------------------------------------------------
old_int09_off   dw 0        ; Saved original INT 09h offset
old_int09_seg   dw 0        ; Saved original INT 09h segment

; 128-byte array: key_table[scan_code] = 1 if key held down, 0 if released
key_table:
    times 128 db 0

