@echo off
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar Caja Clara.ps1"
if errorlevel 1 (
  echo.
  echo La instalacion de Caja Clara no se completo.
  pause
)
