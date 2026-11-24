# Super Mario Engine — Ali's Viva & Concept Guide
## Module Ownership: Foundation, Video Mode 13h, Tile Map, Sprites & Double Buffering
**Student**: Ali Raza (24F-3020) | **Course**: EL2003 Computer Organization & Assembly Language | **Section**: BSE-3A1

---

## Table of Contents
1. [Ali's Scope of Work & Modules](#1-alis-scope-of-work--modules)
2. [Milestone 1: Skeleton, Memory Architecture & Clean Exit](#2-milestone-1-skeleton-memory-architecture--clean-exit)
   - [What is 16-bit Real Mode?](#what-is-16-bit-real-mode)
   - [What is a .COM Executable & Why ORG 100h?](#what-is-a-com-executable--why-org-100h)
   - [The 64KB Segment Limit & The Frame Buffer Dilemma](#the-64kb-segment-limit--the-frame-buffer-dilemma)
   - [DOS Memory Management: AH=4Ah, 48h, 49h, 4Ch](#dos-memory-management-ah4ah-48h-49h-4ch)
   - [What is a "Paragraph" in x86?](#what-is-a-paragraph-in-x86)
   - [The Carry Flag (CF) & Error Handling](#the-carry-flag-cf--error-handling)
3. [Milestone 1 Viva Questions & Model Answers](#3-milestone-1-viva-questions--model-answers)
4. [Upcoming Milestones Roadmap for Ali](#4-upcoming-milestones-roadmap-for-ali)

---

## 1. Ali's Scope of Work & Modules

In our 3-member team (Ali, Umama, Aiza), Ali builds the **Visual and Memory Foundation (Modules 1 to 5)**:
- **Module 1**: Program Skeleton, Build Automation, 64KB Frame Buffer Allocation & DOS Exit.
- **Module 2**: VGA Mode 13h (320×200, 256 colors), Stack-based `PutPixel` and `FillRect`.
- **Module 3**: 60×12 Tile Map, `GetTile`, `DrawTile`, `DrawMap`, and Dual-Map `ResetMap`.
- **Module 4**: Original 16×16 and 16×32 Sprites, Transparency, Mirroring, and 4-Edge Clipping.
- **Module 5**: Double Buffering Engine with `REP STOSW` clearing and `REP MOVSW` video blit.

---

## 2. Milestone 1: Skeleton, Memory Architecture & Clean Exit

### What is 16-bit Real Mode?
- The Intel 8086 CPU operates in **Real Mode**.
- In Real Mode, memory addresses are computed using **Segment : Offset** addressing:
  $$\text{Physical Address} = (\text{Segment} \times 16) + \text{Offset} = (\text{Segment} \ll 4) + \text{Offset}$$
- The processor can access up to **1 MB** ($2^{20}$ bytes, addresses `00000h` to `FFFFFh`) of conventional RAM.
- There is no memory protection or virtual memory: any instruction can write anywhere, making proper resource management critical!

### What is a .COM Executable & Why ORG 100h?
- **`.COM` format**: A flat, single-segment binary (maximum size 65,536 bytes = 64 KB).
- When DOS loads a `.COM` file:
  - It sets all segment registers to the same segment: `CS = DS = SS = ES`.
  - It places a **256-byte (0x100 bytes)** structure called the **PSP (Program Segment Prefix)** at the beginning of the segment (`offset 0000h` to `00FFh`).
  - The actual executable code begins at **offset 100h**.
- Therefore, every `.COM` file in NASM must start with:
  ```nasm
  [org 0x0100]
  ```
  This tells NASM that all memory labels and variable offsets must be calculated relative to `100h`.

### The 64KB Segment Limit & The Frame Buffer Dilemma
- In VGA Mode 13h, the screen resolution is **320 pixels wide × 200 pixels high**.
- Each pixel is 1 byte (256 colors).
- Total screen memory needed = $320 \times 200 = \mathbf{64,000\text{ bytes}}$.
- **The Problem**: A single 8086 segment is limited to **65,536 bytes (64 KB)**. If code, data, stack, AND the 64,000-byte frame buffer were kept in one segment, there would only be $65,536 - 64,000 = \mathbf{1,536\text{ bytes}}$ left for all code, tiles, and sprites! That is impossible.
- **The Solution**: We allocate a **second segment** dedicated entirely to the 64,000-byte frame buffer using DOS memory allocation services!

### DOS Memory Management: AH=4Ah, 48h, 49h, 4Ch

#### 1. Why do we shrink memory first? (`INT 21h, AH=4Ah`)
When DOS launches a `.COM` program, it gives the program **all available conventional memory** by default. Because our program now "owns" all free RAM, calling `AH=48h` (Allocate) would immediately fail with "out of memory"!
To fix this, we shrink our program's block to exactly 64 KB:
```nasm
mov bx, 0x1000      ; 4096 paragraphs = 65,536 bytes = 64 KB
mov ah, 0x4A        ; DOS function: resize memory block
int 0x21            ; ES already points to PSP segment
jc memory_error     ; If Carry Flag is set, resize failed
```

#### 2. Allocating the Second Segment (`INT 21h, AH=48h`)
Now that DOS has free memory available, we request a 64,000-byte block for our off-screen buffer:
```nasm
mov bx, 4000        ; 4000 paragraphs * 16 bytes = 64,000 bytes
mov ah, 0x48        ; DOS function: allocate memory
int 0x21
jc memory_error     ; CF = 1 if allocation failed
mov [frame_buffer_seg], ax  ; AX contains the allocated segment base address!
```

#### 3. Freeing Memory on Exit (`INT 21h, AH=49h`)
When exiting, we return the allocated 64KB segment back to the operating system to prevent memory leaks:
```nasm
mov es, [frame_buffer_seg]
mov ah, 0x49        ; DOS function: free memory block
int 0x21
```

#### 4. Clean Termination (`INT 21h, AH=4Ch`)
```nasm
mov ax, 0x4C00      ; AH = 4Ch (terminate), AL = 00h (exit code 0 = success)
int 0x21
```

### What is a "Paragraph" in x86?
- In real-mode DOS, memory blocks are allocated in units of **Paragraphs**.
- **1 Paragraph = 16 bytes** (`0x10` bytes).
- Why 16 bytes? Because shifting a 16-bit segment address left by 4 bits ($\times 16$) creates a 20-bit physical address.
- Calculating paragraphs:
  - For 64 KB: $65,536 / 16 = \mathbf{4096\text{ paragraphs}} = \mathbf{1000h\text{ paragraphs}}$.
  - For 64,000 bytes: $64,000 / 16 = \mathbf{4000\text{ paragraphs}} = \mathbf{0FA0h\text{ paragraphs}}$.

### The Carry Flag (CF) & Error Handling
- DOS interrupt functions signal errors using the **Carry Flag (CF)**.
- If the operation succeeds: $\text{CF} = 0$.
- If the operation fails: $\text{CF} = 1$, and `AX` contains the error code (e.g., `08h` = Insufficient Memory).
- We test this using the instruction:
  ```nasm
  jc memory_allocation_failed   ; Jump if Carry (CF == 1)
  ```

---

## 3. Milestone 1 Viva Questions & Model Answers

### Q1: Why did you use `[org 0x0100]` at the start of `mario.asm`?
> **Answer**: Because `mario.asm` compiles into a `.COM` executable. In MS-DOS, `.COM` files are loaded by DOS into a single 64KB segment, and DOS reserves the first 256 bytes (`0000h` to `00FFh`) for the Program Segment Prefix (PSP). Execution begins at offset `0100h`, so `[org 0x0100]` tells the assembler to align all labels and data offsets starting from offset `100h`.

### Q2: Why can't you put the frame buffer inside your main `.COM` data segment?
> **Answer**: In 16-bit real mode, an offset cannot exceed 16 bits (`FFFFh` = 65,535 bytes). A 320×200 Mode 13h screen buffer requires $320 \times 200 = 64,000$ bytes. If we put 64,000 bytes into our 65,536-byte `.COM` segment, only 1,536 bytes would be left for all our game code, sprite tables, and stack combined. Therefore, we keep code and data in our primary segment and dynamically allocate a separate 64,000-byte segment for the frame buffer.

### Q3: Why is `INT 21h, AH=4Ah` called before `INT 21h, AH=48h`?
> **Answer**: When DOS launches a `.COM` program, it automatically allocates all remaining conventional RAM to that program. If we call `AH=48h` (allocate) immediately, DOS will report an error ("Insufficient Memory") because our program is already monopolizing all memory. Calling `AH=4Ah` first shrinks our initial allocation block to 64 KB, returning the rest of conventional RAM to DOS so that `AH=48h` can successfully allocate the second segment.

### Q4: How many bytes are in a paragraph, and how many paragraphs did you allocate?
> **Answer**: In x86 architecture, 1 paragraph equals 16 bytes. For our 64,000-byte frame buffer, we divide 64,000 by 16, which equals 4,000 paragraphs (hexadecimal `0FA0h`). We pass `BX = 4000` to `INT 21h, AH=48h`.

### Q5: What happens if you don't call `INT 21h, AH=49h` on exit?
> **Answer**: `AH=49h` frees the allocated memory block back to DOS. In Real Mode, if memory is not freed, it can remain allocated in conventional RAM, causing memory fragmentation or reducing available memory for subsequent programs in the DOS environment.

---

## 4. Upcoming Milestones Roadmap for Ali

- **Milestone 2**: VGA Mode 13h initialization (`INT 10h, AX=0013h`), text mode restore (`AX=0003h`), and stack-passed `PutPixel` and `FillRect` using fast shift arithmetic `(y << 8) + (y << 6) + x`.
- **Milestone 3**: 60×12 level map, tile codes, `GetTile(px, py)`, `DrawTile`, `DrawMap`, and `ResetMap` using `REP MOVSB`.
- **Milestone 4**: 16×16 & 16×32 sprite bit blitting with transparency (color 0), horizontal mirroring, and 4-edge clipping.
- **Milestone 5**: Full double-buffering pipeline with `REP STOSW` backbuffer clear and `REP MOVSW` screen blit.


---

## 5. Milestone 2: VGA Mode 13h & Drawing Primitives

### What is VGA Mode 13h?
- Standard graphics mode provided by VGA BIOS (`INT 10h, AX=0013h`).
- **Resolution**: 320 pixels horizontal × 200 pixels vertical.
- **Colors**: 256 colors per pixel (8 bits / 1 byte per pixel).
- **Video Memory Segment**: `0A000h:0000` to `0A000h:FA00` (exactly 64,000 bytes).
- **Linear Framebuffer**: Unlike older planar modes, Mode 13h is completely linear! 
  Pixel $(0, 0)$ is at byte offset `0`, pixel $(1, 0)$ is at byte `1`, and pixel $(0, 1)$ is at byte `320`.

### Fast Offset Calculation: Why Shifts Instead of `MUL`?
In Module 2, the manual states:
> *"Compute the offset as $y \times 320 + x$ using shifts ($y \times 256 + y \times 64)$."*

#### Mathematical Proof:
$$320 = 256 + 64 = 2^8 + 2^6$$
$$y \times 320 = (y \times 2^8) + (y \times 2^6) = (y \ll 8) + (y \ll 6)$$

#### Assembly Implementation:
```nasm
mov ax, y           ; ax = y
mov bx, ax          ; bx = y
shl ax, 8           ; ax = y * 256
shl bx, 6           ; bx = y * 64
add ax, bx          ; ax = y * 320
add ax, x           ; ax = (y * 320) + x
mov di, ax          ; di = offset in ES
```

#### Why is this crucial for the Viva?
On the original 8086 processor:
- `MUL cx` takes **118 to 133 clock cycles**!
- Two `SHL` instructions plus `ADD` take only **~16 to 24 clock cycles**!
- That is **over 5 times faster**! In a 30 FPS game rendering thousands of pixels per frame, using shifts is essential to prevent lag.

---

### Stack Parameters & Standard Calling Convention
The project manual strictly requires:
> *"Every procedure must preserve every register it does not return. Procedures that need inputs take them through the stack."*

#### How `PutPixel(x, y, color)` Stack Frame Works:
When caller executes:
```nasm
push word x         ; [bp + 8]
push word y         ; [bp + 6]
push word color     ; [bp + 4]
call vid_put_pixel  ; Pushes return IP (2 bytes) -> [bp + 2]
```

Inside the subroutine:
```nasm
push bp             ; Save old frame pointer -> [bp + 0]
mov bp, sp          ; Establish new stack frame
push ax             ; Preserve registers
push bx
push di
; ... access arguments via [bp + 4], [bp + 6], [bp + 8] ...
pop di              ; Restore registers in reverse order
pop bx
pop ax
pop bp              ; Restore caller's BP
ret 6               ; Returns and cleans 6 bytes (3 words) from stack!
```

---

### String Instruction `REP STOSB` for `FillRect`
- In `vid_fill_rect`, rather than writing a slow pixel-by-pixel loop, we use the 8086 string primitive:
  ```nasm
  cld             ; Clear Direction Flag (DF = 0 -> auto-increment DI)
  mov cx, width   ; Number of bytes in this row
  rep stosb       ; Store AL into ES:[DI], increment DI, repeat CX times!
  ```
- Hardware executes `rep stosb` at maximum bus bandwidth, filling rectangles in microseconds!

---

### The 8086 "Short Jump Out of Range" Rule
During Milestone 2 development, we resolved an authentic 8086 architectural constraint:
- On 8086, conditional jumps (`JC`, `JZ`, `JNZ`, `JNE`) use an **8-bit signed relative displacement** (range: **-128 to +127 bytes**).
- When code grows beyond 127 bytes, direct `jc label` fails with `error: short jump is out of range`.
- **The Fix (Trampoline Pattern)**:
  Invert the condition and use an unconditional near jump `JMP` (which supports 16-bit displacement up to 32 KB):
  ```nasm
  jnc .mem_ok       ; Jump forward over the JMP if NO error
  jmp memory_failed ; Near 16-bit jump can reach anywhere in 64 KB!
  .mem_ok:
  ```

---

## 6. Milestone 2 Viva Questions & Model Answers

### Q1: What video mode does your game use, and what is its memory structure?
> **Answer**: We use VGA Mode 13h (activated via BIOS `INT 10h, AX=0013h`). Its resolution is $320 \times 200$ pixels with 256 colors (1 byte per pixel). Video RAM is mapped as a flat linear segment at physical address `0A000h:0000` through `0A000h:0FA00` (64,000 bytes).

### Q2: How do you calculate the memory offset of a pixel at coordinate $(x, y)$?
> **Answer**: The linear offset formula is $\text{offset} = (y \times 320) + x$. We compute this without the slow `MUL` instruction by decomposing 320 into $256 + 64$. We shift $y$ left by 8 bits ($y \times 256$) and left by 6 bits ($y \times 64$), add the two results, and add $x$.

### Q3: Why do your procedures end with `ret N` instead of plain `ret`?
> **Answer**: We follow the standard convention where the callee cleans its own parameters off the stack. For example, `PutPixel` receives 3 word parameters (6 bytes). `ret 6` pops the instruction pointer to return to the caller and simultaneously adds 6 to `SP`, discarding the arguments in one instruction without needing the caller to do `add sp, 6`.

### Q4: Why did you use `REP STOSB` in `FillRect`?
> **Answer**: `REP STOSB` is a specialized string manipulation instruction. It writes the byte in `AL` into `ES:[DI]` and increments `DI` automatically, repeating `CX` times until `CX` reaches zero. It executes directly in microcode without loop instruction overhead, making rectangle filling dramatically faster than individual memory writes.

### Q5: Why is `CLD` required before `REP STOSB`?
> **Answer**: `CLD` (Clear Direction Flag) sets the Direction Flag (`DF = 0`), which guarantees that string instructions increment the index registers (`DI` / `SI`). If `DF` were 1 (set via `STD`), `STOSB` would decrement `DI`, causing the rectangle to draw backwards and corrupt memory!


---

## 7. Milestone 3: 60×12 Level Map, Dual-Map Architecture & Tile Renderer

### The 60×12 Tile Matrix Layout
- **World Dimensions**: 60 columns × 12 rows = **720 bytes** total.
- **Pixel World Dimensions**: $60 \times 16 = 960$ pixels wide by $12 \times 16 = 192$ pixels high.
- The bottom 8 scanlines (from $y=192$ to $199$) remain black.
- Map rows layout:
  - **Row 0**: HUD strip (reserved).
  - **Rows 1 to 8**: Air, clouds, floating blocks, pipes, floating coins, flagpole.
  - **Row 9**: Surface level (walkway, pipe bases, stair base, castle).
  - **Rows 10 & 11**: Solid ground tiles, with two distinct 3-tile gaps (**Pit 1** at columns 18–20, **Pit 2** at columns 38–40).

---

### The Dual-Map Architecture (`original_map` vs `working_map`)
The project manual specifies:
> *"Keep two copies of the level map: the original (never changed) and a working copy (changed when blocks are hit and coins are taken). Restarting copies the original back with one block-move instruction."*

- **`original_map`**: Defined statically using `db` directives. Contains pristine level data and is **never written to**.
- **`working_map`**: Runtime buffer in memory. When Super Mario breaks a brick or hits a `?` block, only `working_map` is modified.
- **`ResetMap` (`map_reset`)**:
  When Mario dies or a new game starts, restoring the entire level map takes exactly one instruction:
  ```nasm
  lea si, [original_map]  ; DS:SI points to master copy
  lea di, [working_map]   ; ES:DI points to runtime copy
  mov cx, 720             ; 720 bytes
  cld                     ; Direction forward
  rep movsb               ; Block copy in hardware!
  ```
  This restores broken bricks and collected coins instantly without looping manually!

---

### World Coordinates to Tile Index Conversion (`GetTile`)
To detect collisions and interact with blocks, we convert pixel world coordinates $(px, py)$ into tile array indices:
1. Divide pixel coordinates by 16 ($2^4$) using bit shifts:
   $$\text{col} = px \gg 4, \quad \text{row} = py \gg 4$$
2. Compute linear 1D offset in the 60-column map:
   $$\text{offset} = (\text{row} \times 60) + \text{col}$$
   To avoid the slow `MUL` instruction:
   $$\text{row} \times 60 = (\text{row} \times 64) - (\text{row} \times 4) = (\text{row} \ll 6) - (\text{row} \ll 2)$$
   ```nasm
   mov dx, bx
   shl dx, 6       ; dx = row * 64
   shl bx, 2       ; bx = row * 4
   sub dx, bx      ; dx = row * 60
   add dx, ax      ; dx = (row * 60) + col
   ```

---

### $O(1)$ Jump Table for `map_draw_tile`
Instead of cascading 13 conditional jumps (`cmp al, 0; je ...; cmp al, 1; je ...`), we use a **Jump Table**:
```nasm
    cmp ax, 12
    jbe .valid_tile
    jmp .done
.valid_tile:
    mov si, ax
    shl si, 1                   ; Multiply by 2 (word table)
    jmp [cs:.tile_jump_table + si] ; Direct indirect near jump!

.tile_jump_table:
    dw .draw_sky        ; 0
    dw .draw_ground     ; 1
    dw .draw_brick      ; 2
    dw .draw_q_blk      ; 3
    ...
```
- **Performance**: Every tile draws in constant $O(1)$ time regardless of whether it is Tile 0 or Tile 12.
- **Architectural Fix**: Bypasses the 8086 $\pm 127$-byte short jump limit cleanly.

---

## 8. Milestone 3 Viva Questions & Model Answers

### Q1: Why do you store two copies of the level map?
> **Answer**: During gameplay, Mario breaks bricks and empties question blocks, which permanently alters the map data. By maintaining an immutable `original_map` in ROM/code space and an active `working_map` in RAM, we can respawn or restart the level instantly by copying the original map over the working map using `REP MOVSB`.

### Q2: How does `REP MOVSB` work in `ResetMap`?
> **Answer**: `REP MOVSB` copies a string of bytes from `DS:SI` to `ES:DI`. Each iteration, it reads `[DS:SI]`, writes to `[ES:DI]`, increments both `SI` and `DI` (because `CLD` cleared the direction flag), and decrements `CX`. It repeats until `CX = 0`. With `CX = 720`, it restores the entire level map in a fraction of a millisecond.

### Q3: How do you map a Mario pixel coordinate $(px, py)$ to a tile in your 2D grid?
> **Answer**: Since each tile is $16 \times 16$ pixels, we shift $px$ and $py$ right by 4 bits (`shr 4`), which divides by 16. That gives us $\text{col}$ and $\text{row}$. Then we calculate the 1D index using $(\text{row} \times 60) + \text{col}$, which we compute with shifts: $(\text{row} \ll 6) - (\text{row} \ll 2) + \text{col}$.

### Q4: Why did you use a jump table in `DrawTile` instead of sequential `CMP` instructions?
> **Answer**: First, a chain of 13 comparisons would require up to 13 branch evaluations per tile, which causes performance penalties when rendering 240+ tiles per frame. A jump table executes in $O(1)$ constant time by indexing directly to the handler address. Second, on the 8086, conditional jumps are limited to $\pm 127$ bytes; the jump table uses an indirect near jump `jmp [table + si]`, which eliminates displacement range errors.
