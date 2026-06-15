extends Node

const SAVE_PATH := "user://progress.json"

var best_score := 0
var completed_units: Array[String] = []


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


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"best_score": best_score, "completed_units": completed_units}))


func record_score(score: int) -> void:
	if score > best_score:
		best_score = score
		save_progress()


func mark_completed(unit_id: String) -> void:
	if unit_id not in completed_units:
		completed_units.append(unit_id)
		save_progress()
