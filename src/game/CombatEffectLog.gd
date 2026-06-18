extends RefCounted
class_name CombatEffectLog

const EFFECT_TIME := 0.58
const EFFECT_LIMIT := 24
const COMMAND_LOG_LIMIT := 24


static func update_effects(effects: Array, delta: float) -> Array:
	var survivors: Array = []
	for item in effects:
		if not (item is Dictionary):
			continue
		var effect := (item as Dictionary).duplicate(true)
		effect["remaining"] = float(effect.get("remaining", 0.0)) - delta
		if float(effect.get("remaining", 0.0)) > 0.0:
			survivors.append(effect)
	return survivors


static func add_effect(effects: Array, effect_id: String, position: Vector2, kind: String, amount: float, extra: Dictionary = {}) -> void:
	var effect := {
		"id": effect_id,
		"position": position,
		"kind": kind,
		"amount": amount,
		"remaining": EFFECT_TIME,
		"duration": EFFECT_TIME,
	}
	for key in extra.keys():
		effect[key] = extra[key]
	effects.append(effect)
	_trim(effects, EFFECT_LIMIT)


static func log_command(command_log: Array, command: Dictionary, elapsed_time: float) -> void:
	(
		command_log
		. append(
			{
				"time": elapsed_time,
				"command": String(command.get("command", "")),
				"event_id": String(command.get("event_id", "")),
			}
		)
	)
	_trim(command_log, COMMAND_LOG_LIMIT)


static func _trim(items: Array, limit: int) -> void:
	while items.size() > limit:
		items.remove_at(0)
