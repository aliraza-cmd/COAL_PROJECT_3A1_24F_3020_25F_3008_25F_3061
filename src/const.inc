; ==============================================================================
; const.inc - Global Engine Constants
; Team: Ali Raza (24F-3020), Umama (25F-3008), Aiza (25F-3061)
; ==============================================================================

; Screen & Display Constants (VGA Mode 13h)
SCREEN_WIDTH    equ 320
SCREEN_HEIGHT   equ 200
SCREEN_SIZE     equ 64000
FRAME_PARAS     equ 4000        ; 64,000 bytes / 16 bytes per paragraph = 4000 paras

; Tile & Map Constants
TILE_SIZE       equ 16
MAP_COLS        equ 60
MAP_ROWS        equ 12
MAP_SIZE        equ 720         ; 60 columns * 12 rows = 720 bytes
WORLD_WIDTH_PX  equ 960         ; 60 * 16 pixels
MAX_CAMERA_X    equ 640         ; 960 - 320 pixels

; Tile Type Codes (Appendix A.2)
TILE_SKY        equ 0           ; Non-solid sky
TILE_GROUND     equ 1           ; Solid ground block
TILE_BRICK      equ 2           ; Solid breakable brick
TILE_Q_COIN     equ 3           ; Solid question block containing coin
TILE_Q_MUSHROOM equ 4           ; Solid question block containing mushroom
TILE_EMPTY_BLK  equ 5           ; Solid hit/empty brown block
TILE_PIPE_TL    equ 6           ; Solid pipe top-left
TILE_PIPE_TR    equ 7           ; Solid pipe top-right
TILE_PIPE_BL    equ 8           ; Solid pipe body-left
TILE_PIPE_BR    equ 9           ; Solid pipe body-right
TILE_STAIR      equ 10          ; Solid stair stone block
TILE_COIN       equ 11          ; Non-solid floating coin
TILE_FLAGPOLE   equ 12          ; Non-solid flag pole

; VGA Mode 13h Default Palette Color Constants
COL_TRANSPARENT equ 0
COL_BLUE        equ 1
COL_GREEN       equ 2
COL_CYAN        equ 3
COL_RED         equ 4
COL_MAGENTA     equ 5
COL_BROWN       equ 6
COL_LIGHT_GRAY  equ 7
COL_DARK_GRAY   equ 8
COL_LIGHT_BLUE  equ 9
COL_LIGHT_GREEN equ 10
COL_LIGHT_CYAN  equ 11
COL_LIGHT_RED   equ 12
COL_LIGHT_MAG   equ 13
COL_YELLOW      equ 14
COL_WHITE       equ 15

; Game Semantic Colors
COL_SKY         equ 9           ; Light blue for sky background
COL_GROUND      equ 6           ; Brown for ground
COL_BRICK       equ 4           ; Red brick
COL_MORTAR      equ 7           ; Light gray brick mortar lines
COL_COIN        equ 14          ; Yellow coin
COL_PIPE        equ 2           ; Green pipe
COL_PIPE_LIP    equ 10          ; Light green pipe lip highlight
COL_STAIR       equ 6           ; Brown stair
COL_Q_BLK       equ 14          ; Yellow question block
COL_EMPTY_BLK   equ 8           ; Dark gray empty block
COL_POLE        equ 15          ; White flagpole
