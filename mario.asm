; =============================================================================
;  MARIO.ASM  -  SUPER MARIO ENGINE   (EL2003 COAL Semester Project, Fall 2026)
;  Edition  : "Tropical Sunrise" theme - self-contained, no .inc files needed
;  16-bit real-mode platform game for NASM (-f bin -> MARIO.COM) and DOSBox.
;
;  Files    : mario.asm only (code + data + artwork + level 1 + level 2)
;  Build    : nasm -f bin mario.asm -o MARIO.COM
;  Calling  : parameters are PUSHed left-to-right (last argument is nearest to
;             the return address, i.e. at [bp+4]); the callee removes them with
;             RET n.  Every procedure preserves every register it does not
;             return (results are returned in AX).
;  Modules  : see the MODULE banners below (1..15).
; =============================================================================
        bits 16
        cpu  386
        org  100h

; ----------------------------------------------------------------- MODULE 1
; Named constants (Appendix A)
; -----------------------------------------------------------------------------
SCREEN_W        equ 320
SCREEN_H        equ 200
TILE            equ 16
MAP_COLS        equ 60
MAP_ROWS        equ 12
MAP_SIZE        equ MAP_COLS*MAP_ROWS
LEVEL_W         equ MAP_COLS*TILE       ; 960 pixels
CAM_MAX         equ LEVEL_W-SCREEN_W    ; 640
MARIO_MAXX      equ LEVEL_W-16          ; 944
MARIO_START_X   equ 32
POLE_COL        equ 56                  ; map column of the flag pole
POLE_X          equ POLE_COL*TILE       ; its world x (896)
GROUND_TOP_Y    equ 160                 ; y of the first ground row (row 10)
VGA_SEG         equ 0A000h
FRAME_PARAS     equ 4000                ; 64000 bytes = 4000 paragraphs
PIT_DIV         equ 39773               ; 1193182 / 39773 = 30.0 Hz timer
TICKS_PER_SEC   equ 30
INVULN_TICKS    equ 60                  ; about 2 seconds
START_TIME      equ 300
START_LIVES     equ 3

; palette indices (own 16 colour palette, see Palette table)
COL_BLACK       equ 0
COL_SKY         equ 1
COL_RED         equ 2
COL_SKIN        equ 3
COL_BROWN       equ 4
COL_DARK        equ 5
COL_WHITE       equ 6
COL_BLUE        equ 7
COL_GREEN       equ 8
COL_DGREEN      equ 9
COL_ORANGE      equ 10
COL_TAN         equ 11
COL_YELLOW      equ 12
COL_GRAY        equ 13
COL_LGREEN      equ 14
COL_BRICK       equ 15

; keyboard scan codes (Appendix A.3)
SC_ESC          equ 01h
SC_P            equ 19h
SC_ENTER        equ 1Ch
SC_LSHIFT       equ 2Ah
SC_SPACE        equ 39h
SC_LEFT         equ 4Bh
SC_RIGHT        equ 4Dh
SC_UP           equ 48h
SC_DOWN         equ 50h
SC_F1           equ 3Bh                 ; debug: clock = 5 seconds
SC_F2           equ 3Ch                 ; debug: coins = 99
SC_F3           equ 3Dh                 ; debug: switch between level 1 and level 2

; game states (Section 5.12)
ST_TITLE        equ 0
ST_PLAYING      equ 1
ST_PAUSED       equ 2
ST_DYING        equ 3
ST_LIFELOST     equ 4
ST_WINSEQ       equ 5
ST_LEVELCOMP    equ 6
ST_GAMEOVER     equ 7
ST_EXIT         equ 8

; tile codes (Appendix A.2)
T_SKY           equ 0
T_GROUND        equ 1
T_BRICK         equ 2
T_QCOIN         equ 3
T_QMUSH         equ 4
T_EMPTY         equ 5
T_STAIR         equ 10
T_COIN          equ 11
T_POLE          equ 12

; physics, 8.8 fixed point (Appendix A.5)
ACCEL           equ 0020h
FRICTION        equ 0010h
WALK_MAX        equ 0180h
RUN_MAX         equ 0280h
GRAVITY         equ 0040h
JUMP_V          equ 0FA80h              ; -5.5
JUMP_CUT        equ 0FE00h              ; -2.0
FALL_MAX        equ 0400h
BOUNCE_V        equ 0FD00h              ; -3.0
BOUNCE_HI_V     equ 0FC80h              ; -3.5 (jump key held)
DEATH_HOP_V     equ 0FB00h              ; -5.0 (about 50 pixels)
GOOMBA_V        equ 0080h
KOOPA_V         equ 00C0h
SHELL_V         equ 0300h
MUSH_V          equ 0100h

; entity records (fixed size, Section 5.5)
E_TYPE          equ 0                   ; db
E_STATE         equ 1                   ; db
E_X             equ 2                   ; dw  world x (pixels)
E_XF            equ 4                   ; db  x fraction
E_GRACE         equ 5                   ; db  frames that ignore Mario (kick)
E_Y             equ 6                   ; dw  y, 8.8
E_VX            equ 8                   ; dw  8.8 signed
E_VY            equ 10                  ; dw  8.8 signed
E_TIMER         equ 12                  ; dw
E_AUX           equ 14                  ; dw
ENT_SIZE        equ 16
ENT_MAX         equ 12                  ; level 2 has 8 enemies + 4 free slots
LAST_LEVEL      equ 1                   ; levels are numbered from 0
MOON_CX         equ 250                 ; night sky: moon centre and top
MOON_Y          equ 22
NSTARS          equ 28
NHILLS          equ 5
NTREES          equ 6

ET_NONE         equ 0
ET_GOOMBA       equ 1
ET_KOOPA        equ 2
ET_SHELL        equ 3
ET_MUSH         equ 4
ES_WAIT         equ 0
ES_WALK         equ 1
ES_FLAT         equ 2
ES_STILL        equ 3
ES_SLIDE        equ 4

EFF_MAX         equ 8                   ; effect records (pop-ups, coin pops)
EFF_SIZE        equ 8

; =============================================================================
;  PROGRAM ENTRY  (Module 1, 5, 14, 15)
; =============================================================================
start:
        cld
        ; --- Module 5: give back unused memory, then allocate the frame buffer
        mov     ah,4Ah                  ; resize our block to 64 KB
        mov     bx,1000h
        int     21h
        jc      near .nomem
        mov     ah,48h                  ; allocate 4000 paragraphs (64000 bytes)
        mov     bx,FRAME_PARAS
        int     21h
        jc      near .nomem
        mov     [FrameSeg],ax

        call    InitLevel               ; characters -> tile codes
        call    InitFont                ; pointer to the ROM 8x8 font
        call    ParseCmdLine            ; AL = 1 when the T switch is given

        mov     bl,al
        mov     ax,0013h                ; VGA mode 13h
        int     10h
        call    SetPalette
        test    bl,bl
        jz      .normal
        call    ColorTestScreen         ; Module 2 test screen, then exit
        jmp     .exit

.normal:
        mov     ax,[FrameSeg]
        mov     [DrawSeg],ax            ; everything is drawn into the frame buffer
        call    InstallHandlers
        call    NewGame
        mov     byte [GameState],ST_TITLE
        mov     ax,[TickCount]
        mov     [LastTick],ax

.mainloop:                              ; --- Module 14: state machine ------
        call    WaitTick                ; step 1 of the frame order
%ifdef TESTMODE
        call    TestStep                ; test build only: scripted input
        test    al,al
        jnz     .mainloop               ; frozen frame: the screen keeps its picture
%endif
        xor     bh,bh
        mov     bl,[GameState]
        shl     bx,1
        call    word [StateTable+bx]    ; jump table indexed by the state
        cmp     byte [GameState],ST_EXIT
        jne     .mainloop

        call    RestoreHandlers         ; Module 15: clean exit
.exit:
        mov     ax,0003h                ; back to text mode
        int     10h
        mov     ax,4C00h                ; DOS exit
        int     21h

.nomem:
        mov     dx,MsgNoMem
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

; -----------------------------------------------------------------------------
; ParseCmdLine
; Purpose : looks for the switch T (or /T) in the DOS command tail.
; Inputs  : none (reads the PSP at offset 80h)
; Outputs : AL = 1 if the colour test screen was requested, else 0
; Changes : AL (all other registers preserved)
; -----------------------------------------------------------------------------
ParseCmdLine:
        push    bx
        push    cx
        xor     ch,ch
        mov     cl,[80h]                ; length of the command tail
        mov     bx,81h
        xor     al,al
.scan:  test    cl,cl
        jz      .done
        mov     ah,[bx]
        and     ah,0DFh                 ; to upper case
        cmp     ah,'T'
        jne     .next
        mov     al,1
        jmp     .done
.next:  inc     bx
        dec     cl
        jmp     .scan
.done:  pop     cx
        pop     bx
        ret

; =============================================================================
;  MODULE 2 : VIDEO MODE AND COLOURS
; =============================================================================

; -----------------------------------------------------------------------------
; SetPalette
; Purpose : loads the game's 16 colours into the VGA DAC (INT 10h, AX=1012h).
; Inputs  : none        Outputs : none        Changes : none
; -----------------------------------------------------------------------------
SetPalette:
        pusha
        push    es
        mov     ax,cs
        mov     es,ax
        xor     bx,bx
        mov     bl,[CurLevel]           ; level 1 = day palette, level 2 = night
        shl     bx,1
        mov     dx,[PaletteTbl+bx]
        mov     ax,1012h
        xor     bx,bx                   ; first colour register
        mov     cx,16                   ; number of registers
        int     10h
        pop     es
        popa
        ret

; -----------------------------------------------------------------------------
; PutPixel(x, y, colour)       push x ; push y ; push colour ; call PutPixel
; Purpose : plots one pixel into the current draw segment (clipped).
; Offset  : y*320 + x  computed with shifts  (y*256 + y*64 + x)
; Changes : none
; -----------------------------------------------------------------------------
PutPixel:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    di
        push    es
        mov     bx,[bp+8]               ; x
        mov     ax,[bp+6]               ; y
        cmp     bx,0
        jl      .out
        cmp     bx,SCREEN_W
        jge     .out
        cmp     ax,0
        jl      .out
        cmp     ax,SCREEN_H
        jge     .out
        mov     di,ax
        shl     di,8                    ; y*256
        shl     ax,6                    ; y*64
        add     di,ax
        add     di,bx
        mov     es,[DrawSeg]
        mov     al,[bp+4]
        mov     [es:di],al
.out:   pop     es
        pop     di
        pop     bx
        pop     ax
        pop     bp
        ret     6

; -----------------------------------------------------------------------------
; FillRect(x, y, w, h, colour)
; Purpose : fills a rectangle (clipped to the screen) using REP STOSB per row.
; Changes : none
; -----------------------------------------------------------------------------
FillRect:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        mov     bx,[bp+12]              ; x
        mov     dx,[bp+10]              ; y
        mov     si,[bp+8]               ; w
        mov     cx,[bp+6]               ; h
        cmp     bx,0                    ; clip left
        jge     .xok
        add     si,bx
        xor     bx,bx
.xok:   mov     ax,SCREEN_W
        sub     ax,bx
        cmp     si,ax                   ; clip right
        jle     .wok
        mov     si,ax
.wok:   cmp     si,0
        jle     .exit
        cmp     dx,0                    ; clip top
        jge     .yok
        add     cx,dx
        xor     dx,dx
.yok:   mov     ax,SCREEN_H
        sub     ax,dx
        cmp     cx,ax                   ; clip bottom
        jle     .hok
        mov     cx,ax
.hok:   cmp     cx,0
        jle     .exit
        mov     di,dx
        shl     di,8
        mov     ax,dx
        shl     ax,6
        add     di,ax
        add     di,bx                   ; di = y*320 + x
        mov     es,[DrawSeg]
        mov     al,[bp+4]
        cld
.row:   push    cx
        mov     cx,si
        rep     stosb
        pop     cx
        add     di,SCREEN_W
        sub     di,si
        loop    .row
.exit:  pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        pop     bp
        ret     10
