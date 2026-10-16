@echo off
rem Opens Briarhold in the Godot editor. Prefers Godot 4.8 in %USERPROFILE%\Tools.
setlocal
set "REPO=%~dp0"
set "GODOT="
for /d %%D in ("%USERPROFILE%\Tools\Godot-4.8*") do for %%F in ("%%D\Godot_v4*_win64.exe") do set "GODOT=%%F"
if not defined GODOT (
  for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do for %%F in ("%%D\Godot_v4*_win64.exe") do set "GODOT=%%F"
)
if not defined GODOT (
  echo Godot not found. See README.md for the install steps.
  pause
  exit /b 1
)
start "" "%GODOT%" --editor --path "%REPO%."
