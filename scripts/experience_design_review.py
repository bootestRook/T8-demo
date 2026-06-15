#!/usr/bin/env python3
"""静态审查完整首版游戏的体验结构。

这个脚本只检查可证据化的结构，不判断主观好玩程度。空脚手架会被单独
标记，真实游戏交付默认必须满足完整首版底线。
"""
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
BLUEPRINTS_FILE = PROJECT_ROOT / "spec" / "gameplay_blueprints.json"
SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot", ".json"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}

checks: list[dict[str, str]] = []
final_status = "PASS"


def _read(path: Path) -> str:
    if not path.exists() or not path.is_file():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def _read_rel(path: str) -> str:
    return _read(PROJECT_ROOT / path)


def _load_blueprints() -> dict[str, Any]:
    if not BLUEPRINTS_FILE.exists():
        return {"experience_floor": {}, "blueprints": []}
    return json.loads(_read(BLUEPRINTS_FILE))


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _has_any(text: str, patterns: list[str]) -> bool:
    lower = text.lower()
    return any(pattern.lower() in lower for pattern in patterns)


def _active_blueprints(concept: str, data: dict[str, Any]) -> list[str]:
    catalog = {item.get("id") for item in data.get("blueprints", []) if item.get("id")}
    active: list[str] = []
    for match in re.findall(r"`([a-zA-Z0-9_\-]+)`", concept):
        if match in catalog and match not in active:
            active.append(match)
    if "starter-template" in concept and "starter_template" not in active:
        active.append("starter_template")
    return active or ["common_loop"]


def _source_files() -> list[Path]:
    roots = [PROJECT_ROOT / "src", PROJECT_ROOT / "scenes", PROJECT_ROOT / "project.godot"]
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix in SOURCE_EXTENSIONS:
            files.append(root)
        elif root.is_dir():
            files.extend(
                path for path in root.rglob("*")
                if path.is_file() and path.suffix in SOURCE_EXTENSIONS
            )
    return sorted(files)


def _source_text() -> str:
    chunks: list[str] = []
    for path in _source_files():
        try:
            rel = path.relative_to(PROJECT_ROOT).as_posix()
        except ValueError:
            rel = path.as_posix()
        chunks.append(rel + "\n" + _read(path))
    return "\n".join(chunks)


def _content_units_text() -> str:
    return _read_rel("src/game/ContentUnits.gd")


def _systems_docs_text() -> str:
    systems_dir = PROJECT_ROOT / "docs" / "project" / "gameplay" / "systems"
    if not systems_dir.exists():
        return ""
    chunks: list[str] = []
    for path in sorted(systems_dir.glob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        chunks.append(path.relative_to(PROJECT_ROOT).as_posix() + "\n" + _read(path))
    return "\n\n".join(chunks)


def _system_doc_files() -> list[Path]:
    systems_dir = PROJECT_ROOT / "docs" / "project" / "gameplay" / "systems"
    if not systems_dir.exists():
        return []
    return sorted(
        path for path in systems_dir.glob("*.md")
        if path.is_file() and path.name.lower() != "readme.md"
    )


def _section(text: str, headers: list[str]) -> str:
    lines = text.splitlines()
    capture = False
    captured: list[str] = []
    for line in lines:
        if line.startswith("## "):
            title = line.lstrip("#").strip()
            if title in headers:
                capture = True
                continue
            if capture:
                break
        if capture:
            captured.append(line)
    return "\n".join(captured).strip()


def _clean_bullet(line: str) -> str:
    return re.sub(r"^\s*(?:[-*]|\d+[.)])\s*(?:\[[ xX]\]\s*)?", "", line).strip()


def _declared_units(concept: str) -> list[str]:
    text = _section(concept, ["首版内容单元", "内容单元"])
    items: list[str] = []
    for line in text.splitlines():
        stripped = _clean_bullet(line)
        if not stripped:
            continue
        if any(token in stripped for token in ("暂无", "待确认", "待写入", "待在", "待创建", "无。", "无内置", "空脚手架")):
            continue
        if line.lstrip().startswith(("-", "*")) or re.match(r"^\s*\d+[.)]", line):
            items.append(stripped)
            continue
        if re.search(r"第\s*\d+\s*个", stripped):
            items.append(stripped)
    if len(items) <= 1:
        numbered = re.findall(r"第\s*\d+\s*个[^；;\n。]*", text)
        for item in numbered:
            if item not in items:
                items.append(item)
    return items


def _declared_system_stages(concept: str) -> list[str]:
    stages: list[str] = []
    explicit = _section(concept, ["系统阶段"])
    if explicit:
        for line in explicit.splitlines():
            stripped = _clean_bullet(line)
            if not stripped:
                continue
            if any(token in stripped for token in ("暂无", "待确认", "待写入", "待在", "待创建", "空脚手架")):
                continue
            if line.lstrip().startswith(("-", "*")) or re.match(r"^\s*\d+[.)]", line):
                stages.append(stripped)

    for path in _system_doc_files():
        text = _read(path)
        if any(token in text for token in ("待写入", "待在首版确认稿", "待创建新游戏后写入")):
            continue
        stage_section = _section(text, ["系统阶段", "首版阶段", "阶段"])
        if stage_section:
            for line in stage_section.splitlines():
                stripped = _clean_bullet(line)
                if stripped and (line.lstrip().startswith(("-", "*")) or re.match(r"^\s*\d+[.)]", line)):
                    stages.append(f"{path.stem}: {stripped}")
        else:
            stages.append(path.stem)
    return stages


def _content_unit_code_count(source: str) -> int:
    patterns = [
        r"[\"']id[\"']\s*:",
        r"\bid\s*=\s*[\"'][A-Za-z0-9_\-]+[\"']",
    ]
    count = 0
    content_units = _content_units_text()
    for pattern in patterns:
        count = max(count, len(re.findall(pattern, content_units)))
    return count


def _system_stage_code_count(source: str) -> int:
    module_patterns = [
        r"class_name\s+([A-Z][A-Za-z0-9_]*(?:Store|System|Manager|Director|Catalog|Table|Router|Runner|Controller|Grid|Rules|Stage))",
        r"res://src/game/modules/[A-Za-z0-9_/.-]+\.gd",
        r"\b(?:current_)?(?:system_)?(?:stage|phase)_id\b",
        r"\b(?:current_)?(?:system_)?(?:stage|phase)\s*=",
    ]
    names: set[str] = set()
    for pattern in module_patterns:
        for match in re.findall(pattern, source):
            if isinstance(match, tuple):
                names.update(item for item in match if item)
            else:
                names.add(match)
    return len(names)


def _animation_evidence(source: str) -> tuple[bool, str]:
    action_dirs: list[tuple[str, str, str]] = []
    sprites = PROJECT_ROOT / "assets" / "sprites"
    if sprites.exists():
        for directory in sprites.rglob("*"):
            if not directory.is_dir():
                continue
            frames = [
                file for file in directory.iterdir()
                if file.is_file() and file.suffix.lower() in IMAGE_EXTENSIONS
            ]
            if len(frames) >= 4:
                rel = directory.relative_to(PROJECT_ROOT).as_posix()
                actor = directory.parent.name.lower()
                action = directory.name.lower()
                action_dirs.append((rel, actor, action))

    referenced_dirs: list[str] = []
    source_lower = source.lower().replace("\\", "/")
    for rel, actor, action in action_dirs:
        if rel.lower() in source_lower or (
            "assets/sprites/" in source_lower and actor in source_lower and action in source_lower
        ):
            referenced_dirs.append(rel)

    if referenced_dirs:
        return True, "动作帧目录已被运行时代码引用：" + "，".join(referenced_dirs[:6])

    animation_nodes = ["AnimatedSprite2D", "SpriteFrames", "AnimationPlayer"]
    has_node = any(token in source for token in animation_nodes)
    has_runtime_playback = _has_any(source, ["play(", "sprite_frames", "animation_finished", "set_animation", "frame_changed"])
    has_actor_context = _has_any(source, ["player", "hero", "enemy", "monster", "boss", "avatar", "主角", "玩家", "敌人"])
    if has_node and has_runtime_playback and has_actor_context:
        return True, "发现运行时动画节点、播放逻辑和角色上下文。"

    detail: list[str] = []
    if action_dirs:
        detail.append("存在动作帧目录但未被运行时代码引用：" + "，".join(item[0] for item in action_dirs[:6]))
    else:
        detail.append("未发现 4 帧以上动作目录")
    if not has_node:
        detail.append("未发现 AnimatedSprite2D / SpriteFrames / AnimationPlayer 节点或资源")
    elif not has_runtime_playback or not has_actor_context:
        detail.append("动画节点证据缺少播放逻辑或角色上下文")
    return False, "；".join(detail) + "。"


def _needs_animation(concept: str, active: list[str], floor: dict[str, Any]) -> bool:
    dynamic_blueprints = set(floor.get("dynamic_blueprints", []))
    if any(item in dynamic_blueprints for item in active):
        return True
    return _has_any(concept, list(floor.get("dynamic_keywords", [])))


def _check_starter(concept: str, active: list[str]) -> bool:
    if "starter_template" not in active and "starter-template" not in concept:
        return False
    units = _content_unit_code_count(_source_text())
    _add(
        "空脚手架体验豁免",
        "PASS" if units == 0 else "FAIL",
        "当前是空脚手架，只检查不预置内容单元。" if units == 0 else f"空脚手架不应预置内容单元，当前疑似 {units} 个。",
    )
    return True


def _check_mode(concept: str) -> None:
    if _has_any(concept, ["完整首版", "完整游戏", "首版内容单元", "系统阶段", "3 个", "三个", "至少 3"]):
        _add("首版目标层级", "PASS", "概念已声明完整首版、内容单元或系统阶段目标。")
        return
    if _has_any(concept, ["技术验证", "快速验证"]):
        _add("首版目标层级", "CONCERNS", "当前只声明技术验证；不能作为真实游戏交付。")
        return
    _add("首版目标层级", "FAIL", "真实游戏默认必须声明完整首版目标，而不是只做最小原型。")


def _check_units(concept: str, source: str, minimum: int) -> None:
    declared_units = _declared_units(concept)
    declared_stages = _declared_system_stages(concept)
    declared = declared_units + declared_stages
    code_count = _content_unit_code_count(source)
    stage_count = _system_stage_code_count(source)
    evidence_count = max(code_count, stage_count)
    status = "PASS" if len(declared) >= minimum and evidence_count >= minimum else "FAIL"
    details = [
        f"设定卡内容单元/系统阶段 {len(declared)} 个",
        f"ContentUnits 代码证据 {code_count} 个",
        f"系统阶段证据 {stage_count} 个",
    ]
    if status == "FAIL":
        details.append(f"完整首版至少需要 {minimum} 个有差异内容单元、挑战或系统阶段。")
    _add("首版内容单元数量", status, "；".join(details))


def _check_unit_differences(concept: str) -> None:
    units = _declared_units(concept) + _declared_system_stages(concept)
    keywords = [
        "差异",
        "布局",
        "空间",
        "节奏",
        "敌人",
        "威胁",
        "目标组合",
        "奖励",
        "失败压力",
        "阶段压力",
        "数值",
        "教学",
        "低风险",
        "高价值",
        "倒计时",
        "变化",
        "更多",
        "路线",
        "障碍",
        "波次",
    ]
    units_with_difference = [
        unit for unit in units
        if any(keyword in unit for keyword in keywords)
    ]
    code = _content_units_text() + "\n" + _systems_docs_text()
    structural_terms = [
        "layout", "rhythm", "enemy", "enemies", "reward", "pressure", "stage", "risk", "difficulty",
        "风险变化", "资源压力", "规则变化", "敌人组合", "目标组合", "奖励变化", "容量压力",
    ]
    structural_hits = [term for term in structural_terms if term.lower() in code.lower()]
    status = "PASS" if len(units) >= 3 and (
        len(units_with_difference) >= 3 or len(structural_hits) >= 2
    ) else "FAIL"
    detail = (
        f"设定卡差异单元 {len(units_with_difference)}/{len(units)}；"
        f"ContentUnits 差异字段：" + ("，".join(structural_hits) if structural_hits else "无")
    )
    _add(
        "内容单元差异",
        status,
        detail if status == "PASS" else detail + "。3 个内容单元必须逐个写清差异，或在 ContentUnits 中提供差异字段。",
    )


def _check_required_terms(name: str, text: str, patterns: list[str]) -> None:
    missing = [pattern for pattern in patterns if pattern.lower() not in text.lower()]
    _add(
        name,
        "FAIL" if missing else "PASS",
        "缺少：" + "，".join(missing) if missing else "品类体验底线字段完整。",
    )


def _run_checks() -> tuple[str, list[dict[str, str]], list[str]]:
    global checks, final_status
    checks = []
    final_status = "PASS"

    concept = _read_rel("docs/game-concept.md")
    source = _source_text()
    data = _load_blueprints()
    floor = data.get("experience_floor", {})
    active = _active_blueprints(concept, data)

    if _check_starter(concept, active):
        return final_status, checks, active

    default_floor = floor.get("default", {})
    minimum = int(default_floor.get("min_content_units", 3))
    runtime_text = source

    _check_mode(concept)
    _check_units(concept, source, minimum)
    if default_floor.get("requires_unit_differences", True):
        _check_unit_differences(concept)

    stage_terms = ["阶段", "波次", "风险升高", "威胁升级", "难度", "倒计时", "撤离", "目标转折", "奖励诱惑", "pressure", "wave", "stage", "risk"]
    _add(
        "30 秒内变化",
        "PASS" if _has_any(runtime_text, stage_terms) else "FAIL",
        "已在运行时代码中发现阶段/压力变化证据。" if _has_any(runtime_text, stage_terms) else "运行时代码缺少阶段升级、威胁变化、奖励诱惑、倒计时或目标转折证据。",
    )

    decision_terms = ["风险", "收益", "资源", "弹药", "冷却", "奖励", "取舍", "选择", "撤离", "容量", "优先级", "诱饵", "损失", "ammo", "cooldown", "choice", "reward"]
    _add(
        "玩家决策压力",
        "PASS" if _has_any(runtime_text, decision_terms) else "FAIL",
        "已在运行时代码中发现风险/资源/奖励/选择压力证据。" if _has_any(runtime_text, decision_terms) else "运行时代码缺少风险收益、资源取舍、位置/目标优先级或撤离时机等决策压力。",
    )

    settlement_terms = ["结算", "本轮表现", "下一步", "继续下一", "胜利", "失败", "settlement", "summary", "result"]
    _add(
        "结算反馈",
        "PASS" if _has_any(runtime_text, settlement_terms) else "FAIL",
        "已在运行时代码中发现胜负结算或下一步反馈证据。" if _has_any(runtime_text, settlement_terms) else "运行时代码缺少胜利、失败、本轮表现和下一步反馈。",
    )

    progress_terms = ["ProgressStore", "最佳", "完成状态", "当前关卡", "当前波次", "下一关", "best_score", "completion", "current_unit"]
    _add(
        "进度反馈",
        "PASS" if _has_any(runtime_text, progress_terms) else "FAIL",
        "已在运行时代码中发现进度/最好成绩/完成状态证据。" if _has_any(runtime_text, progress_terms) else "运行时代码缺少当前内容单元、完成状态、最佳成绩或下一关证据。",
    )

    if _needs_animation(concept, active, floor):
        ok, detail = _animation_evidence(source)
        _add("动态品类动画证据", "PASS" if ok else "FAIL", detail)
    else:
        _add("动态品类动画证据", "PASS", "当前概念未触发动态品类强制动画底线。")

    requirements = floor.get("genre_requirements", {})
    for blueprint_id in active:
        required = requirements.get(blueprint_id)
        if required:
            _check_required_terms(f"品类体验底线：{blueprint_id}", concept, required)

    return final_status, checks, active


def _print(json_mode: bool, status: str, active: list[str]) -> None:
    if json_mode:
        print(json.dumps({"status": status, "active_blueprints": active, "checks": checks}, ensure_ascii=False, indent=2))
        return
    print("## Experience Design Review")
    print("")
    print("- Active blueprints: " + ", ".join(active))
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        print(f"| {check['name']} | {check['status']} | {check['detail']} |")
    print("")
    print(f"结论：{status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="完整首版体验结构审查")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0")
    args = parser.parse_args()

    status, _, active = _run_checks()
    _print(args.json, status, active)
    return 1 if status == "FAIL" or (args.strict and status == "CONCERNS") else 0


if __name__ == "__main__":
    raise SystemExit(main())
