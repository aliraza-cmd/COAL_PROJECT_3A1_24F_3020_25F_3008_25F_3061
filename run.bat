@echo off
rem ============================================================================
rem Super Mario Engine Quick Run Script
rem Launches MARIO.COM inside DOSBox
rem ============================================================================

set DOSBOX="C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe"
set NASM_DIR=D:\nasm

if not exist %DOSBOX% (
    echo [ERROR] DOSBox executable not found at: %DOSBOX%
    pause
    exit /b 1
)

if not exist mario.com (
    echo [ERROR] mario.com not found. Please run build.bat first to compile!
    pause
    exit /b 1
)

%DOSBOX% -c "mount d %NASM_DIR%" -c "mount c %~dp0" -c "c:" -c "mario.com"
