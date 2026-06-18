extends RefCounted
class_name CombatProjectileFactory


static func projectile_spawn_delay(command: Dictionary, event: CombatEvent) -> float:
	if event.event_type != CombatEvent.TYPE_CAST:
		return 0.0
	if int(command.get("count", 1)) <= 1:
		return 0.0
	var index := int(command.get("index", 0))
	if index <= 0:
		return 0.0
	var interval := float(command.get("release_interval", event.payload.get("release_interval", 0.0)))
	return maxf(0.0, interval * float(index))


static func projectile_target_context(
	command: Dictionary, payload: Dictionary, event_type: StringName, default_start: Vector2
) -> Dictionary:
	var context := command.duplicate(true)
	var source_position := command_origin(command, payload, default_start)
	context["source_position"] = source_position
	if payload.has("card_play_token"):
		context["card_play_token"] = payload["card_play_token"]
	if event_type != CombatEvent.TYPE_CAST:
		return context
	if not bool(command.get("lock_uses_target_radius", false)):
		context.erase("target_radius")
		return context
	if payload.has("target_radius") and not context.has("target_radius"):
		context["target_radius"] = payload["target_radius"]
	if payload.has("target_center") and not context.has("target_center"):
		context["target_center"] = payload["target_center"]
	elif not context.has("target_center"):
		context["target_center"] = default_start
	return context


static func new_projectile(
	runtime: CombatRuntime, command: Dictionary, payload: Dictionary, target: Dictionary, default_start: Vector2, projectile_max_age: float
) -> Dictionary:
	var origin := command_origin(command, payload, default_start)
	return {
		"id": runtime._next_entity_id("projectile"),
		"projectile_id": String(command.get("projectile_id", "projectile")),
		"position": origin,
		"target_id": String(target.get("id", "")),
		"target_rule": String(command.get("target_rule", "nearest_to_wall")),
		"target_position": target.get("position", origin),
		"direction": origin.direction_to(target.get("position", origin)),
		"line_width": float(command.get("line_width", 36.0)),
		"speed": runtime._combat_projectile_speed(float(command.get("speed", 620.0))),
		"travel_mode": String(command.get("travel_mode", "")),
		"on_hit_event_id": StringName(command.get("on_hit_event_id", &"")),
		"payload": payload.duplicate(true),
		"pierce_remaining": maxi(0, int(command.get("pierce_count", 1)) - 1),
		"hit_targets": [],
		"age": 0.0,
		"max_age": projectile_max_age,
		"index": int(command.get("index", 0)),
	}


static func command_origin(command: Dictionary, payload: Dictionary, default_start: Vector2) -> Vector2:
	var origin := default_start
	var origin_key := String(command.get("origin_key", ""))
	if not origin_key.is_empty():
		var payload_origin = payload.get(origin_key, null)
		if payload_origin is Vector2:
			origin = payload_origin
	if command.has("origin"):
		var command_origin_value = command.get("origin", null)
		if command_origin_value is Vector2:
			origin = command_origin_value
	return origin
