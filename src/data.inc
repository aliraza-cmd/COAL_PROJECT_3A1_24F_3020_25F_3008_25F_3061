; ==============================================================================
; data.inc - Memory Variables & Shared Buffers
; Team: Ali Raza (24F-3020), Umama (25F-3008), Aiza (25F-3061)
; ==============================================================================

; --- Memory & Buffer Variables ---
frame_buffer_seg dw 0           ; Allocated segment address for off-screen 64KB backbuffer

; --- Strings & Messages ---
msg_title       db "========================================", 0x0D, 0x0A
                db "  SUPER MARIO ENGINE - 16-BIT REAL MODE ", 0x0D, 0x0A
                db "  Group: Ali, Umama, Aiza (BSE-3A1)     ", 0x0D, 0x0A
                db "========================================", 0x0D, 0x0A, "$"

msg_success     db "[OK] Program memory shrunk to 64 KB.", 0x0D, 0x0A
                db "[OK] Frame buffer segment allocated (64,000 bytes).", 0x0D, 0x0A
                db "[OK] System ready for Graphics Mode 13h.", 0x0D, 0x0A, 0x0D, 0x0A
                db "Press any key to test clean exit...", 0x0D, 0x0A, "$"

msg_mem_err     db "Error: Failed to allocate 64KB frame buffer segment!", 0x0D, 0x0A, "$"
msg_exit        db "Releasing frame buffer and exiting cleanly to DOS...", 0x0D, 0x0A, "$"
