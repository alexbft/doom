@echo off
rem Launch the arena mod (Windows). Extra arguments go to UZDoom, e.g. run.cmd +god
setlocal
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
if "%MAP%"=="" set "MAP=ARENA01"

if not exist "%ROOT%\engine\windows\uzdoom.exe" goto setup
if not exist "%ROOT%\iwad\freedoom2.wad" goto setup
goto run

:setup
echo Engine or IWAD missing - running setup first...
call "%ROOT%\setup.cmd" || exit /b 1

:run
if not exist "%ROOT%\config" mkdir "%ROOT%\config"
start "" "%ROOT%\engine\windows\uzdoom.exe" -config "%ROOT%\config\uzdoom.ini" -iwad "%ROOT%\iwad\freedoom2.wad" -file "%ROOT%\mod" +vid_fullscreen 0 +win_w 1280 +win_h 800 +map %MAP% %*
