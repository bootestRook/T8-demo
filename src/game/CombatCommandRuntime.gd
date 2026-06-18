extends RefCounted
class_name CombatCommandRuntime


static func service_query_targets(runtime: CombatRuntime, command: Dictionary, event: CombatEvent, default_center: Vector2) -> void:
	runtime._log_combat_command(command)
	var center: Vector2 = event.payload.get(String(command.get("center_key", "")), default_center)
	var targets := runtime._targets_in_radius(center, runtime._combat_radius(float(command.get("radius", 120.0))))
	var store_as := String(command.get("store_as", "targets"))
	event.payload[store_as] = targets
	command["targets"] = targets.duplicate(true)


static func service_knockback(runtime: CombatRuntime, command: Dictionary, _event: CombatEvent, min_y: float) -> void:
	runtime._log_combat_command(command)
	var distance := runtime._combat_radius(float(command.get("distance", 0.5))) * 0.35
	for target_id in runtime._command_targets(command):
		var index := runtime._monster_index_by_id(String(target_id))
		if index == -1:
			continue
		var monster: Dictionary = runtime.active_monsters[index]
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		position.y = maxf(min_y, position.y - distance)
		monster["position"] = position
		runtime.active_monsters[index] = monster
