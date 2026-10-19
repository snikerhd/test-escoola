@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

rem ---------- Pedir permissoes de administrador (uma so vez) ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo A pedir permissoes de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
title Addon RuTracker - Instalacao Automatica

echo.
echo  ==================================================
echo    ADDON RUTRACKER - INSTALACAO AUTOMATICA
echo    Isto instala tudo o que e preciso. Nao desligues
echo    a janela nem respondas Nao ao Windows.
echo  ==================================================
echo.

rem ---------- [1/8] winget ----------
echo [1/8] A verificar o gestor de instalacao do Windows (winget)...
where winget >nul 2>nul
if errorlevel 1 (
    echo.
    echo   [ERRO] O teu Windows nao tem o "winget".
    echo          Atualiza o Windows ou instala "App Installer" da Microsoft Store,
    echo          e volta a correr este ficheiro.
    echo.
    pause
    exit /b 1
)
echo        OK.
echo.

rem ---------- [2/8] Node.js ----------
echo [2/8] A verificar o Node.js...
set "PATH=%PATH%;%ProgramFiles%\nodejs"
where node >nul 2>nul
if errorlevel 1 (
    echo        Nao encontrado. A instalar Node.js LTS... pode demorar.
    call winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    set "PATH=%PATH%;%ProgramFiles%\nodejs"
    where node >nul 2>nul
    if errorlevel 1 (
        echo.
        echo   [ERRO] Falhou a instalacao do Node.js. Fecha esta janela, abre-a outra
        echo          vez e volta a correr o PREPARAR.bat.
        pause
        exit /b 1
    )
)
for /f "delims=" %%v in ('node -v') do set NODEV=%%v
echo        OK - Node.js !NODEV!.
echo.

rem ---------- [3/8] PostgreSQL ----------
echo [3/8] A verificar o PostgreSQL...
set PGINST=0
if exist "%ProgramFiles%\PostgreSQL" for /d %%d in ("%ProgramFiles%\PostgreSQL\*") do set PGINST=1
powershell -NoProfile -Command "(Test-NetConnection 127.0.0.1 -Port 5432 -WarningAction SilentlyContinue).TcpTestSucceeded" | findstr /i true >nul && set PGINST=1
if "!PGINST!"=="1" (
    echo        OK - PostgreSQL ja existe neste PC.
) else (
    echo        Nao encontrado. A instalar PostgreSQL 16... pode demorar bastante.
    echo        (password do utilizador postgres fica: postgres^)
    call winget install PostgreSQL.PostgreSQL.16 --silent --accept-package-agreements --accept-source-agreements --override "--mode unattended --unattendedmodeui minimal --superpassword postgres --serverport 5432 --enable-components server,commandlinetools"
    echo        A esperar pelo arranque do servico...
    set PGOK=False
    for /l %%t in (1,1,24) do (
        if "!PGOK!"=="False" (
            timeout /t 5 /nobreak >nul
            powershell -NoProfile -Command "(Test-NetConnection 127.0.0.1 -Port 5432 -WarningAction SilentlyContinue).TcpTestSucceeded" | findstr /i true >nul && set PGOK=True
        )
    )
    if not "!PGOK!"=="True" (
        echo.
        echo   [ERRO] O PostgreSQL ficou instalado mas nao responde ainda.
        echo          Reinicia o PC e volta a correr o PREPARAR.bat.
        pause
        exit /b 1
    )
)
echo.

rem ---------- [4/8] Ficheiro .env ----------
echo [4/8] A criar o ficheiro .env...
if exist ".env" (
    echo        Ja existe - a manter o atual.
) else (
    (
        echo RUTRACKER_BASE=https://rutracker.org/forum
        echo DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/app_db
    ) > ".env"
    echo        .env criado.
)
echo.

rem ---------- [5/8] Dependencias + base de dados ----------
echo [5/8] A instalar dependencias npm... pode demorar varios minutos.
call npm install
if errorlevel 1 (
    echo.
    echo   [ERRO] Falhou o npm install. Verifica a internet e tenta outra vez.
    pause
    exit /b 1
)
echo        OK - dependencias instaladas.

echo        A preparar a base de dados app_db...
set PSQL=
for /d %%d in ("%ProgramFiles%\PostgreSQL\*") do if exist "%%d\bin\psql.exe" set PSQL=%%d\bin\psql.exe
if defined PSQL (
    set PGPASSWORD=postgres
    "!PSQL!" -U postgres -h 127.0.0.1 -tAc "SELECT 1 FROM pg_database WHERE datname='app_db'" 2>nul | findstr /q 1 >nul
    if errorlevel 1 "!PSQL!" -U postgres -h 127.0.0.1 -c "CREATE DATABASE app_db" 2>nul
    echo        OK - base de dados garantida.
) else (
    echo        psql nao encontrado - vou tentar criar as tabelas na mesma.
)
call npx drizzle-kit push
if errorlevel 1 (
    echo.
    echo   [AVISO] O passo da base de dados foi saltado (a base tem tabelas
    echo           de outro projeto e o addon nao precisa delas para os streams).
    echo           A continuar...
)
echo        OK - tabelas criadas.
echo.

rem ---------- [6/8] Google Chrome (e o browser que o addon usa) ----------
echo [6/8] A verificar o Google Chrome que o addon usa...
set CHROME=0
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set CHROME=1
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set CHROME=1
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set CHROME=1
if "!CHROME!"=="1" (
    echo        OK - Chrome ja esta instalado.
) else (
    echo        Nao encontrado. A instalar o Google Chrome...
    call winget install Google.Chrome --silent --accept-package-agreements --accept-source-agreements
    if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
        echo        OK - Chrome instalado.
    ) else if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
        echo        OK - Chrome instalado.
    ) else (
        echo        [AVISO] Nao consegui instalar o Chrome. Instala-o de:
        echo                https://www.google.com/chrome e volta a correr.
    )
)
echo.

rem ---------- [7/8] cloudflared (tunel publico) + Tailscale (URL FIXO) ----------
echo [7/8] A verificar o cloudflared (tunel para link publico)...
set CF=0
where cloudflared >nul 2>nul && set CF=1
if exist "%ProgramFiles%\cloudflared\cloudflared.exe" set CF=1
if "!CF!"=="1" (
    echo        OK - cloudflared ja esta instalado.
) else (
    echo        Nao encontrado. A instalar o cloudflared...
    call winget install Cloudflare.cloudflared --silent --accept-package-agreements --accept-source-agreements
    if exist "%ProgramFiles%\cloudflared\cloudflared.exe" (
        echo        OK - cloudflared instalado.
    ) else (
        echo        [AVISO] Nao consegui instalar o cloudflared automaticamente.
        echo                Sem ele nao ha link publico, mas o site funciona neste PC.
    )
)
echo.
echo        A verificar o Tailscale (URL FIXO, sem gerar nada)...
where tailscale >nul 2>nul
if errorlevel 1 (
    echo        Nao encontrado. A instalar o Tailscale...
    call winget install Tailscale.Tailscale --silent --accept-package-agreements --accept-source-agreements
    echo        OK - Tailscale instalado.
    echo        NOTA: abre a app Tailscale e faz login com Google/Microsoft/GitHub.
) else (
    echo        OK - Tailscale ja esta instalado.
)
echo.

rem ---------- [8/8] Login no RuTracker ----------
echo [8/8] Falta so uma coisa: o login no RuTracker!
echo       Vai abrir uma janela do Chrome.
echo       Entra com a TUA conta la dentro e fecha a janela no fim.
echo.
pause
call node open-login.mjs

echo.
echo ==============================================
echo    TUDO PRONTO E AUTOMATICO!
echo    De agora em diante basta abrir:
echo       iniciar-site.bat
echo    e depois entrar em http://localhost:3000
echo ==============================================
echo.
pause
