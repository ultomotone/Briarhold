@echo off
rem Plays Briarhold from source with the installed Godot. No export needed.
rem Prefers Godot 4.8 in %USERPROFILE%\Tools; falls back to the winget 4.7.2.
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
start "" "%GODOT%" --path "%REPO%." --rendering-method forward_plus
