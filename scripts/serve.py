#!/usr/bin/env python3
"""
本地 HTTP 服务 — godot-v1 模板
专为 Godot Web 导出产物设计，处理必要的 MIME 类型和 COOP/COEP HTTP 头。

Godot Web export 要求：
- .wasm 文件必须返回 application/wasm
- .pck 文件返回 application/octet-stream
- SharedArrayBuffer（多线程）需要 COOP/COEP 头：
    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp
"""
import argparse
import json
import os
import socket
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_PORT = 8080
DEFAULT_DIR = str(Path(__file__).parent.parent / "html5")

EXTRA_MIME_TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
}


class GodotWebHandler(SimpleHTTPRequestHandler):

    _json_mode: bool = False

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def guess_type(self, path: str) -> str:
        for ext, mime in EXTRA_MIME_TYPES.items():
            if str(path).endswith(ext):
                return mime
        return super().guess_type(path)

    def log_message(self, fmt: str, *args) -> None:
        if not self._json_mode:
            super().log_message(fmt, *args)


def find_free_port(start: int) -> int | None:
    for port in range(start, 65535):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    return None


def is_port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--dir", default=DEFAULT_DIR)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    json_mode = args.json
    GodotWebHandler._json_mode = json_mode
    serve_dir = Path(args.dir)

    if not serve_dir.exists():
        msg = f"服务目录不存在：{serve_dir}，请先运行 python scripts/export_web.py"
        if json_mode:
            print(json.dumps({"status": "error", "message": msg}, ensure_ascii=False))
        else:
            print(f"[FAIL] {msg}")
        return 1

    port = args.port
    if is_port_in_use(port):
        free = find_free_port(port + 1)
        if free is None:
            print(json.dumps({"status": "error", "message": "no free port"}) if json_mode else "[FAIL] 无可用端口")
            return 1
        port = free

    os.chdir(serve_dir)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), GodotWebHandler)
    url = f"http://127.0.0.1:{port}"

    if json_mode:
        print(json.dumps({"status": "ready", "url": url, "port": port, "dir": str(serve_dir)}, ensure_ascii=False))
        sys.stdout.flush()
    else:
        print(f"[OK] Godot Web 预览：{url}")
        print("[INFO] 已设置 COOP/COEP 头（SharedArrayBuffer 支持）")
        print("[INFO] 按 Ctrl+C 停止")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        if not json_mode:
            print("\n[INFO] 已停止")

    return 0


if __name__ == "__main__":
    sys.exit(main())
