@echo off
cd /d "%~dp0"
echo A iniciar o site em http://localhost:3000 ...
echo Modo PRODUCAO, compativel com o tunel cloudflared.
echo.

REM Build de producao so quando necessario: a pasta .next guarda o ultimo build.
REM Apaga a pasta .next se quiseres forcar um build novo depois de mudar codigo.
if exist ".next\BUILD_ID" goto dostart
echo A fazer o build de producao, so na primeira vez, demora 1-2 min ...
call npm run build
if errorlevel 1 goto buildfail
echo.
:dostart
call npm run start
goto fim
:buildfail
echo ERRO: O build falhou. Ve as mensagens acima.
:fim
pause