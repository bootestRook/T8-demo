#!/usr/bin/env python3
"""内置质量工具准备脚本。

默认只检查，不联网、不安装。传入 --install --yes 后，才会把 Python 包下载到
tools/ 下。GDUnit4 addon 属于可选能力，需额外传入 --install-gdunit。
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_ROOT / "spec" / "quality_tools.json"
RUNNER = PROJECT_ROOT / "scripts" / "run_python_entrypoint.py"


def _load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def _run(command: list[str], timeout: int = 300, env: dict[str, str] | None = None) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            env=env,
        )
        return result.returncode == 0, (result.stdout or "").strip()
    except Exception as exc:
        return False, str(exc)


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _download(url: str, output: Path, attempts: int = 3) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    headers = {"User-Agent": "godot-v1-plus-quality-tools"}
    last_error: Exception | None = None
    for _ in range(max(1, attempts)):
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=120) as response:
                output.write_bytes(response.read())
            return
        except Exception as exc:
            last_error = exc
            if sys.platform == "win32":
                ps = shutil.which("powershell")
                if ps:
                    escaped_output = str(output).replace("'", "''")
                    command = [
                        ps,
                        "-NoProfile",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-Command",
                        (
                            "$ProgressPreference='SilentlyContinue'; "
                            f"Invoke-WebRequest -Uri '{url}' "
                            "-Headers @{ 'User-Agent'='godot-v1-plus-quality-tools' } "
                            f"-OutFile '{escaped_output}' "
                            "-TimeoutSec 120"
                        ),
                    ]
                    ok, text = _run(command, timeout=150)
                    if ok and output.is_file() and output.stat().st_size > 0:
                        return
                    last_error = RuntimeError(text or "PowerShell download failed")
    raise RuntimeError(f"下载失败：{url}；{last_error}")


def _pip_install_target(packages: list[str], target: Path) -> tuple[bool, str]:
    target.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "--upgrade",
        "--target",
        str(target),
        *packages,
    ]
    return _run(command, timeout=900)


def _install_gdunit4(config: dict[str, Any], force: bool) -> tuple[bool, str]:
    addon_path = PROJECT_ROOT / config["addon_path"]
    if addon_path.exists() and not force:
        return True, f"{_rel(addon_path)} 已存在。"

    with tempfile.TemporaryDirectory(prefix="gdunit4-") as temp_raw:
        temp = Path(temp_raw)
        archive = temp / "gdunit4.zip"
        _download(config["source_zip"], archive)
        with zipfile.ZipFile(archive) as zip_file:
            zip_file.extractall(temp)

        candidates = [path for path in temp.rglob("addons/gdUnit4") if path.is_dir()]
        if not candidates:
            return False, "GDUnit4 source zip 中未找到 addons/gdUnit4。"
        source = candidates[0]
        if addon_path.exists():
            shutil.rmtree(addon_path)
        addon_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, addon_path)
    return True, f"已安装 {_rel(addon_path)}。"


def _gdunit4_ready(config: dict[str, Any]) -> bool:
    return (PROJECT_ROOT / config["addon_path"] / "bin" / "GdUnitCmdTool.gd").is_file()


def _python_entry_available(target: Path, entry: str) -> bool:
    if not target.exists():
        return False
    script = (
        "import importlib.metadata as m, sys; "
        f"eps=m.entry_points().select(group='console_scripts', name='{entry}'); "
        "sys.exit(0 if list(eps) else 1)"
    )
    ok, _ = _run([sys.executable, "-c", script], timeout=60, env={**os.environ, "PYTHONPATH": str(target)})
    return ok


def _check_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    gdtoolkit = manifest["gdscript_toolkit"]
    gdtoolkit_target = PROJECT_ROOT / gdtoolkit["target"]
    gdunit4 = manifest["gdunit4"]

    checks = [
        {
            "name": "GDScript Toolkit / gdlint",
            "status": "PASS" if _python_entry_available(gdtoolkit_target, "gdlint") else "FAIL",
            "detail": gdtoolkit["target"],
        },
        {
            "name": "GDScript Toolkit / gdformat",
            "status": "PASS" if _python_entry_available(gdtoolkit_target, "gdformat") else "FAIL",
            "detail": gdtoolkit["target"],
        },
        {
            "name": "GDUnit4 addon",
            "status": "PASS" if _gdunit4_ready(gdunit4) else "WARN",
            "detail": gdunit4["addon_path"],
        }
    ]
    required_ok = all(item["status"] == "PASS" for item in checks[:2])
    status = "PASS" if required_ok else "FAIL"
    return {"status": status, "checks": checks}


def _print_report(report: dict[str, Any], json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    print("## Quality Tools Setup")
    print("")
    for item in report["checks"]:
        print(f"- {item['status']} {item['name']}: {item['detail']}")
    print("")
    print(f"结论：{report['status']}")


def main() -> int:
    parser = argparse.ArgumentParser(description="准备内置质量工具")
    parser.add_argument("--install", action="store_true", help="下载并安装可自动准备的质量工具")
    parser.add_argument("--install-gdunit", action="store_true", help="可选：下载并安装 GDUnit4 addon")
    parser.add_argument("--yes", action="store_true", help="确认允许联网下载和写入 tools/addons")
    parser.add_argument("--force", action="store_true", help="覆盖已存在的 GDUnit4 addon")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    manifest = _load_manifest()
    if args.install or args.install_gdunit:
        if not args.yes:
            print("[FAIL] --install 或 --install-gdunit 需要同时传入 --yes，确认允许联网下载和写入项目 tools/addons。")
            return 1
    if args.install:
        gdtoolkit_ok, gdtoolkit_text = _pip_install_target(
            [manifest["gdscript_toolkit"]["package"]],
            PROJECT_ROOT / manifest["gdscript_toolkit"]["target"],
        )
        if not gdtoolkit_ok:
            print(gdtoolkit_text)
            return 1
    if args.install_gdunit:
        gdunit_ok, gdunit_text = _install_gdunit4(manifest["gdunit4"], args.force)
        if not gdunit_ok:
            print(gdunit_text)
            return 1

    report = _check_manifest(manifest)
    _print_report(report, args.json)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
