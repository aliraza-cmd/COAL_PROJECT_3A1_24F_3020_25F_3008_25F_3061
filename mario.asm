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

 
; -----------------------------------------------------------------------------
; ColorTestScreen
; Purpose : Module 2 test screen: 16 swatches with their palette numbers.
;           Shown with  MARIO.COM T  ; waits for a key, then returns.
; -----------------------------------------------------------------------------
ColorTestScreen:
        pusha
        mov     word [DrawSeg],VGA_SEG
        xor     si,si                   ; colour number
.sw:    mov     ax,si
        and     ax,7
        mov     bx,ax
        shl     bx,5
        add     bx,32                   ; x = 32 + (n mod 8)*32
        mov     ax,si
        shr     ax,3
        mov     dx,ax
        shl     dx,6
        add     dx,50                   ; y = 50 + (n div 8)*64
        push    bx
        push    dx
        push    word 28
        push    word 28
        push    si
        call    FillRect
        push    bx                      ; palette number under each swatch
        add     dx,32
        push    dx
        push    word 0                  ; high word
        push    si                      ; low word
        push    word 0                  ; 0 = no leading zeros
        push    word COL_WHITE
        call    DrawNumber
        inc     si
        cmp     si,16
        jb      .sw
        push    word 40
        push    word 20
        push    word MsgTest
        push    word COL_YELLOW
        push    word 1
        call    DrawString
        xor     ax,ax
        int     16h                     ; wait for any key (BIOS)
        popa
        ret

; =============================================================================
;  TEXT AND NUMBERS  (bitmap font from the BIOS ROM, drawn by our own code)
; =============================================================================

; -----------------------------------------------------------------------------
; InitFont
; Purpose : asks the BIOS (INT 10h AX=1130h BH=3) for the 8x8 ROM font and
;           remembers its far pointer in FontSeg:FontOff.
; Changes : none
; -----------------------------------------------------------------------------
InitFont:
        pusha
        push    es
        mov     ax,1130h
        mov     bh,03h
        int     10h                     ; returns ES:BP
        mov     [FontOff],bp
        mov     [FontSeg],es
        pop     es
        popa
        ret

; -----------------------------------------------------------------------------
; DrawBits8(x, y, address, colour, scale)
; Purpose : draws an 8x8 1-bit bitmap found at DS:address (msb = leftmost).
;           scale 1 writes pixels directly, bigger scales use FillRect.
; Changes : none
; -----------------------------------------------------------------------------
DrawBits8:
        push    bp
        mov     bp,sp
        pusha
        push    es
        mov     es,[DrawSeg]
        mov     si,[bp+8]               ; bitmap address
        xor     dx,dx                   ; row 0..7
.row:   mov     al,[si]
        inc     si
        mov     cx,8                    ; column counter
        xor     bx,bx                   ; column 0..7
.col:   shl     al,1
        jnc     .skip
        push    ax
        cmp     word [bp+4],1
        jne     .big
        ; scale 1: direct pixel
        ; FIX: clip to the screen (unsigned compares also reject negatives);
        ;      before, pop-ups / text near an edge wrote outside the buffer
        mov     ax,[bp+10]              ; y
        add     ax,dx
        cmp     ax,SCREEN_H
        jae     .done
        mov     di,ax
        shl     di,8
        shl     ax,6
        add     di,ax                   ; di = y*320
        mov     ax,[bp+12]              ; x
        add     ax,bx
        cmp     ax,SCREEN_W
        jae     .done
        add     di,ax
        mov     al,[bp+6]
        mov     [es:di],al
        jmp     .done
.big:   mov     ax,[bp+4]               ; scale
        push    ax
        imul    ax,bx
        add     ax,[bp+12]
        push    ax                      ; x
        mov     ax,[bp+4]
        imul    ax,dx
        add     ax,[bp+10]
        push    ax                      ; y
        push    word [bp+4]             ; w
        push    word [bp+4]             ; h
        push    word [bp+6]             ; colour
        call    FillRect
        pop     ax
.done:  pop     ax
.skip:  inc     bx
        loop    .col
        inc     dx
        cmp     dx,8
        jb      .row
        pop     es
        popa
        pop     bp
        ret     10


; -----------------------------------------------------------------------------
; DrawChar(x, y, ch, colour, scale)
; Purpose : copies the glyph of ch from the ROM font to CharBuf, then draws it.
; Changes : none
; -----------------------------------------------------------------------------
DrawChar:
        push    bp
        mov     bp,sp
        pusha
        push    es
        push    ds
        mov     bx,[bp+8]
        and     bx,7Fh
        shl     bx,3                    ; 8 bytes per glyph
        add     bx,[FontOff]
        mov     ax,[FontSeg]
        mov     si,bx
        mov     bx,cs
        mov     es,bx                   ; ES = CS (destination of MOVSB)
        mov     di,CharBuf
        mov     ds,ax                   ; DS = font segment
        mov     cx,8
        cld
        rep     movsb
        pop     ds
        pop     es
        push    word [bp+12]
        push    word [bp+10]
        push    word CharBuf
        push    word [bp+6]
        push    word [bp+4]
        call    DrawBits8
        popa
        pop     bp
        ret     10

; -----------------------------------------------------------------------------
; DrawString(x, y, address, colour, scale)   zero-terminated string
; Changes : none
; -----------------------------------------------------------------------------
DrawString:
        push    bp
        mov     bp,sp
        pusha
        mov     si,[bp+8]
        mov     bx,[bp+12]              ; current x
        mov     di,[bp+4]
        shl     di,3                    ; advance = 8*scale
.next:  xor     ax,ax
        mov     al,[si]
        test    al,al
        jz      .done
        push    bx
        push    word [bp+10]
        push    ax
        push    word [bp+6]
        push    word [bp+4]
        call    DrawChar
        add     bx,di
        inc     si
        jmp     .next
.done:  popa
        pop     bp
        ret     10

; -----------------------------------------------------------------------------
; DrawCentered(y, address, colour, scale)
; Purpose : draws a zero-terminated string centred horizontally.
; Changes : none
; -----------------------------------------------------------------------------
DrawCentered:
        push    bp
        mov     bp,sp
        pusha
        mov     si,[bp+8]
        xor     cx,cx                   ; length
.len:   cmp     byte [si],0
        je      .got
        inc     cx
        inc     si
        jmp     .len
.got:   mov     ax,[bp+4]
        shl     ax,3
        mul     cx                      ; pixel width = len*8*scale
        mov     bx,SCREEN_W
        sub     bx,ax
        sar     bx,1                    ; x = (320-width)/2   FIX: signed shift (wide text)
        push    bx
        push    word [bp+10]
        push    word [bp+8]
        push    word [bp+6]
        push    word [bp+4]
        call    DrawString
        popa
        pop     bp
        ret     8
