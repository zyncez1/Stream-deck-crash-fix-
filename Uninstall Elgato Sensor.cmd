@echo off
setlocal
set "DST=%APPDATA%\Elgato\StreamDeck\Plugins\com.zyncez.streamdeck-autorecover-sensor.sdPlugin"
if exist "%DST%" rmdir /s /q "%DST%"
echo Sensor removed. Completely quit and reopen Stream Deck to finish unloading it.
pause
