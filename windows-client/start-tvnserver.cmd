@echo off
rem ============================================================
rem  caraprojetada - launcher do tightvnc server (portatil)
rem  nao instala, nao baixa. roda o caraprojetada-vnc.exe ao lado.
rem  o usuario define a senha na propria GUI do tightvnc.
rem  o PIN informado no painel do projetor = essa senha.
rem ============================================================
setlocal
title caraprojetada - tightvnc server
cd /d "%~dp0"

if not exist "%~dp0caraprojetada-vnc.exe" (
    echo [erro] caraprojetada-vnc.exe nao encontrado ao lado deste script.
    echo baixe em: https://github.com/Deivisan/caraprojetada/releases/latest/download/caraprojetada-vnc.exe
    pause
    exit /b 1
)

echo.
echo  ===============================================
echo   caraprojetada - tightvnc server (portatil)
echo  ===============================================
echo.
echo  1. vai abrir a janela do tightvnc server.
echo  2. o app ja mostra um PIN na tela (automatico).
echo  3. use esse PIN no painel do projetor ao conectar.
echo  4. mantenha a janela aberta durante a projecao.
echo.
echo  aguarde a interface abrir...
echo.

start "" "%~dp0caraprojetada-vnc.exe"
exit /b 0
