@echo off
setlocal
set "DIR=%LOCALAPPDATA%\StreamDeckAutoRecover"
if not exist "%DIR%" mkdir "%DIR%"
explorer "%DIR%"
