#!/usr/bin/env python3
"""
停止由 run_web_preview.py 启动的 Godot Web 本地预览服务。
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = PROJECT_ROOT / ".runtime" / "web-preview.json"


def _read_state() -> dict[str, Any] | None:
    if not STATE_FILE.exists():
        return None
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return None


def _ping(url: str, timeout: float = 0.6) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.status < 500
    except Exception:
        return False


def _stop_pid(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        if sys.platform == "win32":
            result = subprocess.run(
                ["taskkill", "/PID", str(pid), "/T", "/F"],
                capture_output=True,
                text=True,
                timeout=8,
            )
            return result.returncode == 0
        os.kill(pid, signal.SIGTERM)
        return True
    except Exception:
        return False


def _print(result: dict[str, Any], json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif result["status"] == "ok":
        print(f"[OK] {result['message']}")
    else:
        print(f"[WARN] {result['message']}")


def main() -> int:
    parser = argparse.ArgumentParser(description="停止 Godot Web 本地预览服务")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    state = _read_state()
    if not state:
        _print({"status": "ok", "message": "没有找到正在管理的预览服务。"}, args.json)
        return 0

    pid = int(state.get("pid") or 0)
    url = str(state.get("url") or "")
    stopped = _stop_pid(pid)

    try:
        STATE_FILE.unlink(missing_ok=True)
    except Exception:
        pass

    still_running = bool(url and _ping(url))
    status = "warn" if still_running else "ok"
    message = "预览服务已停止。" if stopped and not still_running else "已清理状态文件；服务可能已经退出或由其他进程占用。"
    _print({"status": status, "message": message, "pid": pid, "url": url}, args.json)
    return 0 if status == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
