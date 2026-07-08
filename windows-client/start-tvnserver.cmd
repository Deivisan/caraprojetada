@echo off
rem ============================================================
rem  caraprojetada - launcher do tightvnc server (portatil)
rem  nao instala, nao baixa. roda o tvnserver.exe ao lado.
rem  o usuario define a senha na propria GUI do tightvnc.
rem  o PIN informado no painel do projetor = essa senha.
rem ============================================================
setlocal
title caraprojetada - tightvnc server
cd /d "%~dp0"

if not exist "%~dp0tvnserver.exe" (
    echo [erro] tvnserver.exe nao encontrado ao lado deste script.
    pause
    exit /b 1
)

echo.
echo  ===============================================
echo   caraprojetada - tightvnc server (portatil)
echo  ===============================================
echo.
echo  1. vai abrir a janela do tightvnc server.
echo  2. em "administration" defina a senha do vnc.
echo  3. essa senha e o PIN usado no painel do projetor.
echo  4. mantenha a janela aberta durante a projecao.
echo.
echo  aguarde a interface abrir...
echo.

start "" "%~dp0tvnserver.exe"
exit /b 0
