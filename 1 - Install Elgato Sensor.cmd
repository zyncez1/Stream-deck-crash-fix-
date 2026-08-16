@echo off
setlocal
cd /d "%~dp0"
set "SRC=%~dp0com.zyncez.streamdeck-autorecover-sensor.sdPlugin"
set "BASE=%APPDATA%\Elgato\StreamDeck\Plugins"
set "DST=%BASE%\com.zyncez.streamdeck-autorecover-sensor.sdPlugin"

echo ============================================================
echo Stream Deck Auto-Recover - Install Elgato Sensor
echo ============================================================
echo.
echo This installs the background sensor that listens to the
echo Stream Deck SOFTWARE's own connection events.
echo.
if not exist "%SRC%\manifest.json" (
  echo ERROR: sensor plugin folder is missing.
  pause
  exit /b 1
)
if not exist "%BASE%" mkdir "%BASE%"
if exist "%DST%" rmdir /s /q "%DST%"
xcopy "%SRC%" "%DST%\" /E /I /Y >nul
if not exist "%DST%\manifest.json" (
  echo ERROR: plugin copy failed.
  pause
  exit /b 1
)
echo.
echo INSTALLED.
echo.
echo Now COMPLETELY QUIT Elgato Stream Deck from its system tray,
echo then reopen Stream Deck so it loads the sensor.
echo.
echo After that, launch StreamDeckAutoRecover.exe
pause
