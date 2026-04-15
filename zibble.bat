@echo off
:: =============================================================================
::  ZIBBLE'S PERFORMANCE — Launcher
::  Abre o zibble.ps1 com privilegios de Administrador automaticamente
::  Para acesso rapido via PowerShell:
::    irm https://raw.githubusercontent.com/SEU_USUARIO/zibble/main/zibble.ps1 | iex
:: =============================================================================

title Zibble's Performance — Launcher
chcp 65001 >nul 2>&1

:: Verificar privilegios de admin
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :run
) else (
    goto :elevate
)

:elevate
echo.
echo  [ZIBBLE] Solicitando privilegios de Administrador...
echo.
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:run
cls
echo.
echo  +-----------------------------------------------------------------+
echo  ^|          ZIBBLE'S PERFORMANCE — Windows Optimization           ^|
echo  ^|                      Iniciando...                              ^|
echo  +-----------------------------------------------------------------+
echo.

:: Verificar se o zibble.ps1 esta na mesma pasta
set "PS_PATH=%~dp0zibble.ps1"

if exist "%PS_PATH%" (
    echo  Script encontrado: %PS_PATH%
    echo  Iniciando em 2 segundos...
    timeout /t 2 /nobreak >nul
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_PATH%"
) else (
    echo  Script local nao encontrado. Baixando da internet...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/SEU_USUARIO/zibble/main/zibble.ps1 | iex"
)

echo.
echo  Zibble's Performance encerrado.
pause
exit /b
