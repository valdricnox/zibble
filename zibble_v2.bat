@echo off
:: =============================================================================
::  ZIBBLE'S PERFORMANCE v2.0 — Launcher
::  Auto-elevação de Administrador + Detecção de PS local ou remoto
:: =============================================================================
title Zibble's Performance v2.0

chcp 65001 >nul 2>&1

:: Verificar admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  [ZIBBLE] Solicitando privilegios de Administrador...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

cls
echo.
echo   ______ ___ ____  ____  _     _____ 
echo  ^|__  __^|_ ^|  _ \^|  _ \^| ^|   ^| ____^|
echo     ^| ^|  / / ^| ^|_) ^| ^|_) ^| ^|   ^|  _^|  
echo     ^| ^| / /^|  _ ^<^|  _ ^<^| ^|___^| ^|___ 
echo     ^|_^|/_/ ^|_^| \_\_^| \_\_____ \_____ ^|
echo.
echo  ZIBBLE'S PERFORMANCE v2.0 — Windows Optimization Toolkit
echo  ============================================================
echo.

:: Habilitar ANSI e scripts PS
reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f >nul 2>&1
powershell -Command "Set-ExecutionPolicy Bypass -Scope CurrentUser -Force" >nul 2>&1

:: Verificar se PS local existe
set "PS_PATH=%~dp0zibble.ps1"

if exist "%PS_PATH%" (
    echo  [OK] Script encontrado localmente.
    echo  Iniciando Zibble...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_PATH%"
) else (
    echo  [INFO] Script nao encontrado localmente.
    echo  Baixando da internet...
    echo.
    echo  Execute no PowerShell Admin:
    echo  irm https://raw.githubusercontent.com/valdricnox/zibble/refs/heads/main/zibble_v2.ps1 | iex ^| iex
    echo.
    set /p resposta="Deseja abrir o PowerShell agora? [S/N]: "
    if /i "%resposta%"=="S" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/valdricnox/zibble/main/zibble_v2.ps1 | iex"
    )
)

echo.
echo  Sessao encerrada.
pause
exit /b
