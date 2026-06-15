extends Node
class_name TutorialHints

signal hint_shown(hint_id: StringName, text: String, context: Dictionary)

var hints: Dictionary = {}
var shown: Dictionary = {}


func register_hint(hint_id: StringName, text: String, once: bool = true) -> void:
	hints[hint_id] = {"text": text, "once": once}


func trigger(hint_id: StringName, context: Dictionary = {}) -> bool:
	if not hints.has(hint_id):
		return false
	var hint: Dictionary = hints[hint_id]
	if bool(hint.get("once", true)) and bool(shown.get(hint_id, false)):
		return false
	shown[hint_id] = true
	var text := String(hint.get("text", ""))
	hint_shown.emit(hint_id, text, context)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.TUTORIAL_HINT_SHOWN, {"id": hint_id, "text": text, "context": context})
	return true


func reset_hint(hint_id: StringName) -> void:
	shown.erase(hint_id)


func reset_all() -> void:
	shown.clear()
