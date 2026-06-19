#!/usr/bin/env python3
"""Validate runtime JSON config tables used by the current combat demo."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LEVELS_PATH = PROJECT_ROOT / "assets" / "data" / "combat" / "level_configs.json"
MONSTERS_PATH = PROJECT_ROOT / "assets" / "data" / "combat" / "monsters.json"
WAVES_PATH = PROJECT_ROOT / "assets" / "data" / "combat" / "waves.json"
CARDS_PATH = PROJECT_ROOT / "assets" / "data" / "cards" / "card_configs.json"

CORE_SKILLS = {"thermobaric", "dry_ice", "electro_pierce"}
STARTER_EFFECTS = {
    "gun_damage_timed",
    "infinite_ammo",
    "heal_missing_wall",
    "reload_ammo_ratio",
    "weakpoint_mark",
    "wall_shield",
    "rest_then_buff",
    "flash_stun",
    "growth_plan",
}


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _load_array(path: Path, errors: list[str]) -> tuple[list[dict[str, Any]], str]:
    if not path.exists():
        errors.append(f"{_rel(path)}:1 entry=<file> field=<path> 文件不存在")
        return [], ""
    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        errors.append(f"{_rel(path)}:{exc.lineno} entry=<json> field=<syntax> {exc.msg}")
        return [], text
    if not isinstance(data, list):
        errors.append(f"{_rel(path)}:1 entry=<root> field=<type> 必须是数组")
        return [], text
    rows: list[dict[str, Any]] = []
    for index, item in enumerate(data):
        if not isinstance(item, dict):
            errors.append(f"{_rel(path)}:{_line_for_index(text, index)} entry=#{index + 1} field=<type> 条目必须是对象")
            continue
        rows.append(item)
    return rows, text


def _line_for_index(text: str, index: int) -> int:
    seen = -1
    for line_no, line in enumerate(text.splitlines(), start=1):
        if "{" in line:
            seen += line.count("{")
            if seen >= index:
                return line_no
    return 1


def _line_for_value(text: str, field: str, value: str, fallback_index: int) -> int:
    needle = f'"{field}"'
    value_needle = f'"{value}"'
    for line_no, line in enumerate(text.splitlines(), start=1):
        if needle in line and value_needle in line:
            return line_no
    return _line_for_index(text, fallback_index)


def _entry_id(row: dict[str, Any], *fields: str, index: int) -> str:
    for field in fields:
        value = str(row.get(field, "")).strip()
        if value:
            return value
    return f"#{index + 1}"


def _add_error(
    errors: list[str],
    path: Path,
    text: str,
    row: dict[str, Any],
    index: int,
    id_field: str,
    entry: str,
    field: str,
    reason: str,
) -> None:
    line = _line_for_value(text, id_field, str(row.get(id_field, "")), index)
    errors.append(f"{_rel(path)}:{line} entry={entry} field={field} {reason}")


def _text(row: dict[str, Any], field: str) -> str:
    return str(row.get(field, "")).strip()


def _number(value: Any) -> float | None:
    text = str(value).strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _require_text(errors: list[str], path: Path, text: str, row: dict[str, Any], index: int, id_field: str, entry: str, field: str) -> None:
    if _text(row, field) == "":
        _add_error(errors, path, text, row, index, id_field, entry, field, "不能为空")


def _require_number(
    errors: list[str],
    path: Path,
    text: str,
    row: dict[str, Any],
    index: int,
    id_field: str,
    entry: str,
    field: str,
    *,
    min_value: float | None = None,
    integer: bool = False,
) -> float | None:
    value = _number(row.get(field, ""))
    if value is None:
        _add_error(errors, path, text, row, index, id_field, entry, field, "必须是数字")
        return None
    if integer and int(value) != value:
        _add_error(errors, path, text, row, index, id_field, entry, field, "必须是整数")
    if min_value is not None and value < min_value:
        _add_error(errors, path, text, row, index, id_field, entry, field, f"必须 >= {min_value:g}")
    return value


def _duplicate_check(errors: list[str], path: Path, text: str, rows: list[dict[str, Any]], id_field: str) -> set[str]:
    seen: set[str] = set()
    for index, row in enumerate(rows):
        entry = _entry_id(row, id_field, index=index)
        value = _text(row, id_field)
        if not value:
            _add_error(errors, path, text, row, index, id_field, entry, id_field, "不能为空")
        elif value in seen:
            _add_error(errors, path, text, row, index, id_field, entry, id_field, "重复 id")
        seen.add(value)
    return {item for item in seen if item}


def _validate_levels(rows: list[dict[str, Any]], text: str, errors: list[str]) -> dict[str, dict[str, Any]]:
    _duplicate_check(errors, LEVELS_PATH, text, rows, "level_id")
    result: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        entry = _entry_id(row, "level_id", index=index)
        for field in ["stage_name", "objective"]:
            _require_text(errors, LEVELS_PATH, text, row, index, "level_id", entry, field)
        wave_count = _require_number(errors, LEVELS_PATH, text, row, index, "level_id", entry, "wave_count", min_value=1, integer=True)
        boss_wave = _require_number(errors, LEVELS_PATH, text, row, index, "level_id", entry, "boss_wave", min_value=0, integer=True)
        for field in ["attack_coef", "hp_coef", "recommended_duration_sec"]:
            _require_number(errors, LEVELS_PATH, text, row, index, "level_id", entry, field, min_value=0.01)
        if wave_count is not None and boss_wave is not None and boss_wave > wave_count:
            _add_error(errors, LEVELS_PATH, text, row, index, "level_id", entry, "boss_wave", "不能大于 wave_count")
        if _text(row, "level_id"):
            result[_text(row, "level_id")] = row
    return result


def _validate_monsters(rows: list[dict[str, Any]], text: str, errors: list[str]) -> set[str]:
    monster_ids = _duplicate_check(errors, MONSTERS_PATH, text, rows, "monster_id")
    for index, row in enumerate(rows):
        entry = _entry_id(row, "monster_id", index=index)
        for field in ["name", "type", "model", "skill_id"]:
            _require_text(errors, MONSTERS_PATH, text, row, index, "monster_id", entry, field)
        for field in ["hp", "attack", "attack_interval", "exp", "radius", "freeze_mul", "paralyze_mul"]:
            _require_number(errors, MONSTERS_PATH, text, row, index, "monster_id", entry, field, min_value=0.01)
        _require_number(errors, MONSTERS_PATH, text, row, index, "monster_id", entry, "speed", min_value=0.0)
        skill_params = _text(row, "skill_params")
        if skill_params:
            try:
                json.loads(skill_params)
            except json.JSONDecodeError as exc:
                _add_error(errors, MONSTERS_PATH, text, row, index, "monster_id", entry, "skill_params", f"必须是合法 JSON 字符串：{exc.msg}")
    return monster_ids


def _validate_waves(
    rows: list[dict[str, Any]],
    text: str,
    level_configs: dict[str, dict[str, Any]],
    monster_ids: set[str],
    errors: list[str],
) -> None:
    _duplicate_check(errors, WAVES_PATH, text, rows, "event_id")
    waves_by_level: dict[str, set[int]] = {level_id: set() for level_id in level_configs}
    boss_by_level: dict[str, set[int]] = {}
    for index, row in enumerate(rows):
        entry = _entry_id(row, "event_id", "wave_id", index=index)
        level_id = _text(row, "level_id")
        monster_id = _text(row, "monster_id")
        _require_text(errors, WAVES_PATH, text, row, index, "event_id", entry, "wave_id")
        _require_text(errors, WAVES_PATH, text, row, index, "event_id", entry, "level_id")
        _require_text(errors, WAVES_PATH, text, row, index, "event_id", entry, "monster_id")
        wave_index = _require_number(errors, WAVES_PATH, text, row, index, "event_id", entry, "wave_index", min_value=1, integer=True)
        for field in ["time_sec", "monster_count", "first_spawn_count", "spawn_interval_sec", "spawn_count_per_tick", "attack_coef", "hp_coef", "hp_bar_coef", "pierce_coef"]:
            _require_number(errors, WAVES_PATH, text, row, index, "event_id", entry, field, min_value=0.0 if field == "time_sec" else 0.01)
        _require_number(errors, WAVES_PATH, text, row, index, "event_id", entry, "rage_on_kill", min_value=0.0)
        if level_id and level_id not in level_configs:
            _add_error(errors, WAVES_PATH, text, row, index, "event_id", entry, "level_id", f"引用不存在的关卡 {level_id}")
        if monster_id and monster_id not in monster_ids:
            _add_error(errors, WAVES_PATH, text, row, index, "event_id", entry, "monster_id", f"引用不存在的怪物 {monster_id}")
        if level_id in level_configs and wave_index is not None:
            wave_i = int(wave_index)
            waves_by_level.setdefault(level_id, set()).add(wave_i)
            max_wave = int(float(str(level_configs[level_id].get("wave_count", 0))))
            if wave_i > max_wave:
                _add_error(errors, WAVES_PATH, text, row, index, "event_id", entry, "wave_index", f"超过关卡 wave_count={max_wave}")
            if _text(row, "event") == "boss" or str(row.get("is_special_wave", "")).strip() in {"1", "true", "True"}:
                boss_by_level.setdefault(level_id, set()).add(wave_i)
    for level_id, config in level_configs.items():
        expected = int(float(str(config.get("wave_count", 0))))
        missing = [wave for wave in range(1, expected + 1) if wave not in waves_by_level.get(level_id, set())]
        if missing:
            line = _line_for_value(text, "level_id", level_id, 0)
            errors.append(f"{_rel(WAVES_PATH)}:{line} entry=level:{level_id} field=wave_index 缺少波次 {missing[:8]}")
        boss_wave = int(float(str(config.get("boss_wave", 0))))
        if boss_wave > 0 and boss_wave not in boss_by_level.get(level_id, set()):
            errors.append(f"{_rel(LEVELS_PATH)}:1 entry={level_id} field=boss_wave 未在 waves.json 中找到 boss 波次 {boss_wave}")


def _validate_cards(rows: list[dict[str, Any]], text: str, errors: list[str]) -> None:
    _duplicate_check(errors, CARDS_PATH, text, rows, "card_id")
    schools = {_text(row, "school") for row in rows if _text(row, "school")}
    for index, row in enumerate(rows):
        entry = _entry_id(row, "card_id", index=index)
        for field in ["card_name", "same_name_key", "type", "school"]:
            _require_text(errors, CARDS_PATH, text, row, index, "card_id", entry, field)
        _require_number(errors, CARDS_PATH, text, row, index, "card_id", entry, "cost", min_value=0.0, integer=True)
        core_skill = _text(row, "core_skill")
        if core_skill and core_skill not in CORE_SKILLS:
            _add_error(errors, CARDS_PATH, text, row, index, "card_id", entry, "core_skill", f"引用不存在的技能 {core_skill}")
        starter_effect = _text(row, "starter_effect")
        if starter_effect and starter_effect not in STARTER_EFFECTS:
            _add_error(errors, CARDS_PATH, text, row, index, "card_id", entry, "starter_effect", f"引用不存在的 starter_effect {starter_effect}")
        draw_school = _text(row, "draw_school")
        if draw_school and draw_school not in schools:
            _add_error(errors, CARDS_PATH, text, row, index, "card_id", entry, "draw_school", f"引用不存在的流派 {draw_school}")
        effect_list = row.get("effect_id_list", [])
        if not isinstance(effect_list, list):
            _add_error(errors, CARDS_PATH, text, row, index, "card_id", entry, "effect_id_list", "必须是数组")


def validate() -> dict[str, Any]:
    errors: list[str] = []
    levels, levels_text = _load_array(LEVELS_PATH, errors)
    monsters, monsters_text = _load_array(MONSTERS_PATH, errors)
    waves, waves_text = _load_array(WAVES_PATH, errors)
    cards, cards_text = _load_array(CARDS_PATH, errors)

    level_configs = _validate_levels(levels, levels_text, errors)
    monster_ids = _validate_monsters(monsters, monsters_text, errors)
    _validate_waves(waves, waves_text, level_configs, monster_ids, errors)
    _validate_cards(cards, cards_text, errors)

    return {
        "status": "FAIL" if errors else "PASS",
        "errors": errors,
        "checked": {
            "levels": len(levels),
            "monsters": len(monsters),
            "waves": len(waves),
            "cards": len(cards),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="校验战斗 Demo JSON 数据配置")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = validate()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("## Data Config Validation")
        print("")
        print(f"- Result: {result['status']}")
        print(f"- Checked: {result['checked']}")
        for error in result["errors"][:50]:
            print(f"- {error}")
    return 1 if result["status"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
