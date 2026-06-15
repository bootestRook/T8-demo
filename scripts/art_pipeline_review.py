#!/usr/bin/env python3
"""Review art generation docs and runtime asset handoff."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from asset_coverage import (
    asset_inventory,
    ASSET_MANIFEST_REL_PATH,
    existing_runtime_asset_references,
    generated_runtime_refs,
    load_asset_manifest,
    manifest_role_coverage,
    missing_runtime_assets,
    role_coverage,
    runtime_asset_references,
    validate_asset_manifest,
)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DOC_SCAN_FILES = [
    PROJECT_ROOT / "AGENTS.md",
    PROJECT_ROOT / "README.md",
    PROJECT_ROOT / "START_HERE.md",
]
DOC_SCAN_DIRS = [
    PROJECT_ROOT / "docs",
    PROJECT_ROOT / ".agents" / "skills",
]
RUNTIME_SCAN_PATHS = [
    PROJECT_ROOT / "project.godot",
    PROJECT_ROOT / "export_presets.cfg",
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "scenes",
]
RUNTIME_SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
VALID_MEDIA_OUTPUTS = {"json", "urls", "urls+meta", "downloads"}

checks: list[dict[str, str]] = []
final_status = "PASS"


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _read(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def _doc_files() -> list[Path]:
    files = [path for path in DOC_SCAN_FILES if path.exists()]
    for directory in DOC_SCAN_DIRS:
        if not directory.exists():
            continue
        files.extend(file for file in directory.rglob("*.md") if file.is_file())
    return sorted(set(files))


def _runtime_files() -> list[Path]:
    files: list[Path] = []
    for path in RUNTIME_SCAN_PATHS:
        if not path.exists():
            continue
        if path.is_file() and path.suffix in RUNTIME_SOURCE_EXTENSIONS:
            files.append(path)
        elif path.is_dir():
            files.extend(
                file for file in path.rglob("*")
                if file.is_file() and file.suffix in RUNTIME_SOURCE_EXTENSIONS
            )
    return sorted(files)


def _is_starter_concept(concept: str) -> bool:
    return "starter-template" in concept


def _has_runtime_art_obligation(concept: str, candidate: str, placeholder: bool) -> bool:
    if placeholder:
        return False
    if candidate and candidate not in {"未选择", "无", "none", "None"}:
        return True
    return bool(concept.strip()) and not _is_starter_concept(concept)


def _check_generation_docs() -> None:
    invalid_outputs: list[str] = []
    stale_provider_hits: list[str] = []
    missing_wrapper_refs: list[str] = []

    for file in _doc_files():
        text = _read(file)
        for line_number, line in enumerate(text.splitlines(), start=1):
            if "gpt-image-1" in line:
                stale_provider_hits.append(f"{_rel(file)}:{line_number}")
            if "media_api.py" not in line or " generate " not in f" {line} ":
                continue
            output_match = re.search(r"--output\s+([^\s`]+)", line)
            if output_match and output_match.group(1) not in VALID_MEDIA_OUTPUTS:
                invalid_outputs.append(
                    f"{_rel(file)}:{line_number} uses --output {output_match.group(1)}"
                )
            if "style_candidates" in line and "generate_style_candidates.py" not in line:
                missing_wrapper_refs.append(f"{_rel(file)}:{line_number}")

    _add(
        "生图 provider 文档",
        "CONCERNS" if stale_provider_hits else "PASS",
        "仍出现 gpt-image-1：" + "；".join(stale_provider_hits) if stale_provider_hits else "未发现旧 provider gpt-image-1。",
    )
    _add(
        "media_api 输出参数",
        "FAIL" if invalid_outputs else "PASS",
        "；".join(invalid_outputs) if invalid_outputs else "--output 均使用 media_api 支持的枚举值。",
    )
    _add(
        "风格候选包装脚本",
        "CONCERNS" if missing_wrapper_refs else "PASS",
        (
            "风格候选示例仍直接调用 media_api，建议改用 scripts/generate_style_candidates.py："
            + "；".join(missing_wrapper_refs[:8])
        )
        if missing_wrapper_refs
        else "风格候选流程已指向稳定包装脚本。",
    )


def _extract_style_candidate(concept: str) -> str:
    for line in concept.splitlines():
        if "选中风格候选图" not in line:
            continue
        value = re.split(r"[:：]", line, maxsplit=1)[-1].strip()
        match = re.search(r"(?:res://)?assets/generated/style_candidates/[^\s`，。)]+", value)
        if match:
            return match.group(0).replace("res://", "")
        return value.strip("` *-。")
    return ""


def _style_candidate_exists(candidate: str) -> bool:
    if not candidate or candidate in {"未选择", "无", "none", "None"}:
        return True
    local = candidate.replace("res://", "")
    return (PROJECT_ROOT / local).exists()


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


def _check_first_version_art_plan() -> None:
    concept = _read(PROJECT_ROOT / "docs" / "game-concept.md")
    if not concept:
        _add("首版内容与美术计划", "CONCERNS", "未找到 docs/game-concept.md，无法判断首版内容单元和美术素材计划。")
        return

    missing: list[str] = []
    if "## 首版内容单元" not in concept:
        missing.append("缺少 `## 首版内容单元`")
    if "## 本轮美术素材计划" not in concept:
        missing.append("缺少 `## 本轮美术素材计划`")

    if missing:
        _add("首版内容与美术计划", "CONCERNS", "；".join(missing))
        return

    _add("首版内容与美术计划", "PASS", "docs/game-concept.md 已写入首版内容单元和本轮美术素材计划。")


def _runtime_asset_evidence(candidate: str) -> tuple[list[str], list[str]]:
    candidate_refs: list[str] = []
    runtime_asset_refs: list[str] = []
    candidate_name = Path(candidate).name if candidate else ""

    for file in _runtime_files():
        for line_number, line in enumerate(_read(file).splitlines(), start=1):
            normalized = line.replace("\\", "/")
            lower = normalized.lower()
            if "style_candidates/" in lower or (candidate_name and candidate_name in normalized):
                candidate_refs.append(f"{_rel(file)}:{line_number}")
            has_generated_runtime = "assets/generated/" in lower and "style_candidates/" not in lower
            has_sprite_or_ui = "assets/sprites/" in lower or "assets/ui/" in lower
            if has_generated_runtime or has_sprite_or_ui:
                runtime_asset_refs.append(f"{_rel(file)}:{line_number}")

    return candidate_refs, runtime_asset_refs


def _check_runtime_art_handoff() -> None:
    concept = _read(PROJECT_ROOT / "docs" / "game-concept.md")
    if not concept:
        _add("美术设定卡", "CONCERNS", "未找到 docs/game-concept.md，无法判断风格候选是否已落地。")
        return

    candidate = _extract_style_candidate(concept)
    if not candidate or candidate in {"未选择", "无", "none", "None"}:
        _add("风格候选落地", "PASS", "当前概念未声明选中风格候选图，按空脚手架或未锁定美术处理。")
        return

    candidate_refs, runtime_asset_refs = _runtime_asset_evidence(candidate)
    placeholder = _placeholder_declared(concept)
    details: list[str] = []
    status = "PASS"

    if not _style_candidate_exists(candidate):
        status = "CONCERNS"
        details.append(f"选中风格候选图不存在：{candidate}")
    if candidate_refs:
        status = "CONCERNS"
        details.append("运行时代码引用了 style_candidates，仅登记候选图不等于素材落地：" + "，".join(candidate_refs[:8]))
    if not runtime_asset_refs and not placeholder:
        status = "CONCERNS"
        details.append("已选风格候选，但未发现运行时美术素材引用，也未声明程序化占位。")
    if placeholder:
        if status == "PASS":
            status = "CONCERNS"
        details.append("已声明程序化占位，后续仍需生成或接入正式运行时素材。")
    if runtime_asset_refs:
        details.append("运行时素材证据：" + "，".join(runtime_asset_refs[:8]))

    _add("风格候选落地", status, "；".join(details) if details else "已发现风格候选之后的运行时素材落地证据。")


def _style_candidate_leak_lines(text: str) -> list[str]:
    negative_markers = [
        "不得",
        "禁止",
        "不可",
        "不允许",
        "不能",
        "不要",
        "不等于",
        "不作为",
        "只作为参考",
        "只作为风格",
        "只作为种子",
    ]
    anchor_markers = [
        "选中风格候选图",
        "风格锚点",
    ]
    runtime_markers = [
        "运行时素材",
        "运行时",
        "接入",
        "加载",
        "引用",
        "作为角色",
        "作为怪物",
        "作为敌人",
        "作为UI",
        "作为 UI",
        "作为HUD",
        "作为 HUD",
        "素材包",
    ]
    leaks: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        normalized = line.replace("\\", "/")
        if "style_candidates/" not in normalized:
            continue
        if any(marker in normalized for marker in negative_markers):
            continue
        if any(marker in normalized for marker in runtime_markers):
            leaks.append(f"{line_number}: {line.strip()}")
            continue
        if any(marker in normalized for marker in anchor_markers):
            continue
        leaks.append(f"{line_number}: {line.strip()}")
    return leaks


def _check_style_guide() -> None:
    concept = _read(PROJECT_ROOT / "docs" / "game-concept.md")
    candidate = _extract_style_candidate(concept)
    placeholder = _placeholder_declared(concept)
    if not _has_runtime_art_obligation(concept, candidate, placeholder):
        _add("统一风格指南", "PASS", "当前为空脚手架、未锁定美术或声明程序化占位，不强制检查 style-guide。")
        return

    style_guide = PROJECT_ROOT / "docs" / "project" / "art" / "style-guide.md"
    if not style_guide.exists():
        _add("统一风格指南", "FAIL", "已锁定美术但缺少 docs/project/art/style-guide.md，无法约束 HUD、角色、威胁/目标、场景和 VFX 的统一风格。")
        return

    text = _read(style_guide)
    required_sections = [
        "## 色板",
        "## 线条与材质",
        "## 角色比例",
        "## UI 形状语言",
        "## VFX 气质",
        "## 运行时素材包",
        "## 禁止事项",
    ]
    missing = [section for section in required_sections if section not in text]
    style_candidate_leaks = _style_candidate_leak_lines(text)
    placeholder_hits = [
        token for token in ["待确认", "待从风格候选图", "待创建新游戏后写入", "待写入"]
        if token in text
    ]
    runtime_paths = ["assets/sprites/", "assets/ui/", "assets/generated/runtime/", "addons/"]
    missing_runtime_paths = [path for path in runtime_paths if path not in text]
    if missing or style_candidate_leaks or placeholder_hits or missing_runtime_paths:
        details: list[str] = []
        if missing:
            details.append("缺少章节：" + "，".join(missing))
        if style_candidate_leaks:
            details.append("style-guide 疑似把候选图当运行时素材来源：" + "；".join(style_candidate_leaks[:5]))
        if placeholder_hits:
            details.append("仍含占位内容：" + "，".join(placeholder_hits))
        if missing_runtime_paths:
            details.append("缺少运行时素材路径：" + "，".join(missing_runtime_paths))
        _add("统一风格指南", "FAIL", "；".join(details))
        return

    _add("统一风格指南", "PASS", "docs/project/art/style-guide.md 已覆盖色板、材质、角色、UI、VFX、运行时素材包和禁止事项。")


def _merge_role_hits(runtime_hits: dict[str, list[str]], manifest_hits: dict[str, list[str]]) -> dict[str, list[str]]:
    merged = {role: list(runtime_hits.get(role, [])) for role in set(runtime_hits) | set(manifest_hits)}
    for role, hits in manifest_hits.items():
        for hit in hits:
            label = f"{hit} @ {ASSET_MANIFEST_REL_PATH}"
            if label not in merged.setdefault(role, []):
                merged[role].append(label)
    return merged


def _check_asset_manifest(needs_runtime_art: bool, placeholder: bool, refs: dict[str, list[str]]) -> dict[str, object]:
    manifest, load_errors = load_asset_manifest()
    validation = validate_asset_manifest(manifest, refs)
    errors = list(load_errors) + list(validation["errors"])
    warnings = list(validation["warnings"])
    formal_assets = list(validation["formal_assets"])
    formal_runtime_assets = list(validation.get("formal_runtime_assets", []))
    temporary_assets = list(validation["temporary_assets"])

    if errors:
        _add("运行时素材来源清单", "FAIL", "；".join(errors[:10]))
        return validation

    if manifest is None:
        if needs_runtime_art:
            _add(
                "运行时素材来源清单",
                "CONCERNS",
                f"真实首版缺少 {ASSET_MANIFEST_REL_PATH}；无法区分正式素材、程序化占位和调试图形。",
            )
        else:
            _add("运行时素材来源清单", "PASS", "当前为空脚手架、未锁定美术或声明程序化占位，不强制要求素材来源清单。")
        return validation

    if needs_runtime_art and not formal_runtime_assets:
        detail = []
        if formal_assets:
            detail.append("素材清单有正式素材计划，但没有已接入、文件存在、运行时代码引用且截图可见的正式运行时素材。")
        else:
            detail.append("素材清单未登记任何正式运行时素材。")
        if placeholder:
            detail.append("当前概念声明程序化占位")
        if temporary_assets:
            detail.append("清单仍含临时素材：" + "，".join(temporary_assets[:8]))
        if warnings:
            detail.extend(warnings[:8])
        _add("运行时素材来源清单", "FAIL", "；".join(detail))
        return validation

    if placeholder or temporary_assets:
        detail = []
        if placeholder:
            detail.append("当前概念声明程序化占位")
        if temporary_assets:
            detail.append("清单仍含临时素材：" + "，".join(temporary_assets[:8]))
        if warnings:
            detail.extend(warnings[:8])
        _add("运行时素材来源清单", "CONCERNS", "；".join(detail))
        return validation

    _add(
        "运行时素材来源清单",
        "CONCERNS" if warnings else "PASS",
        "；".join(warnings[:10]) if warnings else f"已登记正式运行时素材 {len(formal_runtime_assets)} 个，未发现占位冒充正式素材。",
    )
    return validation


def _check_runtime_role_coverage() -> None:
    concept = _read(PROJECT_ROOT / "docs" / "game-concept.md")
    candidate = _extract_style_candidate(concept)
    placeholder = _placeholder_declared(concept)
    refs = runtime_asset_references()
    missing_refs = missing_runtime_assets(refs)
    existing_refs = existing_runtime_asset_references(refs)
    role_hits = role_coverage(existing_refs)
    generated_refs = generated_runtime_refs(existing_refs)
    image_count = asset_inventory()["counts"]["images"]
    needs_runtime_art = _has_runtime_art_obligation(concept, candidate, placeholder)
    manifest_validation = _check_asset_manifest(needs_runtime_art, placeholder, refs)
    role_hits = _merge_role_hits(role_hits, manifest_validation.get("role_coverage", {}))
    temporary_assets = list(manifest_validation.get("temporary_assets", []))

    if not needs_runtime_art:
        if _is_starter_concept(concept):
            _add(
                "运行时素材角色覆盖",
                "PASS",
                "当前为空脚手架，不强制检查角色/目标/UI 覆盖；新游戏 init 后必须重新建立素材计划。",
            )
        elif placeholder:
            _add(
                "运行时素材角色覆盖",
                "CONCERNS",
                "当前概念声明为程序化占位；严格交付前必须生成并接入玩家、压力/目标与 UI 相关运行时素材。",
            )
        else:
            _add(
                "运行时素材角色覆盖",
                "PASS",
                "当前概念尚未锁定美术，不强制检查角色/目标/UI 覆盖。",
            )
        return

    issues: list[str] = []
    details: list[str] = []
    if not refs:
        issues.append("未发现任何 res://assets/ 运行时素材引用。")
    if missing_refs:
        missing_details = [
            f"{path} @ {locations[0]}"
            for path, locations in missing_refs.items()
        ]
        issues.append("运行时代码引用了不存在的素材文件：" + "，".join(missing_details[:8]))
    if generated_refs and role_hits["background_map"] and not (
        role_hits["player_actor"] or role_hits["challenge_actor"] or role_hits["objective_pickup"]
    ):
        issues.append("已发现生成素材引用，但覆盖看起来集中在背景/地图，缺少主角或交互对象。")
    if temporary_assets:
        issues.append("素材清单仍含程序化/占位/调试素材，不能计入正式首版完成：" + "，".join(temporary_assets[:8]))

    missing_required: list[str] = []
    if not role_hits["player_actor"]:
        missing_required.append("主角/玩家素材")
    if not (role_hits["challenge_actor"] or role_hits["objective_pickup"]):
        missing_required.append("压力/目标素材")
    if missing_required:
        issues.append("缺少：" + "，".join(missing_required))
    missing_ui_skin = not role_hits["ui_skin"]
    if missing_ui_skin:
        issues.append("未发现 assets/ui 或 HUD/UI sprite 运行时引用；没有 PSD/UI 设计稿不是豁免条件，应先生成 UI sheet、图标或面板素材并接入运行时。")

    for role, hits in role_hits.items():
        if hits:
            details.append(f"{role}: " + "，".join(hits[:4]))
    if generated_refs:
        details.append("generated runtime: " + "，".join(generated_refs[:4]))
    details.append(f"assets image files: {image_count}")

    status = "PASS"
    if missing_refs or (needs_runtime_art and (missing_required or not refs)):
        status = "FAIL"
    elif issues:
        status = "FAIL" if missing_ui_skin and refs and needs_runtime_art else "CONCERNS"

    _add(
        "运行时素材角色覆盖",
        status,
        "；".join(issues + details) if issues else "；".join(details),
    )


def _print(json_mode: bool) -> None:
    if json_mode:
        print(json.dumps({"status": final_status, "checks": checks}, ensure_ascii=False, indent=2))
        return
    print("## Art Pipeline Review")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        print(f"| {check['name']} | {check['status']} | {check['detail']} |")
    print("")
    print(f"结论：{final_status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="美术生成和素材落地审查")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0，用于交付门禁")
    args = parser.parse_args()

    _check_generation_docs()
    _check_first_version_art_plan()
    _check_runtime_art_handoff()
    _check_style_guide()
    _check_runtime_role_coverage()
    _print(args.json)
    return 1 if final_status == "FAIL" or (args.strict and final_status == "CONCERNS") else 0


if __name__ == "__main__":
    raise SystemExit(main())
