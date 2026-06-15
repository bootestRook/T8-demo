#!/usr/bin/env python3
"""Run Godot directly and collect viewport screenshots.

This is a fast native-runtime check for development loops. It does not replace
the Web/browser check used before delivery.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zlib
from datetime import datetime
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCREENSHOT_ROOT = PROJECT_ROOT / "reports" / "screenshots"
RUNNER_SCENE = "res://tests/runtime/RuntimeScreenshotRunner.tscn"
MAIN_SCENE = "res://scenes/Game.tscn"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from godot_runtime_log_check import (  # noqa: E402
    _blocking_lines,
    _crash_diagnostics,
    _is_windows_access_violation,
    _output_excerpt,
    _return_code_detail,
    find_godot,
)


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _parse_png(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("screenshot is not PNG")

    offset = 8
    width = height = bit_depth = color_type = 0
    idat: list[bytes] = []
    while offset < len(data):
        length = int.from_bytes(data[offset:offset + 4], "big")
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        if kind == b"IHDR":
            width = int.from_bytes(chunk[0:4], "big")
            height = int.from_bytes(chunk[4:8], "big")
            bit_depth = chunk[8]
            color_type = chunk[9]
        elif kind == b"IDAT":
            idat.append(chunk)
        elif kind == b"IEND":
            break
        offset += 12 + length

    if bit_depth != 8 or color_type not in {2, 6}:
        raise ValueError(f"unsupported PNG format bitDepth={bit_depth}, colorType={color_type}")

    bytes_per_pixel = 4 if color_type == 6 else 3
    stride = width * bytes_per_pixel
    raw = zlib.decompress(b"".join(idat))
    pixels = bytearray(height * stride)
    src = 0

    def paeth(a: int, b: int, c: int) -> int:
        p = a + b - c
        pa = abs(p - a)
        pb = abs(p - b)
        pc = abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        return b if pb <= pc else c

    for y in range(height):
        filter_type = raw[src]
        src += 1
        row_start = y * stride
        for x in range(stride):
            value = raw[src + x]
            left = pixels[row_start + x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            up = pixels[row_start + x - stride] if y > 0 else 0
            up_left = pixels[row_start + x - stride - bytes_per_pixel] if y > 0 and x >= bytes_per_pixel else 0
            if filter_type == 1:
                value += left
            elif filter_type == 2:
                value += up
            elif filter_type == 3:
                value += (left + up) // 2
            elif filter_type == 4:
                value += paeth(left, up, up_left)
            elif filter_type != 0:
                raise ValueError(f"unknown PNG filter: {filter_type}")
            pixels[row_start + x] = value & 0xFF
        src += stride

    return {"width": width, "height": height, "bytes_per_pixel": bytes_per_pixel, "pixels": pixels}


def _pixel_health_from_image(image: dict[str, Any]) -> tuple[bool, str]:
    total = image["width"] * image["height"]
    step = max(1, total // 5000)
    samples = non_transparent = non_dark = 0
    buckets: set[str] = set()
    bpp = image["bytes_per_pixel"]
    pixels = image["pixels"]
    for pixel in range(0, total, step):
        index = pixel * bpp
        r, g, b = pixels[index], pixels[index + 1], pixels[index + 2]
        a = pixels[index + 3] if bpp == 4 else 255
        samples += 1
        if a > 8:
            non_transparent += 1
        if a > 8 and r + g + b > 36:
            non_dark += 1
        buckets.add(f"{r // 32}-{g // 32}-{b // 32}-{a // 64}")

    transparent_ratio = non_transparent / max(1, samples)
    non_dark_ratio = non_dark / max(1, samples)
    healthy = transparent_ratio > 0.9 and non_dark_ratio > 0.08 and len(buckets) >= 4
    detail = f"非透明 {transparent_ratio * 100:.1f}%，非暗色 {non_dark_ratio * 100:.1f}%，色彩桶 {len(buckets)}。"
    return healthy, detail


def _is_starter_template() -> bool:
    concept = PROJECT_ROOT / "docs" / "game-concept.md"
    if not concept.exists():
        return False
    return "starter-template" in concept.read_text(encoding="utf-8", errors="ignore")


def _image_diff_ratio(before: dict[str, Any], after: dict[str, Any]) -> float:
    if before["width"] != after["width"] or before["height"] != after["height"]:
        return 1.0
    if before["bytes_per_pixel"] != after["bytes_per_pixel"]:
        return 1.0

    total = before["width"] * before["height"]
    step = max(1, total // 5000)
    changed = samples = 0
    bpp = before["bytes_per_pixel"]
    for pixel in range(0, total, step):
        index = pixel * bpp
        delta = 0
        for channel in range(bpp):
            delta += abs(before["pixels"][index + channel] - after["pixels"][index + channel])
        samples += 1
        if delta > 28:
            changed += 1
    return changed / max(1, samples)


def _run_command(command: list[str], timeout: int) -> tuple[int | None, bool, str]:
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
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            proc.kill()
            proc.wait(timeout=10)
        output_file.seek(0)
        output = output_file.read()
    return proc.returncode, timed_out, output


def _run_godot(godot: str, scene: str, output_dir: Path, timeout: int) -> tuple[int | None, bool, str]:
    command = [
        godot,
        "--path",
        str(PROJECT_ROOT),
        "--scene",
        RUNNER_SCENE,
        "--",
        "--scene",
        scene,
        "--screenshot-dir",
        str(output_dir),
    ]
    return _run_command(command, timeout)


def _build_report(godot: str, scene: str, output_dir: Path, return_code: int | None, timed_out: bool, output: str, transient: list[str]) -> dict[str, Any]:
    checks: list[dict[str, str]] = []

    def add(name: str, status: str, detail: str) -> None:
        checks.append({"name": name, "status": status, "detail": detail})

    blocking = _blocking_lines(output)
    if timed_out:
        blocking.append("Godot native screenshot check timed out.")
    if return_code and return_code != 0 and not blocking:
        blocking = [_return_code_detail(return_code), *_output_excerpt(output)]
    add("Godot 原生运行", "FAIL" if timed_out or blocking or (return_code and return_code != 0) else "PASS", "；".join(blocking[:16]) if blocking else "原生运行并退出正常。")

    screenshot_files = {
        label: output_dir / f"{label}.png"
        for label in ("ready", "running", "input-after")
    }
    screenshots = {label: _rel(path) for label, path in screenshot_files.items() if path.exists()}
    missing = [label for label, path in screenshot_files.items() if not path.exists()]
    add("截图产出", "FAIL" if missing else "PASS", "缺失：" + ",".join(missing) if missing else f"截图目录：{_rel(output_dir)}")

    images: dict[str, dict[str, Any]] = {}
    for label, path in screenshot_files.items():
        if not path.exists():
            continue
        try:
            images[label] = _parse_png(path)
            healthy, detail = _pixel_health_from_image(images[label])
            add(f"{label} 像素健康", "PASS" if healthy else "CONCERNS", detail)
        except Exception as exc:
            add(f"{label} 像素健康", "CONCERNS", str(exc))

    if "ready" in images and "input-after" in images:
        diff = _image_diff_ratio(images["ready"], images["input-after"])
        starter_template = _is_starter_template()
        status = "PASS" if starter_template or diff >= 0.002 else "CONCERNS"
        detail = "ready 到 input-after 变化 %.2f%%。" % (diff * 100.0)
        if starter_template:
            detail += " 空脚手架只验证截图链路，不要求输入改变画面。"
        add("输入后画面变化", status, detail)

    statuses = [item["status"] for item in checks]
    status = "FAIL" if "FAIL" in statuses else ("CONCERNS" if "CONCERNS" in statuses or transient else "PASS")
    return {
        "status": status,
        "scene": scene,
        "godot": godot,
        "return_code": return_code,
        "timed_out": timed_out,
        "transient_failures": transient,
        "crash_diagnostics": _crash_diagnostics() if transient or _is_windows_access_violation(return_code) else None,
        "screenshot_dir": _rel(output_dir),
        "screenshots": screenshots,
        "checks": checks,
        "excerpt": _output_excerpt(output),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 原生运行截图检查")
    parser.add_argument("--godot", default="", help="Godot 可执行文件路径")
    parser.add_argument("--scene", default=MAIN_SCENE, help="要加载和截图的主场景")
    parser.add_argument("--timeout", type=int, default=45, help="进程最大等待秒数")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    godot = find_godot(args.godot)
    if not godot:
        result = {"status": "FAIL", "message": "未找到 Godot 可执行文件。"}
        print(json.dumps(result, ensure_ascii=False) if args.json else f"[FAIL] {result['message']}")
        return 1
    if args.scene == RUNNER_SCENE:
        result = {
            "status": "FAIL",
            "message": "不能把 RuntimeScreenshotRunner 自身作为 --scene；请传入游戏主场景。",
        }
        print(json.dumps(result, ensure_ascii=False, indent=2) if args.json else f"[FAIL] {result['message']}")
        return 1

    output_dir = SCREENSHOT_ROOT / datetime.now().strftime("%Y%m%d-%H%M%S-native")
    output_dir.mkdir(parents=True, exist_ok=True)

    return_code, timed_out, output = _run_godot(godot, args.scene, output_dir, args.timeout)
    transient: list[str] = []
    if not timed_out and _is_windows_access_violation(return_code) and not _blocking_lines(output):
        transient.append(_return_code_detail(return_code))
        shutil.rmtree(output_dir, ignore_errors=True)
        output_dir.mkdir(parents=True, exist_ok=True)
        return_code, timed_out, output = _run_godot(godot, args.scene, output_dir, args.timeout)

    report = _build_report(godot, args.scene, output_dir, return_code, timed_out, output, transient)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("## Godot Native Screenshot Check")
        print(f"- Scene: {args.scene}")
        print(f"- Result: {report['status']}")
        print(f"- Screenshots: {report['screenshot_dir']}")
        for check in report["checks"]:
            print(f"- {check['name']}: {check['status']} - {check['detail']}")
    return 1 if report["status"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
