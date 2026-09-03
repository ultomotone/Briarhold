@echo off
rem Plays Briarhold from source with the installed Godot editor binary. No export needed.
setlocal
set "REPO=%~dp0"
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do set "PK=%%D"
for %%F in ("%PK%\Godot_v4*_win64.exe") do set "GODOT=%%F"
if not exist "%GODOT%" (
  echo Godot not found. Install with: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%REPO%." --rendering-method forward_plus
