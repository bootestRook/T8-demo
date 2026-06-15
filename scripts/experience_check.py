#!/usr/bin/env python3
"""
Godot Web 体验检查。

检查顺序：
1. 运行时源码卫生扫描。
2. Godot Web 导出。
3. 启动或复用本地预览。
4. 如 agent-browser 可用，检查浏览器控制台、canvas 尺寸和基础交互。
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zlib
from datetime import datetime
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
AGENT_BROWSER_ENV_KEY = "AGENT_BROWSER_PATH"
AGENT_BROWSER_SESSION = f"experience-check-{os.getpid()}"
KEEP_BROWSER_SESSION = False
BROWSER_BACKEND = "auto"
DESKTOP_VIEWPORT = (1280, 720)
MOBILE_VIEWPORT = (390, 844)
HTML5_INDEX = PROJECT_ROOT / "html5" / "index.html"
SCREENSHOT_ROOT = PROJECT_ROOT / "reports" / "screenshots"
SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
RUNTIME_SCAN_PATHS = [
    PROJECT_ROOT / "project.godot",
    PROJECT_ROOT / "export_presets.cfg",
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "scenes",
]
TEMPLATE_TEXT_PATTERNS = ["TODO", "Lorem ipsum", "placeholder", "Phaser Vibe Prototype"]

checks: list[dict[str, str]] = []
final_status = "PASS"
cleanup_notes: list[str] = []
cleanup_done = False
cleanup_allowed = False
agent_browser_baseline_pids: set[int] = set()
screenshot_dir = SCREENSHOT_ROOT / datetime.now().strftime("%Y%m%d-%H%M%S")
screenshots: dict[str, str] = {}


def _capture_report_state() -> tuple[list[dict[str, str]], str, dict[str, str]]:
    return ([dict(item) for item in checks], final_status, dict(screenshots))


def _restore_report_state(snapshot: tuple[list[dict[str, str]], str, dict[str, str]]) -> None:
    global final_status
    saved_checks, saved_status, saved_screenshots = snapshot
    checks[:] = saved_checks
    screenshots.clear()
    screenshots.update(saved_screenshots)
    final_status = saved_status


def _run(command: list[str], timeout: int = 120) -> tuple[bool, str]:
    process: subprocess.Popen[str] | None = None
    try:
        process = subprocess.Popen(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        output, _ = process.communicate(timeout=timeout)
        return process.returncode == 0, (output or "").strip()
    except subprocess.TimeoutExpired:
        if process is not None:
            if sys.platform == "win32":
                subprocess.run(
                    ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            else:
                process.kill()
        return False, f"Command '{' '.join(command)}' timed out after {timeout} seconds"
    except Exception as exc:
        return False, str(exc)


def _add_check(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _parse_json(text: str) -> dict[str, Any] | None:
    try:
        return json.loads(text)
    except Exception:
        return None


def _runtime_source_files() -> list[Path]:
    files: list[Path] = []
    for path in RUNTIME_SCAN_PATHS:
        if not path.exists():
            continue
        if path.is_file() and path.suffix in SOURCE_EXTENSIONS:
            files.append(path)
            continue
        if path.is_dir():
            for file in path.rglob("*"):
                if file.is_file() and file.suffix in SOURCE_EXTENSIONS:
                    files.append(file)
    return files


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _check_runtime_source_hygiene() -> None:
    template_hits: list[str] = []
    reference_hits: list[str] = []

    for file in _runtime_source_files():
        text = file.read_text(encoding="utf-8", errors="ignore")
        lower = text.lower()
        for pattern in TEMPLATE_TEXT_PATTERNS:
            if pattern.lower() in lower:
                template_hits.append(f"{pattern} @ {_rel(file)}")

        for index, line in enumerate(text.splitlines(), start=1):
            line_lower = line.lower()
            if "references/" not in line_lower and "res://references" not in line_lower:
                continue
            is_runtime_load = (
                "load(" in line_lower
                or "preload(" in line_lower
                or "resourceloader" in line_lower
                or "ext_resource" in line_lower
            )
            if is_runtime_load:
                reference_hits.append(f"{_rel(file)}:{index}")

    _add_check(
        "模板文案扫描",
        "CONCERNS" if template_hits else "PASS",
        "；".join(template_hits) if template_hits else "运行时入口未发现常见模板感文案。",
    )
    _add_check(
        "运行时 references 加载",
        "FAIL" if reference_hits else "PASS",
        "；".join(reference_hits) if reference_hits else "运行时入口未直接加载 references/。",
    )


def _is_starter_template() -> bool:
    concept = PROJECT_ROOT / "docs" / "game-concept.md"
    if not concept.exists():
        return False
    return "starter-template" in concept.read_text(encoding="utf-8", errors="ignore")


def _check_art_pipeline_handoff() -> None:
    script = PROJECT_ROOT / "scripts" / "art_pipeline_review.py"
    if not script.exists():
        _add_check("美术管线", "CONCERNS", "未找到 scripts/art_pipeline_review.py，跳过风格候选落地检查。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=60)
    parsed = _parse_json(text)
    if not parsed:
        _add_check("美术管线", "CONCERNS" if ok else "FAIL", text or "无法解析美术管线审查输出。")
        return
    status = str(parsed.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in parsed.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    _add_check(
        "美术管线",
        status,
        "；".join(issues) if issues else "风格候选、生成命令和运行时素材落地检查通过。",
    )


def _agent_command() -> list[str] | None:
    candidates: list[str] = []
    env_path = os.environ.get(AGENT_BROWSER_ENV_KEY)
    if env_path:
        candidates.append(env_path)

    tools_agent = PROJECT_ROOT / "tools" / "agent-browser"
    if sys.platform == "win32":
        candidates += [
            str(tools_agent / "agent-browser.exe"),
            str(tools_agent / "agent-browser.cmd"),
            str(tools_agent / "agent-browser.ps1"),
        ]
    else:
        candidates += [
            str(tools_agent / "agent-browser"),
            str(tools_agent / "bin" / "agent-browser"),
        ]
    candidates.append("agent-browser")

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if not resolved:
            continue
        if sys.platform == "win32" and str(resolved).lower().endswith(".ps1"):
            return [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(resolved),
                "--session",
                AGENT_BROWSER_SESSION,
            ]
        return [str(resolved), "--session", AGENT_BROWSER_SESSION]
    return None


def _agent(args: list[str], timeout: int = 30) -> tuple[bool, str]:
    base = _agent_command()
    if not base:
        return False, "未找到 agent-browser"
    return _run(base + args, timeout=timeout)


def _agent_browser_chrome_pids() -> set[int]:
    if sys.platform != "win32":
        return set()
    command = [
        "powershell",
        "-NoProfile",
        "-Command",
        (
            "$ErrorActionPreference='SilentlyContinue';"
            "$items = Get-CimInstance Win32_Process | "
            "Where-Object { $_.Name -eq 'chrome.exe' -and $_.CommandLine -match '\\.agent-browser\\\\browsers\\\\chrome-' } | "
            "Select-Object -ExpandProperty ProcessId;"
            "$items | ConvertTo-Json -Compress"
        ),
    ]
    ok, text = _run(command, timeout=10)
    if not ok or not text:
        return set()
    try:
        parsed = json.loads(text)
    except Exception:
        return set()
    if isinstance(parsed, int):
        return {parsed}
    if isinstance(parsed, list):
        return {int(item) for item in parsed if isinstance(item, int)}
    return set()


def _taskkill(pid: int) -> bool:
    if sys.platform != "win32" or pid <= 0:
        return False
    try:
        result = subprocess.run(
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            cwd=PROJECT_ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
            check=False,
        )
        return result.returncode == 0
    except Exception:
        return False


def _cleanup_agent_session() -> None:
    global cleanup_done
    if cleanup_done:
        return
    cleanup_done = True
    if not cleanup_allowed or KEEP_BROWSER_SESSION or _agent_command() is None:
        return
    ok, text = _agent(["close"], timeout=20)
    if not ok:
        cleanup_notes.append(text or "agent-browser close 失败。")
    if sys.platform != "win32":
        return
    for _ in range(10):
        remaining = _agent_browser_chrome_pids() - agent_browser_baseline_pids
        if not remaining:
            return
        time.sleep(0.25)
    remaining = _agent_browser_chrome_pids() - agent_browser_baseline_pids
    killed = [pid for pid in sorted(remaining) if _taskkill(pid)]
    if killed:
        cleanup_notes.append("已兜底关闭本次自动试玩残留的 Chrome for Testing 进程：" + ",".join(str(pid) for pid in killed))


def _agent_available() -> tuple[bool, str]:
	if _agent_command() is None:
		return False, "未找到 agent-browser 命令。"
	ok, text = _agent(["--version"], timeout=10)
	return ok, text or "agent-browser --version 无输出。"


def _agent_eval(expression: str) -> dict[str, Any] | None:
    encoded = base64.b64encode(expression.encode("utf-8")).decode("ascii")
    ok, text = _agent(["eval", "-b", encoded], timeout=20)
    if not ok:
        return None
    parsed: Any
    try:
        parsed = json.loads(text)
        if isinstance(parsed, str):
            parsed = json.loads(parsed)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        return None


def _agent_page_errors(clear: bool = False) -> tuple[bool, list[str], str]:
    command = ["errors", "--json"]
    if clear:
        command.append("--clear")
    ok, text = _agent(command, timeout=15)
    if not ok:
        return False, [], text
    try:
        payload = json.loads(text)
    except Exception:
        return False, [], text

    raw_errors = ((payload.get("data") or {}).get("errors")) if isinstance(payload, dict) else None
    if not isinstance(raw_errors, list):
        return True, [], ""

    errors: list[str] = []
    for item in raw_errors:
        if not isinstance(item, dict):
            continue
        message = str(item.get("text") or "").strip()
        if message:
            errors.append(message)
    return True, errors, ""


def _blocking_console_errors(console_text: str) -> list[str]:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", console_text or "")
    blocking: list[str] = []
    for line in clean.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        upper = stripped.upper()
        if "WARNING:" in upper:
            continue
        if any(token in upper for token in ("SCRIPT ERROR", "PARSE ERROR", "ERROR:", "UNCAUGHT")):
            blocking.append(stripped)
    return blocking


def _check_canvas(viewport: tuple[int, int]) -> tuple[bool, str]:
    width, height = viewport
    ok, text = _agent(["set", "viewport", str(width), str(height)])
    if not ok:
        return False, f"设置 viewport 失败：{text}"
    for _ in range(2):
        _agent(["reload"], timeout=20)
        _agent(["wait", "1200"], timeout=10)

        result = _agent_eval(
            "(() => {"
            "const c=document.querySelector('canvas');"
            "if(!c)return JSON.stringify({ok:false,reason:'missing canvas'});"
            "const r=c.getBoundingClientRect();"
            "return JSON.stringify({ok:true,width:c.width,height:c.height,clientWidth:Math.round(r.width),clientHeight:Math.round(r.height)});"
            "})()"
        )
        if result and result.get("ok"):
            return True, f"逻辑 {result['width']}x{result['height']}，显示 {result['clientWidth']}x{result['clientHeight']}。"
    return False, str((result or {}).get("reason") if isinstance(result, dict) else "无法读取 canvas")


def _parse_png(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("截图不是 PNG")

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
        raise ValueError(f"暂不支持 PNG 格式 bitDepth={bit_depth}, colorType={color_type}")

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
                raise ValueError(f"未知 PNG filter：{filter_type}")
            pixels[row_start + x] = value & 0xFF
        src += stride

    return {"width": width, "height": height, "bytes_per_pixel": bytes_per_pixel, "pixels": pixels}


def _record_screenshot(source: Path, label: str) -> str:
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    safe_label = re.sub(r"[^A-Za-z0-9_\-]+", "-", label).strip("-") or "screen"
    index = len(screenshots) + 1
    target = screenshot_dir / f"{index:02d}-{safe_label}.png"
    shutil.copy2(source, target)
    rel = target.relative_to(PROJECT_ROOT).as_posix()
    screenshots[label] = rel
    return rel


def _screenshot_image(label: str | None = None) -> dict[str, Any]:
    ok, text = _agent(["screenshot"], timeout=30)
    if not ok:
        raise RuntimeError(text)
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text)
    match = re.search(r"saved to\s+(.+?\.png)", clean, re.IGNORECASE)
    if not match:
        raise RuntimeError("无法定位截图文件")
    path = Path(match.group(1))
    image = _parse_png(path)
    if label:
        image["screenshot_path"] = _record_screenshot(path, label)
    return image


def _image_diff_ratio(before: dict[str, Any], after: dict[str, Any]) -> float:
    if before["width"] != after["width"] or before["height"] != after["height"]:
        return 1.0
    if before["bytes_per_pixel"] != after["bytes_per_pixel"]:
        return 1.0

    total = before["width"] * before["height"]
    step = max(1, total // 5000)
    changed = samples = 0
    bpp = before["bytes_per_pixel"]
    before_pixels = before["pixels"]
    after_pixels = after["pixels"]
    for pixel in range(0, total, step):
        index = pixel * bpp
        delta = 0
        for channel in range(bpp):
            delta += abs(before_pixels[index + channel] - after_pixels[index + channel])
        samples += 1
        if delta > 28:
            changed += 1
    return changed / max(1, samples)


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


def _pixel_health() -> tuple[bool, str]:
    return _pixel_health_from_image(_screenshot_image())


def _playwright_screenshot(page: Any, label: str | None = None) -> dict[str, Any]:
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    safe_label = re.sub(r"[^A-Za-z0-9_\-]+", "-", label or "screen").strip("-") or "screen"
    index = len(screenshots) + 1
    target = screenshot_dir / f"{index:02d}-{safe_label}.png"
    page.screenshot(path=str(target), full_page=False)
    image = _parse_png(target)
    if label:
        screenshots[label] = target.relative_to(PROJECT_ROOT).as_posix()
    return image


def _playwright_canvas_detail(page: Any) -> tuple[bool, str]:
    result = page.evaluate(
        """() => {
            const c = document.querySelector('canvas');
            if (!c) return {ok:false, reason:'missing canvas'};
            const r = c.getBoundingClientRect();
            return {
                ok: true,
                width: c.width,
                height: c.height,
                clientWidth: Math.round(r.width),
                clientHeight: Math.round(r.height)
            };
        }"""
    )
    if isinstance(result, dict) and result.get("ok"):
        return True, f"逻辑 {result['width']}x{result['height']}，显示 {result['clientWidth']}x{result['clientHeight']}。"
    reason = result.get("reason") if isinstance(result, dict) else "无法读取 canvas"
    return False, str(reason)


def _check_browser_runtime_playwright(url: str, report_failures: bool = True) -> bool:
    try:
        from playwright.sync_api import sync_playwright  # type: ignore
    except Exception as exc:
        if report_failures:
            _add_check("浏览器后端", "CONCERNS", f"Playwright 不可用：{exc}")
        return False

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": DESKTOP_VIEWPORT[0], "height": DESKTOP_VIEWPORT[1]})
            console_messages: list[str] = []
            page_errors: list[str] = []
            page.on("console", lambda message: console_messages.append(message.text))
            page.on("pageerror", lambda error: page_errors.append(str(error)))
            try:
                page.goto(url, wait_until="load", timeout=45000)
                page.wait_for_timeout(1500)

                _add_check("浏览器后端", "PASS", "使用 Playwright Python。")

                desktop_ok, desktop_detail = _playwright_canvas_detail(page)
                _add_check("桌面 canvas", "PASS" if desktop_ok else "FAIL", desktop_detail)
                before_click: dict[str, Any] | None = None
                if desktop_ok:
                    try:
                        before_click = _playwright_screenshot(page, "ready")
                        healthy, detail = _pixel_health_from_image(before_click)
                        _add_check("桌面像素健康", "PASS" if healthy else "CONCERNS", detail)
                    except Exception as exc:
                        _add_check("桌面像素健康", "CONCERNS", str(exc))

                starter_template = _is_starter_template()
                try:
                    page.locator("canvas").click(timeout=10000)
                    page.wait_for_timeout(800)
                    after_click = _playwright_screenshot(page, "running")
                    diff_ratio = _image_diff_ratio(before_click, after_click) if before_click else 1.0
                    status = "PASS" if starter_template or diff_ratio >= 0.002 else "FAIL"
                    detail = "点击 canvas 后画面变化 %.2f%%。" % (diff_ratio * 100.0)
                    if starter_template:
                        detail += " 空脚手架不要求点击进入玩法。"
                    elif status == "FAIL":
                        detail += " 可能没有进入 PLAYING。"
                    _add_check("点击开始", status, detail)
                except Exception as exc:
                    _add_check("点击开始", "FAIL", str(exc))

                for label, key_name in [("方向键输入", "ArrowRight"), ("WASD 输入", "d")]:
                    try:
                        page.keyboard.press(key_name)
                        page.wait_for_timeout(400)
                        detail = "输入 %s 后未检测到 page errors。" % key_name
                        _add_check(label, "FAIL" if page_errors else "PASS", "；".join(page_errors[:4]) if page_errors else detail)
                    except Exception as exc:
                        _add_check(label, "CONCERNS", str(exc))

                try:
                    before_sequence = _playwright_screenshot(page, "input-before")
                    for key_name in ["ArrowRight", "ArrowLeft", "w", "a", "Space", "q", "r"]:
                        page.keyboard.press(key_name)
                        page.wait_for_timeout(250)
                    after_sequence = _playwright_screenshot(page, "input-after")
                    diff_ratio = _image_diff_ratio(before_sequence, after_sequence)
                    status = "PASS" if starter_template or diff_ratio >= 0.002 else "CONCERNS"
                    detail = "连续输入后画面变化 %.2f%%，未检测到 page errors。" % (diff_ratio * 100.0)
                    if starter_template:
                        detail += " 空脚手架只验证输入无报错，不要求玩法画面变化。"
                    elif status == "CONCERNS":
                        detail += " 这只是 smoke test，复杂玩法仍需要定制 E2E 脚本。"
                    _add_check("通用输入链路探针", status, detail)
                except Exception as exc:
                    _add_check("通用输入链路探针", "CONCERNS", str(exc))

                page.set_viewport_size({"width": MOBILE_VIEWPORT[0], "height": MOBILE_VIEWPORT[1]})
                page.reload(wait_until="load", timeout=30000)
                page.wait_for_timeout(1200)
                mobile_ok, mobile_detail = _playwright_canvas_detail(page)
                _add_check("窄屏 canvas", "PASS" if mobile_ok else "FAIL", mobile_detail)
                if mobile_ok:
                    try:
                        mobile_image = _playwright_screenshot(page, "mobile")
                        healthy, detail = _pixel_health_from_image(mobile_image)
                        _add_check("窄屏像素健康", "PASS" if healthy else "CONCERNS", detail)
                    except Exception as exc:
                        _add_check("窄屏像素健康", "CONCERNS", str(exc))

                _add_check(
                    "控制台运行时错误",
                    "FAIL" if page_errors else "PASS",
                    "；".join(page_errors[:4]) if page_errors else "未检测到 page errors。",
                )
                blocking = _blocking_console_errors("\n".join(console_messages))
                _add_check(
                    "Godot 控制台错误",
                    "FAIL" if blocking else "PASS",
                    "；".join(blocking[:8]) if blocking else "未检测到 SCRIPT ERROR / Parse Error / ERROR。",
                )
            finally:
                browser.close()
        return True
    except Exception as exc:
        if report_failures:
            _add_check("浏览器后端", "CONCERNS", f"Playwright 运行失败：{exc}")
        return False


def _check_browser_runtime_agent(url: str) -> bool:
    agent_ok, agent_detail = _agent_available()
    if not agent_ok:
        _add_check("浏览器运行时", "CONCERNS", f"agent-browser 不可用，已跳过 canvas/控制台自动检查：{agent_detail}")
        return False

    _add_check("浏览器后端", "PASS", "使用 agent-browser。")

    _agent(["console", "--clear"], timeout=10)
    _agent_page_errors(clear=True)
    ok = False
    text = ""
    for _ in range(2):
        ok, text = _agent(["open", url], timeout=45)
        if ok:
            break
        _agent(["wait", "1000"], timeout=10)
    if not ok:
        _add_check("浏览器运行时", "CONCERNS", f"agent-browser 打开失败：{text}")
        return False
    _agent(["wait", "1500"], timeout=10)

    ok, errors, detail = _agent_page_errors()
    if ok:
        _add_check("控制台运行时错误", "FAIL" if errors else "PASS", "；".join(errors[:4]) if errors else "未检测到 page errors。")
    else:
        _add_check("控制台运行时错误", "CONCERNS", detail)

    ok, console = _agent(["console"], timeout=15)
    if ok:
        blocking = _blocking_console_errors(console)
        _add_check(
            "Godot 控制台错误",
            "FAIL" if blocking else "PASS",
            "；".join(blocking[:8]) if blocking else "未检测到 SCRIPT ERROR / Parse Error / ERROR。",
        )
    else:
        _add_check("Godot 控制台错误", "CONCERNS", console)

    desktop_ok, desktop_detail = _check_canvas(DESKTOP_VIEWPORT)
    _add_check("桌面 canvas", "PASS" if desktop_ok else "FAIL", desktop_detail)
    before_click: dict[str, Any] | None = None
    if desktop_ok:
        try:
            before_click = _screenshot_image("ready")
            healthy, detail = _pixel_health_from_image(before_click)
            _add_check("桌面像素健康", "PASS" if healthy else "CONCERNS", detail)
        except Exception as exc:
            _add_check("桌面像素健康", "CONCERNS", str(exc))

    starter_template = _is_starter_template()

    ok, text = _agent(["click", "canvas"], timeout=10)
    if ok:
        _agent(["wait", "800"], timeout=10)
        errors_ok, errors, error_detail = _agent_page_errors()
        if errors_ok and errors:
            _add_check("点击开始", "FAIL", "；".join(errors[:4]))
        elif not errors_ok:
            _add_check("点击开始", "CONCERNS", error_detail)
        else:
            try:
                after_click = _screenshot_image("running")
                diff_ratio = _image_diff_ratio(before_click, after_click) if before_click else 1.0
                status = "PASS" if starter_template or diff_ratio >= 0.002 else "FAIL"
                detail = "点击 canvas 后画面变化 %.2f%%。" % (diff_ratio * 100.0)
                if starter_template:
                    detail += " 空脚手架不要求点击进入玩法。"
                elif status == "FAIL":
                    detail += " 可能没有进入 PLAYING。"
                _add_check("点击开始", status, detail)
            except Exception as exc:
                _add_check("点击开始", "CONCERNS", f"点击后未检测到 page errors，但无法比对截图：{exc}")
    else:
        _add_check("点击开始", "FAIL", text)

    key_checks = [
        ("方向键输入", ["press", "ArrowRight"], "ArrowRight"),
        ("WASD 输入", ["keyboard", "type", "d"], "D"),
    ]
    for label, command, key_name in key_checks:
        ok, text = _agent(command, timeout=10)
        if ok:
            _agent(["wait", "400"], timeout=10)
            errors_ok, errors, error_detail = _agent_page_errors()
            if not errors_ok:
                _add_check(label, "CONCERNS", error_detail)
                continue
            detail = ("；".join(errors[:4])) if errors else "输入 %s 后未检测到 page errors。" % key_name
            _add_check(label, "FAIL" if errors else "PASS", detail)
        else:
            _add_check(label, "CONCERNS", text)

    try:
        before_sequence = _screenshot_image("input-before")
        sequence = [
            ["press", "ArrowRight"],
            ["press", "ArrowLeft"],
            ["keyboard", "type", "wa"],
            ["click", "canvas"],
            ["press", "Space"],
            ["keyboard", "type", "q"],
            ["keyboard", "type", "r"],
        ]
        failures: list[str] = []
        for command in sequence:
            ok, text = _agent(command, timeout=10)
            if not ok:
                failures.append(" ".join(command) + f": {text}")
            _agent(["wait", "250"], timeout=10)
        errors_ok, errors, error_detail = _agent_page_errors()
        if errors_ok and errors:
            failures.extend(errors[:3])
        elif not errors_ok:
            failures.append(error_detail)
        after_sequence = _screenshot_image("input-after")
        diff_ratio = _image_diff_ratio(before_sequence, after_sequence)
        if failures:
            _add_check("通用输入链路探针", "FAIL", "；".join(failures[:6]))
        else:
            status = "PASS" if starter_template or diff_ratio >= 0.002 else "CONCERNS"
            detail = "连续输入后画面变化 %.2f%%，未检测到 page errors。" % (diff_ratio * 100.0)
            if starter_template:
                detail += " 空脚手架只验证输入无报错，不要求玩法画面变化。"
            elif status == "CONCERNS":
                detail += " 这只是 smoke test，复杂玩法仍需要定制 E2E 脚本。"
            _add_check("通用输入链路探针", status, detail)
    except Exception as exc:
        _add_check("通用输入链路探针", "CONCERNS", str(exc))

    mobile_ok, mobile_detail = _check_canvas(MOBILE_VIEWPORT)
    _add_check("窄屏 canvas", "PASS" if mobile_ok else "FAIL", mobile_detail)
    if mobile_ok:
        try:
            mobile_image = _screenshot_image("mobile")
            healthy, detail = _pixel_health_from_image(mobile_image)
            _add_check("窄屏像素健康", "PASS" if healthy else "CONCERNS", detail)
        except Exception as exc:
            _add_check("窄屏像素健康", "CONCERNS", str(exc))
    return True


def _check_browser_runtime(url: str) -> None:
    if BROWSER_BACKEND == "none":
        _add_check("浏览器运行时", "CONCERNS", "已按 --browser-backend none 跳过浏览器自动化。")
        return

    if BROWSER_BACKEND in {"auto", "playwright"}:
        snapshot = _capture_report_state() if BROWSER_BACKEND == "auto" else None
        playwright_ok = _check_browser_runtime_playwright(url, report_failures=BROWSER_BACKEND == "playwright")
        if playwright_ok:
            return
        if snapshot is not None:
            _restore_report_state(snapshot)
        if BROWSER_BACKEND == "playwright":
            return

    if BROWSER_BACKEND in {"auto", "agent-browser"}:
        if _check_browser_runtime_agent(url):
            return
        if BROWSER_BACKEND == "auto":
            _add_check("浏览器运行时", "CONCERNS", "Playwright 和 agent-browser 均不可用或运行失败。")


def _print_report(url: str, json_mode: bool) -> None:
    if json_mode:
        print(
            json.dumps(
                {
                    "status": final_status,
                    "url": url,
                    "checks": checks,
                    "screenshots": screenshots,
                    "cleanup": cleanup_notes,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    print("## Experience Check")
    print("")
    print(f"- 试玩地址：{url or '未启动'}")
    if screenshots:
        print(f"- 截图目录：{screenshot_dir.relative_to(PROJECT_ROOT).as_posix()}")
        for label, path in screenshots.items():
            print(f"- {label}: {path}")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        detail = check["detail"].replace("\n", "<br>")
        print(f"| {check['name']} | {check['status']} | {detail} |")
    print("")
    print(f"结论：{final_status}")
    if cleanup_notes:
        print("")
        print("清理告警：")
        for note in cleanup_notes:
            print(f"- {note}")
    if final_status == "PASS":
        print("下一步：可以进入人工试玩或继续下一轮迭代。")
    elif final_status == "CONCERNS":
        print("下一步：优先处理 CONCERNS 中的体验或自动化缺口，再交给外部试玩。")
    else:
        print("下一步：先修复 FAIL 项，再重新运行体验检查。")


def _finish(url: str, json_mode: bool, strict: bool) -> int:
    _cleanup_agent_session()
    _print_report(url, json_mode)
    return 1 if final_status == "FAIL" or (strict and final_status == "CONCERNS") else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot Web 体验检查")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--open", action="store_true", help="启动预览后尝试打开浏览器")
    parser.add_argument("--skip-export", action="store_true", help="跳过 Web 导出并复用已有 html5 产物")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0，用于交付门禁")
    parser.add_argument("--keep-browser", action="store_true", help="诊断时保留 agent-browser 会话，默认检查结束自动关闭")
    parser.add_argument(
        "--browser-backend",
        choices=("auto", "playwright", "agent-browser", "none"),
        default="auto",
        help="浏览器自动化后端；auto 优先 Playwright Python，失败后回退 agent-browser",
    )
    args = parser.parse_args()

    global BROWSER_BACKEND, KEEP_BROWSER_SESSION, cleanup_allowed, agent_browser_baseline_pids
    BROWSER_BACKEND = args.browser_backend
    KEEP_BROWSER_SESSION = args.keep_browser
    agent_browser_baseline_pids = _agent_browser_chrome_pids()
    cleanup_allowed = True

    url = ""
    _check_runtime_source_hygiene()
    _check_art_pipeline_handoff()

    if args.skip_export:
        if HTML5_INDEX.exists():
            _add_check("Web 导出", "PASS", "按 --skip-export 复用已有 html5 产物。")
        else:
            _add_check("Web 导出", "FAIL", "传入了 --skip-export，但 html5/index.html 不存在。")
            return _finish("", args.json, args.strict)
    else:
        export_ok, export_text = _run([sys.executable, "scripts/export_web.py", "--json"], timeout=240)
        export_data = _parse_json(export_text)
        if export_ok and export_data and export_data.get("status") == "ok":
            _add_check("Web 导出", "PASS", f"{export_data.get('output_dir')}，文件数 {export_data.get('file_count')}")
        else:
            _add_check("Web 导出", "FAIL", export_text or "导出失败")
            return _finish("", args.json, args.strict)

    preview_ok, preview_text = _run(
        [sys.executable, "scripts/run_web_preview.py", "--json"] + (["--open"] if args.open else []),
        timeout=30,
    )
    preview_data = _parse_json(preview_text)
    url = str((preview_data or {}).get("url") or "")
    if preview_ok and preview_data and preview_data.get("status") == "ready":
        reused = "复用" if preview_data.get("reused") else "启动"
        _add_check("试玩服务器", "PASS", f"{reused}：{url}")
        _check_browser_runtime(url)
    else:
        _add_check("试玩服务器", "FAIL", preview_text or "未能启动预览服务")

    return _finish(url, args.json, args.strict)


if __name__ == "__main__":
    exit_code = 1
    try:
        exit_code = main()
    finally:
        _cleanup_agent_session()
    sys.exit(exit_code)
