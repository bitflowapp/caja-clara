@echo off
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Quitar Caja Clara.ps1"
if errorlevel 1 (
  echo.
  echo La desinstalacion de Caja Clara no se completo.
  pause
)
