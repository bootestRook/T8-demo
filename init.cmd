@echo off
setlocal
cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
  echo [FAIL] 未找到 PowerShell，无法运行初始化脚本。
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/bootstrap-cn.ps1" -InitPm -AutoInstallMissing
set "ERR=%ERRORLEVEL%"

echo.
if "%ERR%"=="0" (
  echo [OK] 初始化检查完成。下一步：在 AI 对话框输入 init。
) else (
  echo [WARN] 初始化未完全通过。请查看上方提示，把缺失的 portable 工具放到 tools\ 后再次运行。
)
pause
exit /b %ERR%
