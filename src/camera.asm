; ==============================================================================
; camera.asm - Camera & Smooth Scrolling Engine
; Course: EL2003 Computer Organization & Assembly Language
; Author: Umama (25F-3008) | Group BSE-3A1
; ==============================================================================

cam_init:
    mov word [cs:camera_x], 0
    ret

cam_update:
    push ax
    push bx

    ; screen_x = mario_world_x - camera_x
    mov ax, [cs:mario_world_x]
    shr ax, 8
    mov bx, [cs:camera_x]
    sub ax, bx

    ; If screen_x > 160: new_camera = mario_world_x - 160
    cmp ax, 160
    jle .check_left_wall

    mov ax, [cs:mario_world_x]
    shr ax, 8
    sub ax, 160

    cmp ax, MAX_CAMERA_X
    jbe .not_over_max
    mov ax, MAX_CAMERA_X
.not_over_max:

    ; Monotonic scroll right: camera_x = max(camera_x, new_camera)
    cmp ax, [cs:camera_x]
    jbe .check_left_wall
    mov [cs:camera_x], ax

.check_left_wall:
    ; Left wall barrier: if mario_world_x < camera_x
    mov ax, [cs:mario_world_x]
    shr ax, 8
    mov bx, [cs:camera_x]
    cmp ax, bx
    jge .done

    shl bx, 8
    mov [cs:mario_world_x], bx
    mov word [cs:mario_vx], 0

.done:
    pop bx
    pop ax
    ret

; Camera Variables
camera_x    dw 0
