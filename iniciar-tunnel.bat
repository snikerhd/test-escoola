@echo off
cd /d "%~dp0"
title Tunel FIXO - Addon RuTracker (Tailscale Funnel)

echo.
echo  ==================================================
echo    TUNEL FIXO PARA O ADDON (Tailscale Funnel)
echo    O URL fica SEMPRE igual. Instalas 1x no Stremio.
echo  ==================================================
echo.
echo  1. O site tem de estar ligado primeiro (iniciar-site.bat)
echo  2. Este bat liga o URL fixo, que aparece abaixo.
echo  3. Usa esse URL no Stremio UMA vez e nunca mais precisas gerar nada.
echo.

set TSDIR=C:\Program Files\Tailscale
if exist "%TSDIR%\tailscale.exe" set PATH=%PATH%;%TSDIR%
where tailscale
if errorlevel 1 (
    echo [ERRO] O Tailscale nao esta instalado.
    echo        Corre o PREPARAR.bat primeiro.
    pause
    exit /b 1
)

echo A verificar login no Tailscale...
tailscale status
if errorlevel 1 (
    echo.
    echo [ACAO NECESSARIA - so 1x] Abre a app Tailscale e faz login,
    echo depois volta a correr este bat.
    pause
    exit /b 1
)

echo.
echo A ligar o URL fixo na porta 3000...
echo DEIXA ESTA JANELA ABERTA enquanto usas o Stremio.
echo O URL fixo aparece abaixo. Copia-o para o Stremio UMA vez.
echo.
tailscale funnel http://localhost:3000
echo.
echo (O tunel parou. Volta a correr este bat para ligar de novo.)
pause
