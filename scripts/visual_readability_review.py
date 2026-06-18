#!/usr/bin/env python3
"""Review player-facing visual evidence from browser screenshots.

This script checks evidence that is cheap and low-risk to automate. It does
not judge art quality; it blocks or flags missing screenshots, missing runtime
asset roles, and obvious "technical pass but no player-facing proof" gaps.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from asset_coverage import (
    ASSET_MANIFEST_REL_PATH,
    existing_runtime_asset_references,
    load_asset_manifest,
    manifest_role_coverage,
    missing_runtime_assets,
    role_coverage,
    runtime_asset_references,
    safe_read,
    validate_asset_manifest,
)
from experience_check import _parse_png

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCREENSHOT_ROOT = PROJECT_ROOT / "reports" / "screenshots"
RUNTIME_UI_PATHS = [
    PROJECT_ROOT / "src" / "ui",
    PROJECT_ROOT / "scenes",
]
DYNAMIC_VISUAL_KEYWORDS = [
    "动作",
    "射击",
    "生存",
    "平台",
    "跑酷",
    "搜打撤",
    "战斗",
    "敌人",
    "怪物",
    "boss",
    "player",
    "enemy",
    "combat",
    "shooter",
    "survival",
    "platform",
    "runner",
    "extraction",
]
NON_ACTOR_VISUAL_KEYWORDS = [
    "叙事",
    "视觉小说",
    "解谜",
    "益智",
    "抽象",
    "环境互动",
    "对话",
    "文字冒险",
    "narrative",
    "visual novel",
    "puzzle",
    "abstract",
]

checks: list[dict[str, str]] = []
final_status = "PASS"


def _rel(path: Path) -> str:
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _concept() -> str:
    return safe_read(PROJECT_ROOT / "docs" / "game-concept.md")


def _is_starter_template(concept: str) -> bool:
    return "starter-template" in concept


def _placeholder_declared(concept: str) -> bool:
    markers = [
        "素材落地状态：程序化占位",
        "素材落地状态: 程序化占位",
        "当前锁定风格：程序化占位",
        "当前锁定风格: 程序化占位",
        "先用占位风格继续",
        "未锁定最终美术",
    ]
    return any(marker in concept for marker in markers)


def _has_any(text: str, patterns: list[str]) -> bool:
    lower = text.lower()
    return any(pattern.lower() in lower for pattern in patterns)


def _requires_actor_visuals(concept: str) -> bool:
    if _has_any(concept, DYNAMIC_VISUAL_KEYWORDS):
        return True
    return not _has_any(concept, NON_ACTOR_VISUAL_KEYWORDS)


def _latest_screenshot_dir(explicit: str | None) -> Path | None:
    if explicit:
        path = PROJECT_ROOT / explicit if not Path(explicit).is_absolute() else Path(explicit)
        return path if path.exists() else None
    if not SCREENSHOT_ROOT.exists():
        return None
    dirs = [path for path in SCREENSHOT_ROOT.iterdir() if path.is_dir()]
    if not dirs:
        return None
    return max(dirs, key=lambda path: path.stat().st_mtime)


def _screenshots(path: Path | None) -> dict[str, Path]:
    if path is None:
        return {}
    result: dict[str, Path] = {}
    for file in sorted(path.glob("*.png")):
        name = file.stem.lower()
        for label in ["ready", "running", "input-before", "input-after", "mobile"]:
            if label in name and label not in result:
                result[label] = file
    return result


def _image_metrics(path: Path) -> dict[str, Any]:
    image = _parse_png(path)
    total = image["width"] * image["height"]
    step = max(1, total // 8000)
    bpp = image["bytes_per_pixel"]
    pixels = image["pixels"]
    samples = non_transparent = non_dark = 0
    buckets: set[str] = set()
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
    return {
        "width": image["width"],
        "height": image["height"],
        "non_transparent_ratio": non_transparent / max(1, samples),
        "non_dark_ratio": non_dark / max(1, samples),
        "color_buckets": len(buckets),
    }


def _check_screenshot_evidence(directory: Path | None, shots: dict[str, Path]) -> None:
    if directory is None:
        _add("截图证据", "CONCERNS", "未找到 reports/screenshots 下的截图目录；视觉/体验类交付前必须先运行 experience_check。")
        return
    missing = [label for label in ["ready", "running"] if label not in shots]
    if missing:
        _add(
            "截图证据",
            "CONCERNS",
            f"截图目录 {_rel(directory)} 缺少关键截图：" + "，".join(missing),
        )
        return
    _add("截图证据", "PASS", f"发现关键截图目录：{_rel(directory)}")


def _check_pixel_readability(shots: dict[str, Path]) -> None:
    if "running" not in shots:
        _add("运行中画面基础像素", "CONCERNS", "缺少 running 截图，无法判断运行中画面基础可读性。")
        return
    try:
        metrics = _image_metrics(shots["running"])
    except Exception as exc:
        _add("运行中画面基础像素", "CONCERNS", f"无法解析 running 截图：{exc}")
        return
    healthy = (
        metrics["width"] >= 320
        and metrics["height"] >= 240
        and metrics["non_transparent_ratio"] > 0.90
        and metrics["non_dark_ratio"] > 0.08
        and metrics["color_buckets"] >= 4
    )
    detail = (
        f"{metrics['width']}x{metrics['height']}，非透明 "
        f"{metrics['non_transparent_ratio'] * 100:.1f}%，非暗色 "
        f"{metrics['non_dark_ratio'] * 100:.1f}%，色彩桶 {metrics['color_buckets']}。"
    )
    _add("运行中画面基础像素", "PASS" if healthy else "CONCERNS", detail)


def _check_runtime_visual_roles(concept: str) -> None:
    refs = runtime_asset_references()
    existing = existing_runtime_asset_references(refs)
    missing = missing_runtime_assets(refs)
    roles = role_coverage(existing)
    manifest, load_errors = load_asset_manifest()
    manifest_validation = validate_asset_manifest(manifest, refs)
    manifest_roles = manifest_role_coverage(manifest, refs)
    for role, hits in manifest_roles.items():
        roles.setdefault(role, [])
        roles[role].extend(f"{hit} @ {ASSET_MANIFEST_REL_PATH}" for hit in hits)
    placeholder = _placeholder_declared(concept)
    starter = _is_starter_template(concept)

    if missing:
        samples = [f"{path} @ {locations[0]}" for path, locations in missing.items()]
        _add("运行时视觉素材引用", "FAIL", "存在缺失素材引用：" + "；".join(samples[:8]))
        return
    if load_errors or manifest_validation["errors"]:
        _add("运行时视觉素材引用", "FAIL", "素材来源清单错误：" + "；".join((load_errors + manifest_validation["errors"])[:8]))
        return
    if starter:
        _add("运行时视觉素材引用", "PASS", "当前为空脚手架，不强制要求玩家/威胁/UI 素材截图证据。")
        return
    if placeholder:
        _add("运行时视觉素材引用", "CONCERNS", "当前声明程序化占位；不能作为正式首版视觉验收完成。")
        return
    manifest_note = ""
    if manifest is None:
        manifest_note = f"缺少 {ASSET_MANIFEST_REL_PATH}；只能根据运行时路径做弱判断，不能证明素材来源和截图可见性。"
    if manifest_validation["temporary_assets"]:
        manifest_note = (
            (manifest_note + "；") if manifest_note else ""
        ) + "素材清单仍含程序化/占位/调试素材：" + "，".join(manifest_validation["temporary_assets"][:8])

    require_actor_visuals = _requires_actor_visuals(concept)
    blocking_roles: list[str] = []
    concern_roles: list[str] = []
    if not roles["player_actor"]:
        if require_actor_visuals:
            blocking_roles.append("玩家/主角")
        else:
            concern_roles.append("玩家/主角")
    if not (roles["challenge_actor"] or roles["objective_pickup"]):
        if require_actor_visuals:
            blocking_roles.append("威胁/目标")
        else:
            concern_roles.append("威胁/目标")
    if not roles["ui_skin"]:
        blocking_roles.append("UI/HUD sprite")
    if blocking_roles:
        detail = "缺少运行时素材角色：" + "，".join(blocking_roles)
        if concern_roles:
            detail += "；非动态角色类可人工确认：" + "，".join(concern_roles)
        if manifest_note:
            detail += "；" + manifest_note
        _add("运行时视觉素材引用", "FAIL", detail)
        return
    if concern_roles:
        detail = "缺少运行时视觉角色证据，非动态角色类按人工确认处理：" + "，".join(concern_roles)
        if manifest_note:
            detail += "；" + manifest_note
        _add(
            "运行时视觉素材引用",
            "CONCERNS",
            detail,
        )
        return
    if manifest_note:
        _add("运行时视觉素材引用", "CONCERNS", manifest_note)
        return

    detail = []
    for role, hits in roles.items():
        if hits:
            detail.append(f"{role}: " + "，".join(hits[:3]))
    _add("运行时视觉素材引用", "PASS", "；".join(detail))


def _runtime_ui_text() -> str:
    chunks: list[str] = []
    for root in RUNTIME_UI_PATHS:
        if not root.exists():
            continue
        files = [root] if root.is_file() else list(root.rglob("*"))
        for file in files:
            if file.is_file() and file.suffix in {".gd", ".tscn", ".tres"}:
                chunks.append(safe_read(file))
    return "\n".join(chunks)


def _check_hud_responsive_layout() -> None:
    scene = "\n".join(
        [
            safe_read(PROJECT_ROOT / "scenes" / "Game.tscn"),
            safe_read(PROJECT_ROOT / "scenes" / "ui" / "Hud.tscn"),
        ]
    )
    hud = safe_read(PROJECT_ROOT / "src" / "ui" / "Hud.gd")
    ui_code = "\n".join(safe_read(path) for path in sorted((PROJECT_ROOT / "src" / "ui").glob("*.gd")))
    issues: list[str] = []
    concerns: list[str] = []

    fixed_wide_panel = re.search(r"custom_minimum_size\s*=\s*Vector2\((\d{3,})\s*,", scene)
    if fixed_wide_panel:
        width = int(fixed_wide_panel.group(1))
        if width > 360 and "MESSAGE_WIDTH_RATIO" not in ui_code:
            issues.append(f"中心 HUD 面板存在固定最小宽度 {width}px，窄屏可能溢出。")

    if 'name="TopBar" type="HBoxContainer"' in scene:
        issues.append("TopBar 仍为 HBoxContainer，长目标/状态/提示在窄屏容易互相挤压。")
    has_compact_top_bar_columns = re.search(r"\.columns\s*=\s*1\s+if\s+compact\s+else", ui_code) is not None
    if 'name="TopBar" type="GridContainer"' in scene and not has_compact_top_bar_columns:
        concerns.append("TopBar 已使用 GridContainer，但未发现运行时按窄屏切换列数。")

    for label_name in ["ObjectiveLabel", "StatusLabel", "HintLabel"]:
        pattern = rf'name="{label_name}" type="Label"[\s\S]*?(?=\n\n\[node|\Z)'
        match = re.search(pattern, scene)
        if not match:
            concerns.append(f"未找到 {label_name}。")
            continue
        block = match.group(0)
        if "autowrap_mode" not in block and f"{label_name.lower()}" not in ui_code.lower():
            concerns.append(f"{label_name} 未发现 autowrap 或脚本压缩策略。")

    if "set_gameplay_mode" not in hud:
        concerns.append("Hud.gd 缺少玩法模式降级接口，中心大提示可能在实机玩法中长期遮挡操作区。")
    if "_fit_text" not in ui_code and "HUD_THEME.fit_text" not in ui_code:
        concerns.append("Hud.gd 缺少长文本压缩策略，状态/目标文案变长后可能溢出。")
    if "size_changed.connect" not in ui_code:
        concerns.append("HUD UI 代码未监听 viewport size_changed，浏览器缩放后布局可能不更新。")
    project = safe_read(PROJECT_ROOT / "project.godot")
    uses_expand_stretch = 'window/stretch/mode="canvas_items"' in project and 'window/stretch/aspect="expand"' in project
    if uses_expand_stretch and ("_layout_width" not in ui_code or "window_get_size" not in ui_code):
        concerns.append("项目使用 canvas_items + expand；HUD UI 代码若只读取逻辑 viewport，窄屏浏览器可能仍按桌面宽度布局。")

    if issues:
        _add("HUD 响应式布局", "FAIL", "；".join(issues + concerns))
        return
    if concerns:
        _add("HUD 响应式布局", "CONCERNS", "；".join(concerns))
        return
    _add("HUD 响应式布局", "PASS", "未发现固定宽 HUD 面板、不可重排顶栏或缺失玩法降级接口。")


def _check_ui_placeholder_risk(concept: str) -> None:
    if _is_starter_template(concept):
        _add("UI 占位风险", "PASS", "当前为空脚手架，不强制检查 UI 成品感。")
        return
    if _placeholder_declared(concept):
        _add("UI 占位风险", "CONCERNS", "当前声明程序化占位；UI 可用 ColorRect/Label 过渡，但不得作为正式首版交付。")
        return
    text = _runtime_ui_text()
    has_basic_controls = any(token in text for token in ["Button", "TextureButton", "PanelContainer", "NinePatchRect", "ProgressBar"])
    has_placeholder_only = ("ColorRect" in text or "Label" in text) and "assets/ui/" not in text
    if has_placeholder_only and not has_basic_controls:
        _add("UI 占位风险", "FAIL", "运行时 UI 疑似只由 Label/ColorRect 组成，且未发现 assets/ui/ 引用。")
        return
    if "assets/ui/" not in text:
        _add("UI 占位风险", "CONCERNS", "未在 UI/场景代码中发现 assets/ui/ 引用；若本轮涉及正式 UI，需要补 UI sprite 证据。")
        return
    _add("UI 占位风险", "PASS", "发现 UI 控件结构或 assets/ui/ 运行时引用。")


def _print(json_mode: bool, directory: Path | None, shots: dict[str, Path]) -> None:
    payload = {
        "status": final_status,
        "screenshot_dir": _rel(directory) if directory else "",
        "screenshots": {label: _rel(path) for label, path in shots.items()},
        "checks": checks,
    }
    if json_mode:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return
    print("## Visual Readability Review")
    print("")
    print(f"- 截图目录：{payload['screenshot_dir'] or '未找到'}")
    for label, path in payload["screenshots"].items():
        print(f"- {label}: {path}")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        print(f"| {check['name']} | {check['status']} | {check['detail']} |")
    print("")
    print(f"结论：{final_status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="浏览器截图视觉可读性轻量审查")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0，用于交付门禁")
    parser.add_argument("--screenshots-dir", default=None, help="指定截图目录；默认使用 reports/screenshots 下最新目录")
    args = parser.parse_args()

    concept = _concept()
    directory = _latest_screenshot_dir(args.screenshots_dir)
    shots = _screenshots(directory)
    _check_screenshot_evidence(directory, shots)
    _check_pixel_readability(shots)
    _check_runtime_visual_roles(concept)
    _check_hud_responsive_layout()
    _check_ui_placeholder_risk(concept)
    _print(args.json, directory, shots)
    return 1 if final_status == "FAIL" or (args.strict and final_status == "CONCERNS") else 0


if __name__ == "__main__":
    raise SystemExit(main())
