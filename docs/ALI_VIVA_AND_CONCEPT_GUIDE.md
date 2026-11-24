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
