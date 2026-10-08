@echo off
set "GODOT=%LOCALAPPDATA%\CodexTools\Godot\Godot_v4.6.1-stable_win64.exe"
if exist "%GODOT%" (
  start "Lume" "%GODOT%" --path "%~dp0."
) else (
  echo Abra project.godot no Godot 4.6 e pressione F5.
  pause
)
