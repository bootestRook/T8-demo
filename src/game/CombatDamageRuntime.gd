extends RefCounted
class_name CombatDamageRuntime

const MONSTER_HIT_FLASH := preload("res://src/game/MonsterHitFlash.gd")


static func update_statuses(runtime: CombatRuntime, monster: Dictionary, delta: float) -> void:
	MONSTER_HIT_FLASH.tick(monster, delta)
	var statuses: Dictionary = monster.get("statuses", {})
	var expired: Array = []
	for key in statuses.keys():
		var status: Dictionary = statuses[key] as Dictionary
		status["remaining"] = float(status.get("remaining", 0.0)) - delta
		if float(status.get("tick_damage", 0.0)) > 0.0:
			tick_status_damage(runtime, monster, status, String(key), delta)
		if float(status.get("remaining", 0.0)) <= 0.0:
			expired.append(key)
		else:
			statuses[key] = status
	for key in expired:
		statuses.erase(key)
	monster["statuses"] = statuses


static func tick_status_damage(runtime: CombatRuntime, monster: Dictionary, status: Dictionary, key: String, delta: float) -> void:
	status["tick_timer"] = float(status.get("tick_timer", 0.0)) - delta
	if float(status.get("tick_timer", 0.0)) > 0.0:
		return
	var tick_damage := float(status.get("tick_damage", 0.0))
	monster["hp"] = float(monster.get("hp", 0.0)) - tick_damage
	if tick_damage > 0.0:
		MONSTER_HIT_FLASH.trigger(monster)
	status["tick_timer"] = float(status.get("tick_interval", 0.5))
	runtime._add_combat_effect(
		monster.get("position", Vector2.ZERO), key, tick_damage, {"element": damage_element_for_kind(key, "", ""), "is_player_damage": true}
	)


static func monster_speed_mul(monster: Dictionary) -> float:
	var statuses: Dictionary = monster.get("statuses", {})
	if statuses.has("freeze") or statuses.has("paralyze") or statuses.has("stun"):
		return 0.0
	var result := 1.0
	if statuses.has("slow"):
		var slow: Dictionary = statuses["slow"] as Dictionary
		result *= float(slow.get("slow_mul", 0.55))
	return result


static func service_deal_damage(runtime: CombatRuntime, command: Dictionary, event: CombatEvent) -> void:
	runtime._log_combat_command(command)
	var amount := float(command.get("amount", 0.0))
	var damage_kind := String(command.get("damage_kind", "damage"))
	var effect_extra := {
		"element": damage_element_for_kind(damage_kind, String(command.get("element", "")), String(event.source_id)),
		"critical": is_critical_damage(command, event),
		"source_id": String(event.source_id),
		"event_id": String(event.event_id),
		"is_player_damage": true,
	}
	if damage_kind == "explosion":
		var explosion_radius := runtime._explosion_effect_radius(command, event)
		var explosion_center := runtime._explosion_effect_center(event)
		effect_extra["area_radius"] = explosion_radius
		effect_extra["effect_center"] = explosion_center
		effect_extra["suppress_ring"] = true
		(
			runtime
			. _add_combat_effect(
				explosion_center,
				"explosion_area",
				amount,
				{
					"element": effect_extra["element"],
					"area_radius": explosion_radius,
					"is_player_damage": false,
				}
			)
		)
	for target_id in runtime._command_targets(command):
		damage_monster(runtime, String(target_id), amount, damage_kind, effect_extra)


static func service_apply_status(runtime: CombatRuntime, command: Dictionary, _event: CombatEvent) -> void:
	runtime._log_combat_command(command)
	var status_id := String(command.get("status_id", "status"))
	for target_id in runtime._command_targets(command):
		apply_status_to_monster(runtime, String(target_id), status_id, command)


static func damage_monster(runtime: CombatRuntime, monster_id: String, amount: float, kind: String, effect_extra: Dictionary = {}) -> void:
	var index := runtime._monster_index_by_id(monster_id)
	if index == -1:
		return
	var monster: Dictionary = runtime.active_monsters[index]
	var final_amount := amount * monster_damage_taken_mul(monster)
	monster["hp"] = maxf(0.0, float(monster.get("hp", 0.0)) - final_amount)
	if final_amount > 0.0:
		MONSTER_HIT_FLASH.trigger(monster)
	runtime.active_monsters[index] = monster
	runtime._add_combat_effect(monster.get("position", Vector2.ZERO), kind, final_amount, effect_extra)


static func monster_damage_taken_mul(monster: Dictionary) -> float:
	var result := 1.0
	var statuses: Dictionary = monster.get("statuses", {})
	for key in statuses.keys():
		var status: Dictionary = statuses[key] as Dictionary
		result *= float(status.get("damage_taken_mul", 1.0))
	return result


static func apply_status_to_target_list(
	runtime: CombatRuntime, targets: Array, count: int, status_id: String, duration: float, extra: Dictionary = {}
) -> int:
	var applied := 0
	for item in targets:
		if applied >= count:
			return applied
		if not (item is Dictionary):
			continue
		var target: Dictionary = item
		var command := extra.duplicate(true)
		command["duration"] = duration
		apply_status_to_monster(runtime, String(target.get("id", "")), status_id, command)
		runtime._add_combat_effect(
			target.get("position", Vector2.ZERO), String(command.get("vfx_kind", status_id)), 0.0, {"status_id": status_id}
		)
		applied += 1
	return applied


static func apply_status_to_monster(runtime: CombatRuntime, monster_id: String, status_id: String, command: Dictionary) -> void:
	var index := runtime._monster_index_by_id(monster_id)
	if index == -1:
		return
	var monster: Dictionary = runtime.active_monsters[index]
	var statuses: Dictionary = monster.get("statuses", {})
	var duration := float(command.get("duration", 0.5))
	var tick_damage := float(command.get("tick_damage", 0.0))
	if command.has("total_damage") and duration > 0.0:
		tick_damage = float(command.get("total_damage", 0.0)) / maxf(1.0, duration / 0.5)
	if command.has("total_damage_max_hp_ratio") and duration > 0.0:
		var max_hp_damage := float(monster.get("hp_max", 0.0)) * float(command.get("total_damage_max_hp_ratio", 0.0))
		tick_damage += max_hp_damage / maxf(1.0, duration / 0.5)
	var stack := 1
	var max_stack := maxi(1, int(command.get("max_stack", 1)))
	if statuses.has(status_id):
		var old_status: Dictionary = statuses[status_id] as Dictionary
		stack = mini(max_stack, int(old_status.get("stack", 1)) + 1)
		tick_damage *= float(stack)
	statuses[status_id] = {
		"remaining": duration,
		"tick_damage": tick_damage,
		"tick_interval": 0.5,
		"tick_timer": 0.5,
		"slow_mul": float(command.get("slow_mul", 0.55)),
		"damage_taken_mul": float(command.get("damage_taken_mul", 1.0)),
		"stack": stack,
	}
	monster["statuses"] = statuses
	runtime.active_monsters[index] = monster


static func damage_element_for_kind(kind: String, explicit_element: String, source_id: String) -> String:
	var result := "physical"
	if not explicit_element.is_empty():
		result = explicit_element
	elif kind == "impact" or kind == "spark" or kind == "burn":
		result = "fire"
	elif kind == "projectile" or kind == "small_ice" or kind == "freeze" or kind == "frostbite":
		result = "ice"
	elif kind == "electro_bolt" or kind == "particle" or kind == "matrix" or source_id.find("electro") != -1:
		result = "electric"
	elif kind == "explosion":
		result = "electric" if source_id.find("electro") != -1 else "fire"
	return result


static func is_critical_damage(command: Dictionary, event: CombatEvent) -> bool:
	if command.has("critical"):
		return bool(command.get("critical", false))
	if command.has("is_crit"):
		return bool(command.get("is_crit", false))
	if event.payload.has("critical"):
		return bool(event.payload.get("critical", false))
	return bool(event.payload.get("is_crit", false))
