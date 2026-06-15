#!/usr/bin/env python3
"""
Godot 质量工具入口。

默认门禁：
- GDScript Toolkit: gdlint + gdformat --check

可选检查：
- GDUnit4（传入 --run-gdunit 时执行）
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GODOT_ENV_KEY = "GODOT4_PATH"
GDLINT_ENV_KEY = "GDLINT_PATH"
GDFORMAT_ENV_KEY = "GDFORMAT_PATH"
RUNNER = PROJECT_ROOT / "scripts" / "run_python_entrypoint.py"
GDTOOLKIT_TARGET = PROJECT_ROOT / "tools" / "gdtoolkit" / "python"

GDSCRIPT_SOURCE_ROOTS = (
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "scenes",
)
GDUNIT_TEST_ROOTS = (
    PROJECT_ROOT / "tests" / "gdunit",
    PROJECT_ROOT / "test",
)

checks: list[dict[str, str]] = []
final_status = "PASS"


def _run(command: list[str], timeout: int = 180, env: dict[str, str] | None = None) -> tuple[int, str]:
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
        return result.returncode, (result.stdout or "").strip()
    except subprocess.TimeoutExpired:
        return 124, f"Command '{' '.join(command)}' timed out after {timeout} seconds"
    except Exception as exc:
        return 1, str(exc)


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _path_variants(base: Path, command_name: str) -> list[Path]:
    if sys.platform == "win32":
        return [
            base / command_name,
            base / f"{command_name}.exe",
            base / f"{command_name}.cmd",
            base / f"{command_name}.bat",
        ]
    return [base / command_name]


def _find_command(command_name: str, env_key: str = "", extra_dirs: tuple[Path, ...] = ()) -> str | None:
    candidates: list[str] = []
    if env_key and os.environ.get(env_key):
        candidates.append(str(os.environ[env_key]))
    for directory in extra_dirs:
        for path in _path_variants(directory, command_name):
            candidates.append(str(path))
    candidates.append(command_name)

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if resolved:
            return str(resolved)
    return None


def _sort_godot_exec_paths(paths: list[Path]) -> list[str]:
    dedup: list[str] = []
    seen: set[str] = set()
    for path in paths:
        if not path.is_file():
            continue
        text = str(path)
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        dedup.append(text)
    return sorted(
        dedup,
        key=lambda value: (
            0 if "console" in Path(value).name.lower() else 1,
            Path(value).name.lower(),
            value.lower(),
        ),
    )


def _find_godot(hint: str = "") -> str | None:
    candidates: list[str] = []
    if hint:
        candidates.append(hint)
    env = os.environ.get(GODOT_ENV_KEY)
    if env:
        candidates.append(env)
    for root in (PROJECT_ROOT / "tools" / "godot", PROJECT_ROOT / "tools"):
        if root.exists():
            candidates += _sort_godot_exec_paths([
                *root.rglob("Godot*.exe"),
                *root.rglob("godot*.exe"),
            ])
    candidates += ["godot4", "godot"]

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if resolved:
            return str(resolved)
    return None


def _gdscript_files() -> list[Path]:
    files: list[Path] = []
    for root in GDSCRIPT_SOURCE_ROOTS:
        if root.exists():
            files += [path for path in root.rglob("*.gd") if path.is_file()]
    return sorted(files)


def _gdtoolkit_dirs() -> tuple[Path, ...]:
    return (
        PROJECT_ROOT / "tools" / "gdtoolkit" / "Scripts",
        PROJECT_ROOT / "tools" / "gdtoolkit" / "bin",
        PROJECT_ROOT / "tools" / "python" / "Scripts",
    )


def _check_gdscript_toolkit() -> None:
    files = _gdscript_files()
    if not files:
        _add("GDScript Toolkit", "PASS", "未找到 src/ 或 scenes/ 下的 .gd 文件，跳过。")
        return

    dirs = _gdtoolkit_dirs()
    gdlint = _find_command("gdlint", GDLINT_ENV_KEY, dirs)
    gdformat = _find_command("gdformat", GDFORMAT_ENV_KEY, dirs)

    if not gdlint and GDTOOLKIT_TARGET.exists():
        gdlint = f"{sys.executable}|{RUNNER}|{GDTOOLKIT_TARGET}|gdlint"
    if not gdformat and GDTOOLKIT_TARGET.exists():
        gdformat = f"{sys.executable}|{RUNNER}|{GDTOOLKIT_TARGET}|gdformat"

    file_args = [_rel(path) for path in files]
    if gdlint:
        command = gdlint.split("|")
        if len(command) == 4:
            code, text = _run([command[0], command[1], "--target", command[2], command[3], *file_args], timeout=180)
        else:
            code, text = _run([gdlint, *file_args], timeout=180)
        _add("gdlint", "PASS" if code == 0 else "FAIL", f"{len(files)} 个 GDScript 文件" if code == 0 else text)
    else:
        _add("gdlint", "FAIL", "GDScript Toolkit 是必选门禁，未找到 gdlint。运行 scripts/setup_quality_tools.py --install --yes。")

    if gdformat:
        command = gdformat.split("|")
        if len(command) == 4:
            code, text = _run([command[0], command[1], "--target", command[2], command[3], "--check", *file_args], timeout=180)
        else:
            code, text = _run([gdformat, "--check", *file_args], timeout=180)
        _add("gdformat --check", "PASS" if code == 0 else "FAIL", "格式检查通过。" if code == 0 else text)
    else:
        _add("gdformat --check", "FAIL", "GDScript Toolkit 是必选门禁，未找到 gdformat。运行 scripts/setup_quality_tools.py --install --yes。")


def _find_gdunit_tool() -> Path | None:
    for rel in (
        Path("addons") / "gdUnit4" / "bin" / "GdUnitCmdTool.gd",
        Path("addons") / "gdunit4" / "bin" / "GdUnitCmdTool.gd",
    ):
        path = PROJECT_ROOT / rel
        if path.is_file():
            return path
    return None


def _gdunit_test_roots() -> list[Path]:
    return [root for root in GDUNIT_TEST_ROOTS if root.exists() and any(root.rglob("*.gd"))]


def _godot_script_command(godot: str, script: str, args: list[str]) -> list[str]:
    if sys.platform == "win32":
        shell = shutil.which("powershell")
        if shell:
            def quote(value: str) -> str:
                return "'" + value.replace("'", "''") + "'"

            command = " ".join(
                [
                    f"& {quote(godot)}",
                    "--headless",
                    "--path",
                    quote(str(PROJECT_ROOT)),
                    "-s",
                    quote(script),
                    *[quote(arg) for arg in args],
                ]
            )
            return [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]
    return [godot, "--headless", "--path", str(PROJECT_ROOT), "-s", script, *args]


def _check_gdunit4(args: argparse.Namespace) -> None:
    tool = _find_gdunit_tool()
    test_roots = _gdunit_test_roots()
    if not tool and not test_roots:
        _add("GDUnit4", "FAIL", "已启用 GDUnit4 检查，但未检测到 addon 或 tests/gdunit。运行 scripts/setup_quality_tools.py --install-gdunit --yes。")
        return
    if not tool:
        _add("GDUnit4", "FAIL", "发现 GDUnit 测试目录，但未找到 addons/gdUnit4/bin/GdUnitCmdTool.gd。")
        return
    if not test_roots:
        _add("GDUnit4", "FAIL", "已启用 GDUnit4 检查，但未找到 tests/gdunit 或 test/ 下的 GDScript 测试。")
        return

    godot = _find_godot(args.godot)
    if not godot:
        _add("GDUnit4", "FAIL", "发现 GDUnit4 测试，但未找到 Godot 可执行文件。")
        return

    command_args: list[str] = []
    for root in test_roots:
        command_args += ["-a", str(root)]
    command_args += ["-c", "--ignoreHeadlessMode", "-rd", "res://reports/gdunit4", "-rc", "3"]
    script_path = "res://" + _rel(tool)
    command = _godot_script_command(godot, script_path, command_args)
    code, text = _run(command, timeout=args.gdunit_timeout)
    if code == 0:
        _add("GDUnit4", "PASS", f"测试通过：{', '.join(_rel(root) for root in test_roots)}")
    elif code == 101:
        _add("GDUnit4", "CONCERNS", text[-2000:] if text else "GDUnit4 返回 warnings。")
    else:
        _add("GDUnit4", "FAIL", text[-3000:] if text else f"GDUnit4 返回码 {code}。")


def _print_report(json_mode: bool) -> None:
    if json_mode:
        print(json.dumps({"status": final_status, "checks": checks}, ensure_ascii=False, indent=2))
        return

    print("## Godot Quality Tools")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        detail = check["detail"].replace("\n", "<br>")
        print(f"| {check['name']} | {check['status']} | {detail} |")
    print("")
    print(f"结论：{final_status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 质量工具入口")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0")
    parser.add_argument("--godot", default="", help="Godot 可执行文件路径")
    parser.add_argument("--skip-gdtoolkit", action="store_true")
    parser.add_argument("--run-gdunit", action="store_true", help="启用可选的 GDUnit4 检查")
    parser.add_argument("--skip-gdunit", action="store_true")
    parser.add_argument("--gdunit-timeout", type=int, default=240)
    args = parser.parse_args()

    if not args.skip_gdtoolkit:
        _check_gdscript_toolkit()
    if args.run_gdunit and not args.skip_gdunit:
        _check_gdunit4(args)
    else:
        _add("GDUnit4", "PASS", "可选检查默认跳过；传入 --run-gdunit 可启用。")

    _print_report(args.json)
    return 1 if final_status == "FAIL" or (args.strict and final_status == "CONCERNS") else 0


if __name__ == "__main__":
    raise SystemExit(main())
