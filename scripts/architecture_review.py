#!/usr/bin/env python3
"""Lightweight architecture boundary review for AI-driven Godot work."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODULE_CATALOG = PROJECT_ROOT / "spec" / "module_catalog.json"
MODULES_DIR = PROJECT_ROOT / "src" / "game" / "modules"
SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
SCAN_ROOTS = [PROJECT_ROOT / "src", PROJECT_ROOT / "scenes", PROJECT_ROOT / "project.godot"]

checks: list[dict[str, str]] = []
final_status = "PASS"


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _read(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _source_files() -> list[Path]:
    files: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        if root.is_file() and root.suffix in SOURCE_EXTENSIONS:
            files.append(root)
        elif root.is_dir():
            files.extend(
                file for file in root.rglob("*")
                if file.is_file() and file.suffix in SOURCE_EXTENSIONS
            )
    return sorted(files)


def _gd_files() -> list[Path]:
    return [file for file in _source_files() if file.suffix == ".gd"]


def _load_catalog() -> dict[str, Any] | None:
    if not MODULE_CATALOG.exists():
        _add("模块清单", "FAIL", "缺少 spec/module_catalog.json。")
        return None
    try:
        data = json.loads(MODULE_CATALOG.read_text(encoding="utf-8"))
    except Exception as exc:
        _add("模块清单", "FAIL", f"无法解析 spec/module_catalog.json：{exc}")
        return None
    if not isinstance(data, dict) or not isinstance(data.get("modules"), list):
        _add("模块清单", "FAIL", "module_catalog.json 必须包含 modules 数组。")
        return None
    _add("模块清单", "PASS", f"已登记 {len(data.get('modules', []))} 个可选模块。")
    return data


def _check_catalog_paths(catalog: dict[str, Any]) -> None:
    missing: list[str] = []
    duplicate_ids: list[str] = []
    seen: set[str] = set()
    for module in catalog.get("modules", []):
        module_id = str(module.get("id", ""))
        if not module_id:
            missing.append("缺少 id")
        elif module_id in seen:
            duplicate_ids.append(module_id)
        seen.add(module_id)
        path = str(module.get("path", ""))
        if not path or not (PROJECT_ROOT / path).exists():
            missing.append(f"{module_id or '<unknown>'}: {path or '缺少 path'}")
    details = []
    if missing:
        details.append("路径问题：" + "；".join(missing))
    if duplicate_ids:
        details.append("重复 id：" + "，".join(sorted(set(duplicate_ids))))
    _add("模块路径", "FAIL" if details else "PASS", "；".join(details) if details else "清单路径均存在且 id 不重复。")


def _check_unregistered_modules(catalog: dict[str, Any]) -> None:
    catalog_paths = {
        (PROJECT_ROOT / str(module.get("path", ""))).resolve()
        for module in catalog.get("modules", [])
        if module.get("path")
    }
    actual_paths = {file.resolve() for file in MODULES_DIR.glob("*.gd")} if MODULES_DIR.exists() else set()
    missing = sorted(_rel(path) for path in actual_paths - catalog_paths)
    _add(
        "模块登记",
        "CONCERNS" if missing else "PASS",
        "未登记到 spec/module_catalog.json：" + "，".join(missing) if missing else "src/game/modules 下模块均已登记。",
    )


def _module_files() -> list[Path]:
    if not MODULES_DIR.exists():
        return []
    return sorted(file for file in MODULES_DIR.glob("*.gd") if file.is_file())


def _check_module_boundaries() -> None:
    issues: list[str] = []
    for file in _module_files():
        text = _read(file)
        for line_no, line in enumerate(text.splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if re.search(r"\bHud\b|src/ui/Hud\.gd|/root/Hud", stripped):
                issues.append(f"{_rel(file)}:{line_no} 引用 HUD")
            if re.search(r"PrototypeState\.(?!gd\b)|/root/PrototypeState", stripped):
                issues.append(f"{_rel(file)}:{line_no} 直接引用 PrototypeState")
    _add(
        "模块越界",
        "FAIL" if issues else "PASS",
        "；".join(issues[:12]) if issues else "模块未直接引用 HUD 或 PrototypeState。",
    )


def _check_hud_boundaries() -> None:
    hud = PROJECT_ROOT / "src" / "ui" / "Hud.gd"
    text = _read(hud)
    if not text:
        _add("HUD 边界", "CONCERNS", "未找到 src/ui/Hud.gd。")
        return
    suspicious: list[str] = []
    patterns = [
        r"\bscore\s*(?:\+=|-=|=)",
        r"\bhp\s*(?:\+=|-=|=)",
        r"\bhealth\s*(?:\+=|-=|=)",
        r"\bphase\s*=",
        r"\bwin\s*=",
        r"\blose\s*=",
        r"PrototypeState\.[A-Za-z0-9_]+\s*=",
    ]
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("signal ") or stripped.startswith("var "):
            continue
        if any(re.search(pattern, stripped, re.IGNORECASE) for pattern in patterns):
            suspicious.append(f"{_rel(hud)}:{line_no} {stripped[:80]}")
    _add(
        "HUD 边界",
        "CONCERNS" if suspicious else "PASS",
        "疑似在 HUD 写核心玩法状态：" + "；".join(suspicious[:8]) if suspicious else "HUD 未发现明显核心玩法写入。",
    )


def _check_data_module_persistence(catalog: dict[str, Any]) -> None:
    issues: list[str] = []
    for module in catalog.get("modules", []):
        if module.get("layer") != "data":
            continue
        if module.get("persistence") is False:
            continue
        methods = set(module.get("public_methods", []))
        path = PROJECT_ROOT / str(module.get("path", ""))
        text = _read(path)
        has_state = any(token in text for token in ("var ", "Dictionary", "Array"))
        if has_state and not {"serialize", "deserialize"}.issubset(methods):
            issues.append(str(module.get("name") or module.get("id")))
    _add(
        "数据模块存档协议",
        "CONCERNS" if issues else "PASS",
        "数据模块未在清单声明 serialize/deserialize：" + "，".join(issues) if issues else "数据模块清单包含必要持久化协议或无需存档。",
    )


def _check_game_script_size() -> None:
    game = PROJECT_ROOT / "scenes" / "Game.gd"
    text = _read(game)
    if not text:
        _add("Game.gd 职责", "CONCERNS", "未找到 scenes/Game.gd。")
        return
    lines = [line for line in text.splitlines() if line.strip() and not line.strip().startswith("#")]
    function_count = len(re.findall(r"^func\s+", text, flags=re.MULTILINE))
    issue = len(lines) > 420 or function_count > 32
    _add(
        "Game.gd 职责",
        "CONCERNS" if issue else "PASS",
        (
            f"Game.gd 较大：有效行 {len(lines)}，函数 {function_count}；新增能力前考虑拆到单一职责模块。"
            if issue
            else f"Game.gd 规模可控：有效行 {len(lines)}，函数 {function_count}。"
        ),
    )


def _check_runtime_reference_loads() -> None:
    hits: list[str] = []
    for file in _source_files():
        text = _read(file)
        for line_no, line in enumerate(text.splitlines(), start=1):
            lower = line.lower()
            if "references/" not in lower and "res://references" not in lower:
                continue
            if any(token in lower for token in ("load(", "preload(", "resourceloader", "ext_resource")):
                hits.append(f"{_rel(file)}:{line_no}")
    _add(
        "运行时参考资源边界",
        "FAIL" if hits else "PASS",
        "运行时代码加载 references：" + "，".join(hits[:12]) if hits else "未发现运行时代码加载 references/。",
    )


def _print(json_mode: bool) -> None:
    if json_mode:
        print(json.dumps({"status": final_status, "checks": checks}, ensure_ascii=False, indent=2))
        return
    print("## Architecture Review")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        detail = check["detail"].replace("\n", "<br>")
        print(f"| {check['name']} | {check['status']} | {detail} |")
    print("")
    print(f"结论：{final_status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="架构边界审查")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    catalog = _load_catalog()
    if catalog:
        _check_catalog_paths(catalog)
        _check_unregistered_modules(catalog)
        _check_data_module_persistence(catalog)
    _check_module_boundaries()
    _check_hud_boundaries()
    _check_game_script_size()
    _check_runtime_reference_loads()
    _print(args.json)
    return 1 if final_status == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
