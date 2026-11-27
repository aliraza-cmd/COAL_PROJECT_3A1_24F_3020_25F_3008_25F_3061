# Super Mario Engine — 16-bit x86 Assembly (NASM + DOSBox)
**Course**: EL2003 Computer Organization and Assembly Language  
**Section**: BSE-3A1 | Fall 2026  
**Repository**: `COAL_PROJECT_3A1_24F_3020_25F_3008_25F_3061`

---

## 👥 Team Members & Module Distribution

| Member Name | Roll Number | Assigned Modules | Subsystems Owned |
| :--- | :--- | :--- | :--- |
| **Ali Raza** | **24F-3020** | **Modules 1, 2, 3, 4, 5** | Foundation, VGA Mode 13h primitives, 60x12 tile map, sprite engine, double buffering |
| **Umama** | **25F-3061** | **Modules 6, 7, 8, 9, 10** | Scrolling camera, custom keyboard ISR (port 60h), timer ISR, 8.8 physics, collision |
| **Aiza** | **25F-3008** | **Modules 11, 12, 13, 14, 15** | Enemies AI (Goomba/Koopa/Shell), interactive blocks, HUD/Score, state machine, lifecycle |

---

## 📁 Repository Structure

```
├── build.bat                  # One-click build and launch script for DOSBox
├── run.bat                    # Quick launcher for MARIO.COM
├── MARIO.COM                  # Generated 16-bit executable binary
├── README.md                  # Project overview, team allocation, and build guide
├── docs/
│   └── ALI_VIVA_AND_CONCEPT_GUIDE.md  # Detailed concepts, memory architecture & viva prep
└── src/
    ├── mario.asm              # Master program entry point (ORG 100h) & state controller
    ├── const.inc              # Global EQU constants (dimensions, colors, tile IDs)
    ├── data.inc               # Global memory variables & segment pointers
    ├── video.asm              # Mode 13h, primitives & double buffering (Ali)
    ├── map.asm                # Tile map data, GetTile & ResetMap (Ali)
    └── sprites.asm            # Original 16x16 / 16x32 bitmaps & DrawSprite (Ali)
```

---

## ⚙️ How to Build and Run

### Method 1: Using `build.bat` (Recommended)
Simply double click `build.bat` or run it from command prompt:
```cmd
build.bat
```
This automatically assembles `src\mario.asm` using NASM and launches `MARIO.COM` in DOSBox.

### Method 2: Manual Commands inside DOSBox
Open DOSBox and type:
```cmd
Z:\> mount d D:\nasm
Z:\> mount c C:\Users\Ali\OneDrive\Desktop\COAL PROJECT\COAL_PROJECT_3A1_24F_3020_25F_3008_25F_3061
Z:\> c:
C:\> d:\nasm -f bin src\mario.asm -o mario.com
C:\> mario.com
```

### Method 3: Debugging with AFD
```cmd
C:\> d:\afd mario.com
```

---

## 🧠 Memory Architecture (Milestone 1)
- Target executable: Single-segment `.COM` format loaded at `ORG 100h`.
- Conventional memory allocation: Shrunk to 64 KB using `INT 21h, AH=4Ah`.
- Off-screen frame buffer: Dynamically allocates a separate 64,000-byte segment (`320x200` backbuffer) using `INT 21h, AH=48h` and releases it cleanly on exit via `AH=49h`.
