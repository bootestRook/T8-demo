@echo off
setlocal
cd /d "%~dp0.."

set "PY=tools\python\python.exe"
if exist "%PY%" goto run

where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  set "PY=python"
  goto run
)

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  set "PY=py"
  goto run
)

echo GodotMCP startup failed: Python was not found. 1>&2
exit /b 1

:run
"%PY%" "scripts\godot_mcp_stdio.py" %*
exit /b %ERRORLEVEL%
