extends Node

const DEFAULT_LEVEL_ID := "1"
const LEVEL_CONFIG_CSV_PATH := "res://assets/data/combat/level_configs.csv"
const MONSTER_CSV_PATH := "res://assets/data/combat/monsters.csv"
const WAVE_CSV_PATH := "res://assets/data/combat/waves.csv"
const LEVEL_CONFIG_JSON_PATH := "res://assets/data/combat/level_configs.json"
const MONSTER_JSON_PATH := "res://assets/data/combat/monsters.json"
const WAVE_JSON_PATH := "res://assets/data/combat/waves.json"
const DEFAULT_WAVE_JSON_PATH := "res://assets/data/combat/default_waves.json"

var units: Array[Dictionary] = []
var content_units: Array[Dictionary] = units
var wave_configs: Array[Dictionary] = []
var card_configs: Array[Dictionary] = []
var upgrade_configs: Array[Dictionary] = []
var monster_specs: Dictionary = {}
var level_configs: Dictionary = {}
var active_level_id := DEFAULT_LEVEL_ID


func _ready() -> void:
	load_combat_configs(active_level_id)


func list_content_units() -> Array[Dictionary]:
	return units.duplicate(true)


func get_active_level_config() -> Dictionary:
	return get_level_config(active_level_id)


func get_level_config(level_id: String) -> Dictionary:
	return (level_configs.get(level_id, {}) as Dictionary).duplicate(true)


func get_monster_spec(monster_id: String) -> Dictionary:
	return (monster_specs.get(monster_id, {}) as Dictionary).duplicate(true)


func get_default_wave_configs() -> Array[Dictionary]:
	return _load_json_rows(DEFAULT_WAVE_JSON_PATH)


func load_combat_configs(level_id: String = DEFAULT_LEVEL_ID) -> void:
	level_configs = _load_level_configs(_load_data_rows(LEVEL_CONFIG_JSON_PATH, LEVEL_CONFIG_CSV_PATH))
	monster_specs = _load_monster_specs(_load_data_rows(MONSTER_JSON_PATH, MONSTER_CSV_PATH))
	active_level_id = level_id
	if not level_configs.has(active_level_id) and level_configs.has(DEFAULT_LEVEL_ID):
		active_level_id = DEFAULT_LEVEL_ID
	wave_configs = _load_wave_configs(_load_data_rows(WAVE_JSON_PATH, WAVE_CSV_PATH), active_level_id)


func reset_for_new_game() -> void:
	units.clear()
	wave_configs.clear()
	card_configs.clear()
	upgrade_configs.clear()
	monster_specs.clear()
	level_configs.clear()


func _load_level_configs(rows: Array[Dictionary]) -> Dictionary:
	var result := {}
	for row in rows:
		var level_id := String(row.get("level_id", ""))
		if level_id.is_empty():
			continue
		result[level_id] = {
			"level_id": level_id,
			"source_level_id": String(row.get("source_level_id", "")),
			"stage_name": String(row.get("stage_name", "")),
			"objective": String(row.get("objective", "")),
			"wave_count": _to_int(row.get("wave_count", 0)),
			"attack_coef": _to_float(row.get("attack_coef", 1.0)),
			"hp_coef": _to_float(row.get("hp_coef", 1.0)),
			"boss_wave": _to_int(row.get("boss_wave", 0)),
			"recommended_duration_sec": _to_float(row.get("recommended_duration_sec", 0.0)),
			"comment": String(row.get("comment", "")),
		}
	return result


func _load_monster_specs(rows: Array[Dictionary]) -> Dictionary:
	var result := {}
	for row in rows:
		var monster_id := String(row.get("monster_id", ""))
		if monster_id.is_empty():
			continue
		result[monster_id] = {
			"monster_id": monster_id,
			"name": String(row.get("name", monster_id)),
			"type": String(row.get("type", "normal")),
			"type_name": String(row.get("type_name", "小怪")),
			"model": String(row.get("model", "")),
			"hp": _to_float(row.get("hp", 90.0)),
			"damage": _to_int(row.get("attack", 18)),
			"speed": _to_float(row.get("speed", 56.0)),
			"attack_interval": _to_float(row.get("attack_interval", 1.4)),
			"exp": _to_int(row.get("exp", 16)),
			"radius": _to_float(row.get("radius", 24.0)),
			"skill_id": String(row.get("skill_id", "")),
			"skill_name": String(row.get("skill_name", "")),
			"skill_params": String(row.get("skill_params", "")),
			"freeze_mul": _to_float(row.get("freeze_mul", 1.0)),
			"paralyze_mul": _to_float(row.get("paralyze_mul", 1.0)),
			"comment": String(row.get("comment", "")),
		}
	return result


func _load_wave_configs(rows: Array[Dictionary], level_id: String) -> Array[Dictionary]:
	var grouped := {}
	var order: Array[int] = []
	for row in rows:
		if String(row.get("level_id", "")) != level_id:
			continue
		var wave_index := _to_int(row.get("wave_index", 0))
		if wave_index <= 0:
			continue
		if not grouped.has(wave_index):
			grouped[wave_index] = _new_wave_group(level_id, wave_index, row)
			order.append(wave_index)
		_add_spawn_to_wave(grouped[wave_index] as Dictionary, row)
	order.sort()
	var result: Array[Dictionary] = []
	for wave_index in order:
		result.append((grouped[wave_index] as Dictionary).duplicate(true))
	return result


func _new_wave_group(level_id: String, wave_index: int, row: Dictionary) -> Dictionary:
	return {
		"wave_id": "L%s_W%02d" % [level_id, wave_index],
		"level_id": level_id,
		"wave_index": wave_index,
		"time": _to_float(row.get("time_sec", 0.0)),
		"event": "spawn",
		"is_special_wave": false,
		"spawns": [],
	}


func _add_spawn_to_wave(wave: Dictionary, row: Dictionary) -> void:
	var event := String(row.get("event", "spawn"))
	var is_special := _to_int(row.get("is_special_wave", 0)) > 0 or event == "boss"
	var wave_time := _to_float(row.get("time_sec", wave.get("time", 0.0)))
	wave["time"] = minf(float(wave.get("time", wave_time)), wave_time)
	if is_special:
		wave["event"] = event
		wave["is_special_wave"] = true
	var spawns: Array = wave.get("spawns", [])
	(
		spawns
		. append(
			{
				"wave_id": String(row.get("wave_id", "")),
				"event_id": String(row.get("event_id", "")),
				"local_id": _to_int(row.get("local_id", 0)),
				"monster_id": String(row.get("monster_id", "")),
				"count": _to_int(row.get("monster_count", 1)),
				"first_spawn_count": _to_int(row.get("first_spawn_count", 1)),
				"spawn_interval": _to_float(row.get("spawn_interval_sec", 1.0)),
				"spawn_count_per_tick": _to_int(row.get("spawn_count_per_tick", 1)),
				"spawn_pattern": String(row.get("spawn_pattern", "random_top")),
				"attack_coef": _to_float(row.get("attack_coef", 1.0)),
				"hp_coef": _to_float(row.get("hp_coef", 1.0)),
				"hp_bar_coef": _to_float(row.get("hp_bar_coef", 1.0)),
				"pierce_coef": _to_float(row.get("pierce_coef", 1.0)),
				"rage_on_kill": _to_float(row.get("rage_on_kill", 0.0)),
				"is_special_wave": is_special,
				"event": event,
				"comment": String(row.get("comment", "")),
			}
		)
	)
	wave["spawns"] = spawns


func _load_csv_rows(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var headers := file.get_csv_line()
	var result: Array[Dictionary] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 0:
			continue
		var item := {}
		for index in range(headers.size()):
			var key := _clean_csv_cell(String(headers[index]))
			if key.is_empty() or index >= row.size():
				continue
			item[key] = _clean_csv_cell(String(row[index]))
		if not item.is_empty():
			result.append(item)
	return result


func _load_data_rows(json_path: String, csv_path: String) -> Array[Dictionary]:
	var json_rows := _load_json_rows(json_path)
	if not json_rows.is_empty():
		return json_rows
	return _load_csv_rows(csv_path)


func _load_json_rows(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return []
	var result: Array[Dictionary] = []
	for item in parsed:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _clean_csv_cell(value: String) -> String:
	return value.replace("\uFEFF", "").strip_edges()


func _to_int(value: Variant) -> int:
	var text := String(value).strip_edges()
	if text.is_empty():
		return 0
	return int(float(text))


func _to_float(value: Variant) -> float:
	var text := String(value).strip_edges()
	if text.is_empty():
		return 0.0
	return float(text)
