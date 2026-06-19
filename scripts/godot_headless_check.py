#!/usr/bin/env python3
"""Godot headless 静态/场景加载检查。

Web 导出成功不代表脚本可运行；Godot 有些 GDScript warning 会在场景加载时
按 error 处理。这个脚本用 headless 模式加载主场景几帧，并解析 Godot 输出。
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCENE = "res://scenes/Game.tscn"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from godot_locator import find_godot  # noqa: E402
import validate_data_configs  # noqa: E402

BLOCKING_PATTERNS = (
    "SCRIPT ERROR",
    "PARSE ERROR",
    "COMPILE ERROR",
    "ERROR: FAILED TO LOAD SCRIPT",
    "ERROR: FAILED TO INSTANTIATE",
    "INVALID ACCESS",
    "INVALID CALL",
)
IGNORED_PATTERNS = (
    "WARNING:",
    "trying to play a sample from a stream that cannot be sampled",
)


def _blocking_lines(text: str) -> list[str]:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text or "")
    lines = [line.strip() for line in clean.splitlines() if line.strip()]
    blocking: list[str] = []
    for line in lines:
        upper = line.upper()
        if any(pattern.upper() in upper for pattern in IGNORED_PATTERNS):
            continue
        if any(pattern in upper for pattern in BLOCKING_PATTERNS):
            blocking.append(line)
    return blocking


def _output_excerpt(text: str, limit: int = 12) -> list[str]:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text or "")
    lines = [line.strip() for line in clean.splitlines() if line.strip()]
    return lines[-limit:]


def _powershell_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _headless_command(godot: str, scene: str, frames: int) -> list[str]:
    if sys.platform == "win32":
        import shutil
        shell = shutil.which("powershell")
        if shell:
            ps_command = " ".join([
                f"& {_powershell_quote(godot)}",
                "--headless",
                "--path",
                _powershell_quote(str(PROJECT_ROOT)),
                "--scene",
                _powershell_quote(scene),
                "--quit-after",
                str(max(1, frames)),
            ])
            return [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_command]

    return [
        godot,
        "--headless",
        "--path",
        str(PROJECT_ROOT),
        "--scene",
        scene,
        "--quit-after",
        str(max(1, frames)),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot headless 场景加载检查")
    parser.add_argument("--godot", default="", help="Godot 可执行文件路径")
    parser.add_argument("--scene", default=DEFAULT_SCENE, help="要加载的场景路径")
    parser.add_argument("--frames", type=int, default=8, help="加载后运行帧数")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    data_status = validate_data_configs.validate()
    if data_status["status"] == "FAIL":
        if args.json:
            print(json.dumps({
                "status": "FAIL",
                "scene": args.scene,
                "godot": "",
                "return_code": 1,
                "return_code_failure": True,
                "blocking": data_status["errors"][:20],
            }, ensure_ascii=False, indent=2))
        else:
            print("## Godot Headless Check")
            print("")
            print("- Result: FAIL")
            print("")
            for item in data_status["errors"][:20]:
                print(f"- {item}")
        return 1

    godot = find_godot(args.godot)
    if not godot:
        result = {
            "status": "FAIL",
            "message": "未找到 Godot 可执行文件。请先运行 init.cmd 解包 tools/ 中的 portable Godot，或设置 GODOT4_PATH。",
        }
        print(json.dumps(result, ensure_ascii=False) if args.json else f"[FAIL] {result['message']}")
        return 1

    command = _headless_command(godot, args.scene, args.frames)
    with tempfile.NamedTemporaryFile("w+", encoding="utf-8", errors="replace", delete=True) as output_file:
        proc = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdout=output_file,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=90,
        )
        output_file.seek(0)
        output = output_file.read()
    blocking = _blocking_lines(output)
    return_code_failure = proc.returncode != 0
    if return_code_failure and not blocking:
        blocking = _output_excerpt(output)
    status = "FAIL" if return_code_failure or blocking else "PASS"
    payload = {
        "status": status,
        "scene": args.scene,
        "godot": godot,
        "return_code": proc.returncode,
        "return_code_failure": return_code_failure,
        "blocking": blocking[:20],
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print("## Godot Headless Check")
        print("")
        print(f"- Scene: {args.scene}")
        print(f"- Result: {status}")
        if return_code_failure:
            print(f"- Return code: {proc.returncode}")
        if blocking:
            print("")
            for item in blocking[:20]:
                print(f"- {item}")
    return 1 if status == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
