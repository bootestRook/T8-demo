#!/usr/bin/env python3
"""Build a Windows-friendly local playable package for Godot Web exports."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
HTML5_DIR = PROJECT_ROOT / "html5"
EXPORTS_DIR = PROJECT_ROOT / "exports"
DEFAULT_OUT_DIR = EXPORTS_DIR / "T8-demo-playable"
DEFAULT_ZIP = EXPORTS_DIR / "T8-demo-playable.zip"
ENTRY_NAME = "index.html"


CMD_CONTENT = r"""@echo off
chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%serve-local.ps1"
if errorlevel 1 (
    echo.
    echo 启动失败。请确认已经完整解压压缩包，并且 www 目录没有被删除。
    pause
)
"""


POWERSHELL_CONTENT = r"""param(
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Www = Join-Path $Root "www"
$Index = Join-Path $Www "index.html"
$HostAddress = "127.0.0.1"
$StartPort = 8080

if (-not (Test-Path $Index)) {
    Write-Host "未找到 www\index.html。请完整解压压缩包后再双击启动游戏.cmd。" -ForegroundColor Red
    exit 1
}

function Start-Listener {
    param([int]$FirstPort)
    for ($Port = $FirstPort; $Port -lt 65535; $Port++) {
        try {
            $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse($HostAddress), $Port)
            $Listener.Start()
            return @{ Listener = $Listener; Port = $Port }
        } catch {
            continue
        }
    }
    throw "没有找到可用端口。"
}

function Get-MimeType {
    param([string]$Path)
    $Ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($Ext) {
        ".html" { "text/html; charset=utf-8" }
        ".js" { "application/javascript; charset=utf-8" }
        ".wasm" { "application/wasm" }
        ".pck" { "application/octet-stream" }
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".ico" { "image/x-icon" }
        ".json" { "application/json; charset=utf-8" }
        ".worker" { "application/javascript; charset=utf-8" }
        default { "application/octet-stream" }
    }
}

function ConvertTo-Bytes {
    param([string]$Text)
    return [System.Text.Encoding]::UTF8.GetBytes($Text)
}

function Write-TextResponse {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$Status,
        [string]$Reason,
        [string]$Text,
        [bool]$HeadOnly
    )
    Write-Response `
        -Stream $Stream `
        -Status $Status `
        -Reason $Reason `
        -MimeType "text/plain; charset=utf-8" `
        -Body (ConvertTo-Bytes $Text) `
        -HeadOnly $HeadOnly
}

function Write-Response {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$Status,
        [string]$Reason,
        [string]$MimeType,
        [byte[]]$Body,
        [bool]$HeadOnly
    )
    $Length = if ($null -eq $Body) { 0 } else { $Body.Length }
    $Header = "HTTP/1.1 $Status $Reason`r`n" +
        "Content-Length: $Length`r`n" +
        "Content-Type: $MimeType`r`n" +
        "Cross-Origin-Opener-Policy: same-origin`r`n" +
        "Cross-Origin-Embedder-Policy: require-corp`r`n" +
        "Cache-Control: no-cache, no-store, must-revalidate`r`n" +
        "Connection: close`r`n`r`n"
    $HeaderBytes = [System.Text.Encoding]::ASCII.GetBytes($Header)
    $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
    if (-not $HeadOnly -and $Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
    }
}

$Started = Start-Listener -FirstPort $StartPort
$Listener = $Started.Listener
$Port = $Started.Port
$Url = "http://${HostAddress}:$Port/"

Write-Host ""
Write-Host "游戏本地服务已启动：" -ForegroundColor Green
Write-Host $Url
Write-Host ""
Write-Host "浏览器将自动打开。关闭此窗口即可停止游戏服务。"
Write-Host ""
if (-not $NoOpen) {
    Start-Process $Url
}

try {
    while ($true) {
        $Client = $Listener.AcceptTcpClient()
        try {
            $Stream = $Client.GetStream()
            $Reader = [System.IO.StreamReader]::new($Stream, [System.Text.Encoding]::ASCII, $false, 8192, $true)
            $RequestLine = $Reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($RequestLine)) {
                continue
            }
            while ($true) {
                $Line = $Reader.ReadLine()
                if ($null -eq $Line -or $Line -eq "") { break }
            }

            $Parts = $RequestLine.Split(" ")
            $Method = $Parts[0].ToUpperInvariant()
            $RawPath = if ($Parts.Length -gt 1) { $Parts[1] } else { "/" }
            if ($Method -ne "GET" -and $Method -ne "HEAD") {
                Write-TextResponse -Stream $Stream -Status 405 -Reason "Method Not Allowed" -Text "Method Not Allowed" -HeadOnly ($Method -eq "HEAD")
                continue
            }

            $PathOnly = $RawPath.Split("?")[0]
            if ($PathOnly -eq "/") { $PathOnly = "/index.html" }
            $Relative = [Uri]::UnescapeDataString($PathOnly.TrimStart("/")).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
            $FullPath = [System.IO.Path]::GetFullPath((Join-Path $Www $Relative))
            $WwwFull = [System.IO.Path]::GetFullPath($Www)
            $WwwPrefix = $WwwFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
            if (-not $FullPath.StartsWith($WwwPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-TextResponse -Stream $Stream -Status 403 -Reason "Forbidden" -Text "Forbidden" -HeadOnly ($Method -eq "HEAD")
                continue
            }
            if (-not (Test-Path $FullPath -PathType Leaf)) {
                Write-TextResponse -Stream $Stream -Status 404 -Reason "Not Found" -Text "Not Found" -HeadOnly ($Method -eq "HEAD")
                continue
            }

            $Body = [System.IO.File]::ReadAllBytes($FullPath)
            Write-Response `
                -Stream $Stream `
                -Status 200 `
                -Reason "OK" `
                -MimeType (Get-MimeType $FullPath) `
                -Body $Body `
                -HeadOnly ($Method -eq "HEAD")
        } catch {
            try {
                Write-TextResponse `
                    -Stream $Stream `
                    -Status 500 `
                    -Reason "Internal Server Error" `
                    -Text "Internal Server Error" `
                    -HeadOnly $false
            } catch {}
        } finally {
            $Client.Close()
        }
    }
} finally {
    $Listener.Stop()
}
"""


README_CONTENT = """T8-demo 本地可游玩包

使用方式：
1. 先完整解压 zip，不要在压缩包预览窗口里直接运行。
2. 双击“启动游戏.cmd”。
3. 等待默认浏览器自动打开本地地址。
4. 游玩结束后，关闭启动窗口即可停止本地服务。

说明：
- 这是 Godot Web 导出的本地离线包。
- 不要直接双击 www/index.html；Godot Web 需要本地 HTTP 服务加载 .wasm 和 .pck 文件。
- 本包只在 Windows 上提供双击启动脚本。
"""


def _print(result: dict[str, Any], json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    status = result.get("status")
    if status == "ok":
        print(f"[OK] 本地可游玩包目录：{result['out_dir']}")
        print(f"[OK] zip：{result['zip']}")
        print("[NEXT] 把 zip 发给玩家；玩家完整解压后双击“启动游戏.cmd”。")
    else:
        print(f"[FAIL] {result.get('message', '打包失败')}")


def _safe_remove_dir(path: Path) -> None:
    resolved = path.resolve()
    exports = EXPORTS_DIR.resolve()
    if resolved == exports or exports not in resolved.parents:
        raise RuntimeError(f"拒绝清理 exports 之外的目录：{resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)


def _run_export(json_mode: bool) -> None:
    command = [sys.executable, str(PROJECT_ROOT / "scripts" / "export_web.py"), "--json"]
    result = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        message = (result.stdout or result.stderr or "export_web.py 失败").strip()
        raise RuntimeError(message)
    if not json_mode:
        print((result.stdout or "").strip())


def _collect_export_files() -> list[Path]:
    index = HTML5_DIR / ENTRY_NAME
    if not index.exists():
        raise RuntimeError("html5/index.html 不存在，请先运行 python scripts/export_web.py --json")

    files = [
        path
        for path in sorted(HTML5_DIR.iterdir())
        if path.is_file()
        and (path.name == ENTRY_NAME or path.name.startswith("index."))
        and path.name != ".gdignore"
        and path.suffix != ".import"
    ]
    required_suffixes = {".html", ".js", ".wasm", ".pck"}
    found_suffixes = {path.suffix for path in files}
    missing = sorted(required_suffixes - found_suffixes)
    if missing:
        raise RuntimeError(f"Web 导出产物不完整，缺少：{', '.join(missing)}")
    return files


def _write_launcher_files(out_dir: Path) -> None:
    (out_dir / "启动游戏.cmd").write_text(CMD_CONTENT, encoding="utf-8", newline="\r\n")
    (out_dir / "serve-local.ps1").write_text(POWERSHELL_CONTENT, encoding="utf-8-sig", newline="\r\n")
    (out_dir / "README.txt").write_text(README_CONTENT, encoding="utf-8", newline="\r\n")


def _zip_directory(source_dir: Path, zip_path: Path) -> tuple[int, int]:
    file_count = 0
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(source_dir.rglob("*")):
            if not path.is_file():
                continue
            arcname = Path(source_dir.name) / path.relative_to(source_dir)
            zf.write(path, arcname.as_posix())
            file_count += 1
    return file_count, zip_path.stat().st_size // 1024


def build_package(out_dir: Path, zip_path: Path, skip_export: bool, no_zip: bool, json_mode: bool) -> dict[str, Any]:
    if not skip_export:
        _run_export(json_mode=json_mode)

    files = _collect_export_files()
    _safe_remove_dir(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    www_dir = out_dir / "www"
    www_dir.mkdir(parents=True, exist_ok=True)

    for source in files:
        shutil.copy2(source, www_dir / source.name)
    _write_launcher_files(out_dir)

    zip_result = ""
    zip_size_kb = 0
    zip_file_count = 0
    if not no_zip:
        if zip_path.exists():
            zip_path.unlink()
        zip_file_count, zip_size_kb = _zip_directory(out_dir, zip_path)
        zip_result = str(zip_path)

    return {
        "status": "ok",
        "out_dir": str(out_dir),
        "zip": zip_result,
        "zip_size_kb": zip_size_kb,
        "file_count": len(files) + 3,
        "zip_file_count": zip_file_count,
        "launcher": str(out_dir / "启动游戏.cmd"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="生成可分享的 Windows 本地可游玩包")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="输出目录")
    parser.add_argument("--zip", dest="zip_path", default=str(DEFAULT_ZIP), help="zip 输出路径")
    parser.add_argument("--skip-export", action="store_true", help="跳过 Web 导出，直接使用现有 html5/")
    parser.add_argument("--no-zip", action="store_true", help="只生成目录，不生成 zip")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = PROJECT_ROOT / out_dir
    zip_path = Path(args.zip_path)
    if not zip_path.is_absolute():
        zip_path = PROJECT_ROOT / zip_path

    try:
        result = build_package(
            out_dir=out_dir,
            zip_path=zip_path,
            skip_export=args.skip_export,
            no_zip=args.no_zip,
            json_mode=args.json,
        )
    except Exception as exc:
        _print({"status": "error", "message": str(exc)}, args.json)
        return 1

    _print(result, args.json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
