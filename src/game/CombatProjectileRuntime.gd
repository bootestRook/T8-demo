extends RefCounted
class_name CombatProjectileRuntime

const COMBAT_PROJECTILE_FACTORY := preload("res://src/game/CombatProjectileFactory.gd")


static func update_projectiles(
	runtime: CombatRuntime, delta: float, router: TriggerRouter, default_start: Vector2, projectile_max_age: float
) -> Array:
	var survivors: Array = []
	for item in runtime.active_projectiles:
		if not (item is Dictionary):
			continue
		var projectile := (item as Dictionary).duplicate(true)
		projectile["age"] = float(projectile.get("age", 0.0)) + delta
		if float(projectile.get("age", 0.0)) > float(projectile.get("max_age", projectile_max_age)):
			continue
		projectile = advance_projectile(runtime, projectile, delta, router, survivors, default_start)
	return survivors


static func update_pending_projectile_spawns(
	runtime: CombatRuntime, delta: float, default_start: Vector2, projectile_max_age: float
) -> Array:
	var survivors: Array = []
	for item in runtime.pending_projectile_spawns:
		if not (item is Dictionary):
			continue
		var pending := (item as Dictionary).duplicate(true)
		pending["timer"] = float(pending.get("timer", 0.0)) - delta
		if float(pending.get("timer", 0.0)) > 0.0:
			survivors.append(pending)
			continue
		var command: Dictionary = pending.get("command", {}) as Dictionary
		var payload: Dictionary = pending.get("payload", {}) as Dictionary
		var event_type := StringName(pending.get("event_type", CombatEvent.TYPE_CAST))
		spawn_projectile_from_command(runtime, command, payload, event_type, default_start, projectile_max_age)
	return survivors


static func advance_projectile(
	runtime: CombatRuntime, projectile: Dictionary, delta: float, router: TriggerRouter, survivors: Array, default_start: Vector2
) -> Dictionary:
	if String(projectile.get("travel_mode", "")) == "linear_pierce":
		return advance_linear_pierce_projectile(runtime, projectile, delta, router, survivors, default_start)
	var position: Vector2 = projectile.get("position", default_start)
	var direction: Vector2 = (projectile.get("direction", Vector2.UP) as Vector2).normalized()
	var step := float(projectile.get("speed", 600.0)) * delta
	var next_position := position + direction * step
	var excluded: Array = projectile.get("hit_targets", [])
	var hit := runtime._first_monster_on_segment(position, next_position, excluded, float(projectile.get("line_width", 36.0)))
	projectile["direction"] = direction
	projectile["position"] = next_position
	if hit.is_empty():
		survivors.append(projectile)
		return projectile
	resolve_projectile_hit(runtime, projectile, hit, router, default_start)
	var hit_targets: Array = projectile.get("hit_targets", [])
	hit_targets.append(String(hit.get("id", "")))
	projectile["hit_targets"] = hit_targets
	if int(projectile.get("pierce_remaining", 0)) > 0:
		projectile["pierce_remaining"] = int(projectile.get("pierce_remaining", 0)) - 1
		survivors.append(projectile)
	return projectile


static func advance_linear_pierce_projectile(
	runtime: CombatRuntime, projectile: Dictionary, delta: float, router: TriggerRouter, survivors: Array, default_start: Vector2
) -> Dictionary:
	var position: Vector2 = projectile.get("position", default_start)
	var direction: Vector2 = (projectile.get("direction", Vector2.UP) as Vector2).normalized()
	projectile["direction"] = direction
	var step := float(projectile.get("speed", 600.0)) * delta
	var next_position := position + direction * step
	var excluded: Array = projectile.get("hit_targets", [])
	var hit := runtime._first_monster_on_segment(position, next_position, excluded, float(projectile.get("line_width", 36.0)))
	projectile["position"] = next_position
	if hit.is_empty():
		survivors.append(projectile)
		return projectile
	resolve_projectile_hit(runtime, projectile, hit, router, default_start)
	var hit_targets: Array = projectile.get("hit_targets", [])
	hit_targets.append(String(hit.get("id", "")))
	projectile["hit_targets"] = hit_targets
	if int(projectile.get("pierce_remaining", 0)) > 0:
		projectile["pierce_remaining"] = int(projectile.get("pierce_remaining", 0)) - 1
		survivors.append(projectile)
	return projectile


static func service_spawn_projectile(
	runtime: CombatRuntime, command: Dictionary, event: CombatEvent, default_start: Vector2, projectile_max_age: float
) -> void:
	var spawn_delay := projectile_spawn_delay(command, event)
	if spawn_delay > 0.0:
		queue_pending_projectile_spawn(runtime, command, event, spawn_delay)
		command["queued"] = true
		command["delay"] = spawn_delay
		return
	spawn_projectile_from_command(runtime, command, event.payload, event.event_type, default_start, projectile_max_age)


static func projectile_spawn_delay(command: Dictionary, event: CombatEvent) -> float:
	return COMBAT_PROJECTILE_FACTORY.projectile_spawn_delay(command, event)


static func queue_pending_projectile_spawn(runtime: CombatRuntime, command: Dictionary, event: CombatEvent, delay: float) -> void:
	(
		runtime
		. pending_projectile_spawns
		. append(
			{
				"timer": delay,
				"command": command.duplicate(true),
				"payload": event.payload.duplicate(true),
				"event_type": event.event_type,
			}
		)
	)


static func spawn_projectile_from_command(
	runtime: CombatRuntime,
	command: Dictionary,
	payload: Dictionary,
	event_type: StringName,
	default_start: Vector2,
	projectile_max_age: float
) -> void:
	runtime._log_combat_command(command)
	var target_context := projectile_target_context(command, payload, event_type, default_start)
	var target := runtime._select_target(
		String(command.get("target_rule", "nearest_to_wall")), [], int(command.get("index", 0)), target_context
	)
	if target.is_empty():
		command["blocked"] = true
		command["reason"] = "no_target"
		return
	var projectile := new_projectile(runtime, command, payload, target, default_start, projectile_max_age)
	if String(projectile.get("travel_mode", "")) == "instant":
		add_instant_projectile_effect(runtime, projectile, target, default_start)
		resolve_projectile_hit(runtime, projectile, target, runtime.state.combat_router, default_start)
	else:
		runtime.active_projectiles.append(projectile)


static func projectile_target_context(
	command: Dictionary, payload: Dictionary, event_type: StringName, default_start: Vector2
) -> Dictionary:
	return COMBAT_PROJECTILE_FACTORY.projectile_target_context(command, payload, event_type, default_start)


static func new_projectile(
	runtime: CombatRuntime, command: Dictionary, payload: Dictionary, target: Dictionary, default_start: Vector2, projectile_max_age: float
) -> Dictionary:
	return COMBAT_PROJECTILE_FACTORY.new_projectile(runtime, command, payload, target, default_start, projectile_max_age)


static func command_origin(command: Dictionary, payload: Dictionary, default_start: Vector2) -> Vector2:
	return COMBAT_PROJECTILE_FACTORY.command_origin(command, payload, default_start)


static func add_instant_projectile_effect(
	runtime: CombatRuntime, projectile: Dictionary, target: Dictionary, default_start: Vector2
) -> void:
	var projectile_id := String(projectile.get("projectile_id", "projectile"))
	if projectile_id.find("electro") == -1:
		return
	var payload: Dictionary = projectile.get("payload", {}) as Dictionary
	var end_position: Vector2 = target.get("position", default_start)
	var area_radius := runtime._combat_radius(float(payload.get("explosion_radius", 1.0)))
	(
		runtime
		. _add_combat_effect(
			end_position,
			projectile_id,
			float(payload.get("pierce_damage", 0.0)),
			{
				"start_position": Vector2(end_position.x, 120.0),
				"end_position": end_position,
				"area_radius": area_radius,
				"target_rule": String(projectile.get("target_rule", "nearest_to_wall")),
				"target_id": String(target.get("id", "")),
			}
		)
	)


static func resolve_projectile_hit(
	runtime: CombatRuntime, projectile: Dictionary, target: Dictionary, router: TriggerRouter, default_start: Vector2
) -> void:
	var event_id := StringName(projectile.get("on_hit_event_id", &""))
	if event_id == &"" or router == null:
		return
	var payload: Dictionary = (projectile.get("payload", {}) as Dictionary).duplicate(true)
	payload["hit_target"] = String(target.get("id", ""))
	payload["hit_position"] = target.get("position", default_start)
	payload["is_first_hit"] = (projectile.get("hit_targets", []) as Array).is_empty()
	var event := CombatEvent.create(
		CombatEvent.TYPE_HIT, event_id, StringName(projectile.get("projectile_id", "projectile")), &"player", payload
	)
	var commands := router.route(event, runtime._combat_services())
	if runtime.state != null:
		runtime.state._on_combat_projectile_hit_resolved(event.payload, commands)
