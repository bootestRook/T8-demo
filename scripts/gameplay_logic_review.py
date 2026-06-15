#!/usr/bin/env python3
"""玩法语义审查。

用 `spec/gameplay_blueprints.json` 驱动检查。当前脚手架默认会检查通用可玩闭环；
当 `docs/game-concept.md` 写入肉鸽、搜打撤、塔防、经营、RTS、自走棋、
养成、背包、暗黑、跑酷或混合玩法等蓝图时，脚本会提示相应的概念字段和模块边界。
"""
from __future__ import annotations

import argparse
import json
import operator
import re
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
BLUEPRINTS_FILE = PROJECT_ROOT / "spec" / "gameplay_blueprints.json"
SOURCE_TEXT_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot", ".json"}
DEFAULT_EVIDENCE_PATHS = ["src/game", "scenes", "src/ui"]

checks: list[dict[str, str]] = []
final_status = "PASS"

OPS = {
    ">": operator.gt,
    ">=": operator.ge,
    "<": operator.lt,
    "<=": operator.le,
    "==": operator.eq,
}


def _read(path: str) -> str:
    target = PROJECT_ROOT / path
    if not target.exists():
        return ""
    return target.read_text(encoding="utf-8", errors="ignore")


def _load_blueprints() -> dict[str, Any]:
    if not BLUEPRINTS_FILE.exists():
        return {"default_blueprints": ["common_loop"], "blueprints": []}
    return json.loads(BLUEPRINTS_FILE.read_text(encoding="utf-8"))


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _number_constants(text: str) -> dict[str, float]:
    constants: dict[str, float] = {}
    for name, value in re.findall(r"const\s+([A-Z0-9_]+)\s*:?=\s*(-?\d+(?:\.\d+)?)", text):
        try:
            constants[name] = float(value)
        except ValueError:
            continue
    return constants


def _has_any(text: str, patterns: list[str]) -> bool:
    lower = text.lower()
    return any(pattern.lower() in lower for pattern in patterns)


def _file_text(paths: list[str], cache: dict[str, str]) -> str:
    return "\n".join(_path_text(path, cache) for path in paths)


def _path_text(path: str, cache: dict[str, str]) -> str:
    target = PROJECT_ROOT / path
    if not target.exists():
        return ""
    if target.is_file():
        return path + "\n" + cache.setdefault(path, _read(path))

    key = path.rstrip("/\\") + "/**"
    if key in cache:
        return cache[key]

    chunks: list[str] = []
    for file in sorted(target.rglob("*")):
        if not file.is_file() or file.suffix not in SOURCE_TEXT_EXTENSIONS:
            continue
        rel = file.relative_to(PROJECT_ROOT).as_posix()
        chunks.append(rel + "\n" + cache.setdefault(rel, _read(rel)))
    cache[key] = "\n".join(chunks)
    return cache[key]


def _detect_active_blueprints(concept: str, catalog: dict[str, dict[str, Any]], defaults: list[str]) -> list[str]:
    if "starter-template" in concept:
        return ["starter_template"]
    active = list(defaults)
    explicit: list[str] = []
    for match in re.findall(r"`([a-zA-Z0-9_\-]+)`", concept):
        if match in catalog:
            explicit.append(match)
    if explicit:
        for blueprint_id in explicit:
            if blueprint_id not in active:
                active.append(blueprint_id)
        return active
    for blueprint_id, blueprint in catalog.items():
        aliases = [blueprint_id, blueprint.get("name", ""), *blueprint.get("aliases", [])]
        if any(alias and alias.lower() in concept.lower() for alias in aliases):
            explicit.append(blueprint_id)
    for blueprint_id in explicit:
        if blueprint_id not in active:
            active.append(blueprint_id)
    return active


def _check_concept_required(blueprint: dict[str, Any], concept: str) -> None:
    required = blueprint.get("concept_required", [])
    if not required:
        return
    missing = [term for term in required if term.lower() not in concept.lower()]
    name = f"蓝图概念：{blueprint['id']}"
    _add(
        name,
        "FAIL" if blueprint["id"] == "common_loop" and missing else ("CONCERNS" if missing else "PASS"),
        "缺少：" + "，".join(missing) if missing else "概念字段完整。",
    )


def _check_code_checks(blueprint: dict[str, Any], cache: dict[str, str]) -> None:
    for item in blueprint.get("code_checks", []):
        text = _file_text(item.get("files", []), cache)
        missing: list[str] = []
        if not _has_any(text, item.get("any", [])):
            missing.append("any(" + " / ".join(item.get("any", [])) + ")")
        if item.get("also_any") and not _has_any(text, item.get("also_any", [])):
            missing.append("also_any(" + " / ".join(item.get("also_any", [])) + ")")
        _add(
            f"蓝图代码：{blueprint['id']} / {item.get('name', 'check')}",
            "FAIL" if missing else "PASS",
            "缺少：" + "；".join(missing) if missing else "通过。",
        )


def _check_numeric_rules(blueprint: dict[str, Any], constants: dict[str, float]) -> None:
    rules = blueprint.get("numeric_rules", [])
    if not rules:
        return
    issues: list[str] = []
    for rule in rules:
        name = rule["constant"]
        if name not in constants:
            issues.append(f"缺少常量 {name}")
            continue
        op = OPS.get(rule.get("op", "=="))
        if op is None:
            issues.append(f"{name} 使用了未知比较符 {rule.get('op')}")
            continue
        expected = constants.get(rule["constant_ref"], 0.0) if "constant_ref" in rule else float(rule.get("value", 0.0))
        if not op(constants[name], expected):
            issues.append(f"{name}={constants[name]:g} 不满足 {rule.get('op')} {expected:g}")
    _add(
        f"蓝图数值：{blueprint['id']}",
        "FAIL" if issues else "PASS",
        "；".join(issues) if issues else "核心数值符号和范围合理。",
    )


def _check_recommended_modules(blueprint: dict[str, Any], concept: str) -> None:
    modules = blueprint.get("recommended_modules", [])
    if not modules or blueprint["id"] in {"common_loop", "starter_template"}:
        return
    found = [module for module in modules if module.lower() in concept.lower()]
    if found:
        _add(f"蓝图模块边界：{blueprint['id']}", "PASS", "已记录模块：" + "，".join(found))
    else:
        _add(
            f"蓝图模块边界：{blueprint['id']}",
            "CONCERNS",
            "建议在 game-concept.md 写入模块边界：" + "，".join(modules[:4]),
        )


def _check_implementation_evidence(blueprint: dict[str, Any], cache: dict[str, str]) -> None:
    evidence_items = blueprint.get("implementation_evidence", [])
    if not evidence_items:
        return

    for item in evidence_items:
        paths = item.get("files") or DEFAULT_EVIDENCE_PATHS
        patterns = item.get("any", [])
        text = _file_text(paths, cache)
        lower = text.lower()
        found = [pattern for pattern in patterns if pattern.lower() in lower]
        min_matches = max(1, int(item.get("min_matches", 1)))
        missing = len(found) < min_matches
        _add(
            f"蓝图代码证据：{blueprint['id']} / {item.get('name', 'evidence')}",
            "CONCERNS" if missing else "PASS",
            (
                f"运行时代码证据不足：需要至少 {min_matches} 个，当前 {len(found)} 个。候选："
                + "，".join(patterns[:8])
            )
            if missing
            else "已发现代码证据：" + "，".join(found[:8]),
        )


def _check_feedback_and_assets(cache: dict[str, str]) -> None:
    game = cache.setdefault("scenes/Game.gd", _read("scenes/Game.gd"))
    project = cache.setdefault("project.godot", _read("project.godot"))
    has_event_flow = "GameEvents" in game and "GameEvents" in project
    if "starter-template" in cache.setdefault("docs/game-concept.md", _read("docs/game-concept.md")):
        has_event_flow = "GameEvents" in project
    missing = []
    if "FeedbackDirector" not in game and not (has_event_flow and "FeedbackDirector" in project):
        missing.append("反馈入口")
    if "AudioDirector" not in game and not (has_event_flow and "AudioDirector" in project):
        missing.append("音效入口")
    _add(
        "素材与反馈边界",
        "CONCERNS" if missing else "PASS",
        "缺少：" + "，".join(missing) if missing else "反馈和音效入口存在，可通过直接调用或事件总线触发。",
    )


def _check_starter_contract(cache: dict[str, str]) -> None:
    game = cache.setdefault("scenes/Game.gd", _read("scenes/Game.gd"))
    state = cache.setdefault("src/game/PrototypeState.gd", _read("src/game/PrototypeState.gd"))
    units = cache.setdefault("src/game/ContentUnits.gd", _read("src/game/ContentUnits.gd"))
    missing: list[str] = []
    forbidden = ["doodle", "JumpPlatform", "JumpPickup", "PLAYER_JUMPED", "STAR_COLLECTED", "PLATFORM_BOUNCED"]
    combined = "\n".join([game, state, units])
    found_forbidden = [item for item in forbidden if item in combined]
    if "STARTER_CONCEPT_ID" not in state or "starter-template" not in state:
        missing.append("starter-template 状态")
    if "var units: Array[Dictionary] = []" not in units:
        missing.append("空内容单元")
    if found_forbidden:
        missing.append("残留 demo 代码：" + "，".join(found_forbidden))
    _add(
        "空脚手架边界",
        "FAIL" if missing else "PASS",
        "缺少：" + "；".join(missing) if missing else "无内置玩法、无内容单元、无旧 demo 运行时痕迹。",
    )


def _print(json_mode: bool, active: list[str]) -> None:
    if json_mode:
        print(json.dumps({"status": final_status, "active_blueprints": active, "checks": checks}, ensure_ascii=False, indent=2))
        return
    print("## Gameplay Logic Review")
    print("")
    print("- Active blueprints: " + ", ".join(active))
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        print(f"| {check['name']} | {check['status']} | {check['detail']} |")
    print("")
    print(f"结论：{final_status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="玩法语义审查")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    concept = _read("docs/game-concept.md")
    state = _read("src/game/PrototypeState.gd")
    cache: dict[str, str] = {"docs/game-concept.md": concept, "src/game/PrototypeState.gd": state}
    data = _load_blueprints()
    catalog = {item["id"]: item for item in data.get("blueprints", [])}
    active = _detect_active_blueprints(concept, catalog, data.get("default_blueprints", ["common_loop"]))
    constants = _number_constants(state)

    for blueprint_id in active:
        blueprint = catalog.get(blueprint_id)
        if not blueprint:
            _add(f"蓝图配置：{blueprint_id}", "FAIL", "蓝图不存在。")
            continue
        _check_concept_required(blueprint, concept)
        _check_code_checks(blueprint, cache)
        _check_numeric_rules(blueprint, constants)
        _check_recommended_modules(blueprint, concept)
        _check_implementation_evidence(blueprint, cache)
    _check_feedback_and_assets(cache)
    if "starter_template" in active:
        _check_starter_contract(cache)
    _print(args.json, active)
    return 1 if final_status == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
