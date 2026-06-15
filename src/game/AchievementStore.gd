extends Node

# 轻量成就存储。只处理本地解锁状态，不绑定具体玩法实现。

const SAVE_PATH := "user://achievements.json"

signal achievement_unlocked(achievement_id: StringName, definition: Dictionary)

var definitions: Dictionary = {}
var unlocked: Dictionary = {}
var progress: Dictionary = {}


func _ready() -> void:
	load_achievements()
	if has_node("/root/GameEvents"):
		GameEvents.event_emitted.connect(_on_game_event)


func register_achievement(
	achievement_id: StringName,
	title: String,
	description: String,
	event_id: StringName,
	required_count: int = 1,
	payload_equals: Dictionary = {},
	payload_at_least: Dictionary = {}
) -> void:
	definitions[achievement_id] = {
		"title": title,
		"description": description,
		"event_id": event_id,
		"required_count": maxi(1, required_count),
		"payload_equals": payload_equals,
		"payload_at_least": payload_at_least,
	}


func is_unlocked(achievement_id: StringName) -> bool:
	return bool(unlocked.get(String(achievement_id), false))


func unlock(achievement_id: StringName) -> bool:
	if is_unlocked(achievement_id) or not definitions.has(achievement_id):
		return false
	unlocked[String(achievement_id)] = true
	save_achievements()
	var definition := definitions[achievement_id] as Dictionary
	achievement_unlocked.emit(achievement_id, definition)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.ACHIEVEMENT_UNLOCKED, {"id": achievement_id, "definition": definition})
	return true


func load_achievements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	unlocked = parsed.get("unlocked", {})
	progress = parsed.get("progress", parsed.get("event_counts", {}))


func save_achievements() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"unlocked": unlocked, "progress": progress}))


func _on_game_event(event_id: StringName, payload: Dictionary) -> void:
	var changed := false
	var unlocked_any := false
	for achievement_id in definitions:
		var definition := definitions[achievement_id] as Dictionary
		if definition.get("event_id") != event_id:
			continue
		if not _payload_matches(payload, definition.get("payload_equals", {})):
			continue
		if not _payload_at_least_matches(payload, definition.get("payload_at_least", {})):
			continue
		var key := String(achievement_id)
		progress[key] = int(progress.get(key, 0)) + 1
		changed = true
		if int(progress.get(key, 0)) >= int(definition.get("required_count", 1)):
			unlocked_any = unlock(achievement_id) or unlocked_any
	if changed and not unlocked_any:
		save_achievements()


func _payload_matches(payload: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if payload.get(key) != expected[key]:
			return false
	return true


func _payload_at_least_matches(payload: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if float(payload.get(key, 0.0)) < float(expected[key]):
			return false
	return true
