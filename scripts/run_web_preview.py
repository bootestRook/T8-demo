#!/usr/bin/env python3
"""
启动或复用 Godot Web 本地预览服务。

用法：
  python scripts/run_web_preview.py --open --json
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
HTML5_DIR = PROJECT_ROOT / "html5"
RUNTIME_DIR = PROJECT_ROOT / ".runtime"
STATE_FILE = RUNTIME_DIR / "web-preview.json"
LOG_FILE = RUNTIME_DIR / "web-preview.log"
HOST = "127.0.0.1"
DEFAULT_PORT = 8080


def _read_state() -> dict[str, Any] | None:
    if not STATE_FILE.exists():
        return None
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return None


def _write_state(state: dict[str, Any]) -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _ping(url: str, timeout: float = 1.5) -> bool:
	try:
		parsed = urllib.parse.urlparse(url)
		host = parsed.hostname or HOST
		port = parsed.port or DEFAULT_PORT
		check_url = urllib.parse.urlunparse((parsed.scheme or "http", f"{host}:{port}", "/index.html", "", "", ""))
		request = urllib.request.Request(check_url, headers={"Cache-Control": "no-cache"}, method="HEAD")
		with urllib.request.urlopen(request, timeout=timeout) as response:
			if response.status >= 500:
				return False
			return (
				response.headers.get("Cross-Origin-Opener-Policy") == "same-origin"
				and response.headers.get("Cross-Origin-Embedder-Policy") == "require-corp"
			)
	except Exception:
		return False


def _find_free_port(start: int) -> int:
    for port in range(start, 65535):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            try:
                sock.bind((HOST, port))
                return port
            except OSError:
                continue
    raise RuntimeError("未找到可用端口")


def _wait_until_ready(url: str, process: subprocess.Popen[bytes], seconds: float = 8.0) -> bool:
	deadline = time.time() + seconds
	while time.time() < deadline:
		if process.poll() is not None:
			return False
		if _ping(url):
			return True
		time.sleep(0.25)
	return False


def _open_url(url: str, enabled: bool) -> bool:
    if not enabled:
        return False
    try:
        return bool(webbrowser.open(url))
    except Exception:
        return False


def _start_server(port: int) -> tuple[subprocess.Popen[bytes], str]:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_FILE.open("ab")
    command = [
        sys.executable,
        str(PROJECT_ROOT / "scripts" / "serve.py"),
        "--port",
        str(port),
        "--dir",
        str(HTML5_DIR),
        "--json",
    ]
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    process = subprocess.Popen(
        command,
        cwd=PROJECT_ROOT,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=log,
        creationflags=creationflags,
        close_fds=True,
    )
    return process, f"http://{HOST}:{port}"


def _result(
    status: str,
    url: str = "",
    port: int | None = None,
    pid: int | None = None,
    reused: bool = False,
    opened: bool = False,
    open_attempted: bool = False,
    message: str = "",
) -> dict[str, Any]:
    return {
        "status": status,
        "url": url,
        "port": port,
        "pid": pid,
        "reused": reused,
        "opened": opened,
        "openAttempted": open_attempted,
        "logFile": str(LOG_FILE),
        "stateFile": str(STATE_FILE),
        "message": message,
    }


def _print(result: dict[str, Any], json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    if result["status"] == "ready":
        reused = "复用" if result.get("reused") else "启动"
        print(f"[OK] Godot Web 预览已{reused}：{result['url']}")
        print(f"[INFO] PID: {result.get('pid')}")
        print(f"[INFO] 日志：{result['logFile']}")
        if result.get("openAttempted") and not result.get("opened"):
            print("[WARN] 未能自动打开浏览器，请手动打开上面的地址。")
        print("[NEXT] 浏览器试玩后，直接回到 AI 对话框描述问题或下一步需求。")
        return

    if result["status"] == "starting":
        print(f"[WARN] 预览服务已启动但暂未响应：{result['url']}")
        print(f"[INFO] 日志：{result['logFile']}")
        return

    print(f"[FAIL] {result.get('message') or '预览服务启动失败'}")


def main() -> int:
    parser = argparse.ArgumentParser(description="启动或复用 Godot Web 本地预览服务")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--open", action="store_true", help="启动后尝试打开浏览器")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    args = parser.parse_args()

    if not (HTML5_DIR / "index.html").exists():
        result = _result("error", message="html5/index.html 不存在，请先运行 python scripts/export_web.py --json")
        _print(result, args.json)
        return 1

    state = _read_state()
    if state and state.get("url") and _ping(str(state["url"])):
        opened = _open_url(str(state["url"]), args.open)
        result = _result(
            "ready",
            url=str(state["url"]),
            port=state.get("port"),
            pid=state.get("pid"),
            reused=True,
            opened=opened,
            open_attempted=args.open,
            message="预览服务已存在并可访问。",
        )
        _print(result, args.json)
        return 0

    try:
        port = _find_free_port(args.port)
        process, url = _start_server(port)
    except Exception as exc:
        result = _result("error", message=str(exc))
        _print(result, args.json)
        return 1

    state = {
        "pid": process.pid,
        "url": url,
        "port": port,
        "logFile": str(LOG_FILE),
        "startedAt": datetime.now().isoformat(timespec="seconds"),
    }
    _write_state(state)

    ready = _wait_until_ready(url, process)
    opened = _open_url(url, args.open) if ready else False
    result = _result(
        "ready" if ready else "starting",
        url=url,
        port=port,
        pid=process.pid,
        reused=False,
        opened=opened,
        open_attempted=args.open,
        message="预览服务已启动。" if ready else "预览服务正在启动，稍后重试或查看日志。",
    )
    _print(result, args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
