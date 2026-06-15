#!/usr/bin/env python3
"""Godot 正常运行日志检查。

headless 场景加载能抓语法和启动期错误，但不能覆盖用户在 Godot 编辑器
按 F5 后看到的真实项目进程日志。这个脚本用非 headless 模式运行主场景
数秒，捕获 console 输出并把常见运行时错误纳入 gate。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GODOT_ENV_KEY = "GODOT4_PATH"
DEFAULT_SCENE = "res://scenes/Game.tscn"

BLOCKING_PATTERNS = (
    "SCRIPT ERROR",
    "PARSE ERROR",
    "COMPILE ERROR",
    "ERROR: FAILED TO LOAD SCRIPT",
    "ERROR: FAILED TO LOAD RESOURCE",
    "ERROR: FAILED TO INSTANTIATE",
    "ERROR: ERROR LOADING RESOURCE",
    "ERROR: CANNOT OPEN FILE",
    "INVALID ACCESS",
    "INVALID CALL",
    "NONEXISTENT FUNCTION",
    "ATTEMPT TO CALL FUNCTION",
)

IGNORED_PATTERNS = (
    "WARNING:",
    "trying to play a sample from a stream that cannot be sampled",
)


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


def find_godot(hint: str = "") -> str | None:
    candidates: list[str] = []
    if hint:
        candidates.append(hint)
    env = os.environ.get(GODOT_ENV_KEY)
    if env:
        candidates.append(env)
    for root in [PROJECT_ROOT / "tools" / "godot", PROJECT_ROOT / "tools"]:
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


def _clean_lines(text: str) -> list[str]:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text or "")
    return [line.strip() for line in clean.splitlines() if line.strip()]


def _blocking_lines(text: str) -> list[str]:
    blocking: list[str] = []
    for line in _clean_lines(text):
        upper = line.upper()
        if any(pattern.upper() in upper for pattern in IGNORED_PATTERNS):
            continue
        if any(pattern in upper for pattern in BLOCKING_PATTERNS):
            blocking.append(line)
    return blocking


def _output_excerpt(text: str, limit: int = 16) -> list[str]:
    return _clean_lines(text)[-limit:]


def _runtime_command(godot: str, scene: str, seconds: int) -> list[str]:
    return [
        godot,
        "--path",
        str(PROJECT_ROOT),
        "--scene",
        scene,
        "--quit-after",
        str(max(1, seconds)),
    ]


def _is_windows_access_violation(code: int | None) -> bool:
    return sys.platform == "win32" and code == 0xC0000005


def _return_code_detail(code: int | None) -> str:
    if code is None:
        return "Godot process did not report an exit code."
    if _is_windows_access_violation(code):
        return "Godot exited with code 3221225477 (0xC0000005 access violation)."
    return f"Godot exited with code {code}."


def _run_runtime_command(command: list[str], timeout: int, seconds: int) -> tuple[int | None, bool, str]:
    timed_out = False
    with tempfile.NamedTemporaryFile("w+", encoding="utf-8", errors="replace", delete=True) as output_file:
        proc = subprocess.Popen(
            command,
            cwd=PROJECT_ROOT,
            stdout=output_file,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            proc.wait(timeout=max(timeout, seconds + 10))
        except subprocess.TimeoutExpired:
            timed_out = True
            proc.kill()
            proc.wait(timeout=10)
        output_file.seek(0)
        output = output_file.read()
    return proc.returncode, timed_out, output


def _crash_diagnostics() -> dict[str, object] | None:
    script = PROJECT_ROOT / "scripts" / "godot_crash_diagnostics.py"
    if sys.platform != "win32" or not script.exists():
        return None
    try:
        result = subprocess.run(
            [sys.executable, str(script), "--json"],
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=25,
            check=False,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None
        parsed = json.loads(result.stdout)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 正常运行日志检查")
    parser.add_argument("--godot", default="", help="Godot 可执行文件路径")
    parser.add_argument("--scene", default=DEFAULT_SCENE, help="要运行的场景路径")
    parser.add_argument("--seconds", type=int, default=8, help="正常运行秒数")
    parser.add_argument("--timeout", type=int, default=30, help="进程最大等待秒数")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    godot = find_godot(args.godot)
    if not godot:
        result = {
            "status": "FAIL",
            "message": "未找到 Godot 可执行文件。请先运行 init.cmd 解包 tools/ 中的 portable Godot，或设置 GODOT4_PATH。",
        }
        print(json.dumps(result, ensure_ascii=False) if args.json else f"[FAIL] {result['message']}")
        return 1

    command = _runtime_command(godot, args.scene, args.seconds)
    return_code, timed_out, output = _run_runtime_command(
        command,
        args.timeout,
        args.seconds,
    )

    blocking = _blocking_lines(output)
    transient_failures: list[str] = []
    if not timed_out and not blocking and _is_windows_access_violation(return_code):
        transient_failures.append(_return_code_detail(return_code))
        return_code, timed_out, output = _run_runtime_command(
            command,
            args.timeout,
            args.seconds,
        )
        blocking = _blocking_lines(output)

    return_code_failure = bool(return_code and return_code != 0)
    if timed_out:
        blocking.append(f"Godot runtime did not exit within {max(args.timeout, args.seconds + 10)} seconds.")
    elif return_code_failure and not blocking:
        blocking = [_return_code_detail(return_code), *_output_excerpt(output)]

    status = "FAIL" if timed_out or return_code_failure or blocking else "PASS"
    crash_diagnostics = _crash_diagnostics() if transient_failures or _is_windows_access_violation(return_code) else None
    payload = {
        "status": status,
        "scene": args.scene,
        "godot": godot,
        "seconds": args.seconds,
        "return_code": return_code,
        "timed_out": timed_out,
        "return_code_failure": return_code_failure,
        "transient_failures": transient_failures,
        "crash_diagnostics": crash_diagnostics,
        "blocking": blocking[:24],
        "excerpt": _output_excerpt(output),
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print("## Godot Runtime Log Check")
        print("")
        print(f"- Scene: {args.scene}")
        print(f"- Result: {status}")
        if transient_failures:
            print(f"- Retried transient failure: {'；'.join(transient_failures)}")
        if return_code_failure:
            print(f"- Return code: {return_code}")
        if timed_out:
            print("- Timeout: yes")
        if blocking:
            print("")
            for item in blocking[:24]:
                print(f"- {item}")
    return 1 if status == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
