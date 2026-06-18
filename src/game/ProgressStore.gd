extends Node

const SAVE_PATH := "user://progress.json"
const STATUS_NONE := "none"
const STATUS_CLEARED := "cleared"
const STATUS_PERFECT := "perfect"

var best_score := 0
var completed_units: Array[String] = []
var level_statuses: Dictionary = {}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	best_score = int(parsed.get("best_score", 0))
	completed_units.assign(parsed.get("completed_units", []))
	level_statuses = (parsed.get("level_statuses", {}) as Dictionary).duplicate(true)
	for unit_id in completed_units:
		var level_id := String(unit_id)
		if not level_statuses.has(level_id):
			level_statuses[level_id] = STATUS_CLEARED


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"best_score": best_score,
						"completed_units": completed_units,
						"level_statuses": level_statuses,
					}
				)
			)
		)
	)


func record_score(score: int) -> void:
	if score > best_score:
		best_score = score
		save_progress()


func mark_completed(unit_id: String) -> void:
	if unit_id not in completed_units:
		completed_units.append(unit_id)
	if not level_statuses.has(unit_id):
		level_statuses[unit_id] = STATUS_CLEARED
	save_progress()


func record_level_result(level_id: String, wall_hp: int, wall_hp_max: int, score: int) -> void:
	if level_id.is_empty() or wall_hp <= 0:
		return
	record_score(score)
	var new_status := STATUS_PERFECT if wall_hp >= wall_hp_max else STATUS_CLEARED
	var old_status := String(level_statuses.get(level_id, STATUS_NONE))
	if old_status == STATUS_PERFECT and new_status == STATUS_CLEARED:
		return
	level_statuses[level_id] = new_status
	if level_id not in completed_units:
		completed_units.append(level_id)
	save_progress()


func get_level_status(level_id: String) -> String:
	return String(level_statuses.get(level_id, STATUS_NONE))


func get_level_status_label(level_id: String) -> String:
	match get_level_status(level_id):
		STATUS_PERFECT:
			return "完美通过"
		STATUS_CLEARED:
			return "已通关"
	return "未通关"


func is_level_playable(level_id: String, all_level_ids: Array[String]) -> bool:
	var index := all_level_ids.find(level_id)
	if index <= 0:
		return index == 0
	var previous_level_id := all_level_ids[index - 1]
	return get_level_status(previous_level_id) != STATUS_NONE


func get_visible_level_ids(all_level_ids: Array[String]) -> Array[String]:
	return get_unlocked_level_ids(all_level_ids)


func get_unlocked_level_ids(all_level_ids: Array[String]) -> Array[String]:
	var unlocked: Array[String] = []
	for level_id in all_level_ids:
		if not is_level_playable(level_id, all_level_ids):
			break
		unlocked.append(level_id)
	return unlocked
