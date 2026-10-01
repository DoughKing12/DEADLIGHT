@echo off
title Breachpoint Build Script
echo ==============================
echo   BREACHPOINT - Build
echo ==============================
echo.

:: Check for MinGW g++ (add C:\msys64\mingw64\bin to PATH if present)
where g++ >nul 2>&1
if %errorlevel% neq 0 if exist "C:\msys64\mingw64\bin\g++.exe" set "PATH=C:\msys64\mingw64\bin;%PATH%"

where g++ >nul 2>&1
if %errorlevel% equ 0 (
    echo Found MinGW g++. Building with g++...
    echo.
    g++ -O2 -std=c++17 -Wall -Wextra -static -o fps.exe fps.cpp -lgdi32 -lgdiplus -lwinmm
    if %errorlevel% equ 0 (
        echo.
        echo BUILD SUCCESSFUL! Run: fps.exe
        pause
        exit /b 0
    )
)

:: Check for MSVC (Visual Studio)
where cl >nul 2>&1
if %errorlevel% equ 0 (
    echo Found MSVC compiler. Building with cl.exe...
    echo.
    cl /O2 /EHsc /utf-8 fps.cpp /Fe:fps.exe /link user32.lib gdi32.lib gdiplus.lib winmm.lib
    if %errorlevel% equ 0 (
        echo.
        echo BUILD SUCCESSFUL! Run: fps.exe
        pause
        exit /b 0
    )
)

echo.
echo ERROR: No C++ compiler found!
echo.
echo Install one of the following:
echo.
echo   OPTION 1 - MinGW (fast):
echo     Download MSYS2 from https://www.msys2.org/
echo     Then run: pacman -S mingw-w64-x86_64-gcc
echo     Then re-run this script.
echo.
echo   OPTION 2 - MSVC:
echo     Download "Visual Studio Build Tools" from:
echo     https://visualstudio.microsoft.com/visual-cpp-build-tools/
echo     Select "Desktop development with C++" workload.
echo     Then run this script from "x64 Native Tools Command Prompt".
echo.
pause
