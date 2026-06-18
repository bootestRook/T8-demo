extends RefCounted
class_name CombatRuntime

const MONSTER_ATTACK_RANGE_Y := 1040.0
const MONSTER_SPAWN_Y := 190.0
const MONSTER_WALL_STOP_Y := MONSTER_ATTACK_RANGE_Y - 36.0
const PROJECTILE_START := Vector2(549.0, 1235.0)
const PROJECTILE_MAX_AGE := 3.0
const COMBAT_AREA_RUNTIME := preload("res://src/game/CombatAreaRuntime.gd")
const COMBAT_COMMAND_PAYLOAD := preload("res://src/game/CombatCommandPayload.gd")
const COMBAT_COMMAND_RUNTIME := preload("res://src/game/CombatCommandRuntime.gd")
const COMBAT_DAMAGE_RUNTIME := preload("res://src/game/CombatDamageRuntime.gd")
const COMBAT_EFFECT_LOG := preload("res://src/game/CombatEffectLog.gd")
const COMBAT_MONSTER_RUNTIME := preload("res://src/game/CombatMonsterRuntime.gd")
const COMBAT_MONSTER_CATALOG := preload("res://src/game/CombatMonsterCatalog.gd")
const COMBAT_PROJECTILE_RUNTIME := preload("res://src/game/CombatProjectileRuntime.gd")
const COMBAT_SNAPSHOT_BUILDER := preload("res://src/game/CombatSnapshotBuilder.gd")
const COMBAT_SPAWN_RUNTIME := preload("res://src/game/CombatSpawnRuntime.gd")
const COMBAT_TARGET_SELECTOR := preload("res://src/game/CombatTargetSelector.gd")
const COMBAT_UNIT_SCALE := preload("res://src/game/CombatUnitScale.gd")

var state: Node = null
var active_monsters: Array = []
var active_projectiles: Array = []
var pending_projectile_spawns: Array = []
var active_areas: Array = []
var active_spawn_groups: Array = []
var combat_effects: Array = []
var combat_command_log: Array = []
var next_combat_entity_id := 1


func setup(owner_state: Node) -> void:
	state = owner_state
	reset()


func reset() -> void:
	randomize()
	active_monsters.clear()
	active_projectiles.clear()
	pending_projectile_spawns.clear()
	active_areas.clear()
	active_spawn_groups.clear()
	combat_effects.clear()
	combat_command_log.clear()
	next_combat_entity_id = 1


func tick(delta: float, router: TriggerRouter) -> void:
	_update_spawn_groups(delta)
	_update_monsters(delta)
	_update_pending_projectile_spawns(delta)
	_update_projectiles(delta, router)
	_update_areas(delta, router)
	_update_combat_effects(delta)


func route_event(event: CombatEvent, router: TriggerRouter) -> Array:
	if router == null or event == null:
		return []
	return router.route(event, _combat_services())


func has_living_targets() -> bool:
	return not _alive_monsters_sorted_by_wall().is_empty()


func has_target_in_cast_range(target_radius: float, target_center: Vector2 = PROJECTILE_START) -> bool:
	var context := {"target_radius": target_radius, "target_center": target_center}
	return not _targets_matching_context_range(_alive_monsters_sorted_by_wall(), [], context).is_empty()


func spawn_wave(wave: Dictionary) -> void:
	COMBAT_SPAWN_RUNTIME.spawn_wave(self, wave)


func _start_spawn_group(spawn_config: Dictionary, spawn_offset: int) -> void:
	COMBAT_SPAWN_RUNTIME.start_spawn_group(self, spawn_config, spawn_offset)


func _update_spawn_groups(delta: float) -> void:
	active_spawn_groups = COMBAT_SPAWN_RUNTIME.update_spawn_groups(self, delta)


func _resolve_spawn_group_ticks(group: Dictionary) -> Dictionary:
	return COMBAT_SPAWN_RUNTIME.resolve_spawn_group_ticks(self, group)


func _spawn_group_batch(spawn_config: Dictionary, spawn_offset: int, start_index: int, batch_count: int, total_count: int) -> void:
	COMBAT_SPAWN_RUNTIME.spawn_group_batch(self, spawn_config, spawn_offset, start_index, batch_count, total_count)


func get_snapshot() -> Dictionary:
	return COMBAT_SNAPSHOT_BUILDER.build(self)


func _spawn_monster(monster_id: String, local_index: int, global_index: int, group_count: int, spawn_config: Dictionary = {}) -> void:
	COMBAT_SPAWN_RUNTIME.spawn_monster(self, monster_id, local_index, global_index, group_count, spawn_config)


func _spawn_position(local_index: int, global_index: int, group_count: int, spawn_config: Dictionary, spec: Dictionary) -> Vector2:
	return COMBAT_SPAWN_RUNTIME.spawn_position(local_index, global_index, group_count, spawn_config, spec)


func _spawn_distribution(spawn_config: Dictionary, spec: Dictionary) -> String:
	return COMBAT_SPAWN_RUNTIME.spawn_distribution(spawn_config, spec)


func _boss_spawn_position(global_index: int) -> Vector2:
	return COMBAT_SPAWN_RUNTIME.boss_spawn_position(global_index)


func _uniform_spawn_position(local_index: int, global_index: int, group_count: int) -> Vector2:
	return COMBAT_SPAWN_RUNTIME.uniform_spawn_position(local_index, global_index, group_count)


func _regional_random_spawn_position(global_index: int, start_ratio: float, end_ratio: float) -> Vector2:
	return COMBAT_SPAWN_RUNTIME.regional_random_spawn_position(global_index, start_ratio, end_ratio)


func _random_unit() -> float:
	return COMBAT_SPAWN_RUNTIME.random_unit()


func _spawn_coef(spawn_config: Dictionary, key: String) -> float:
	return COMBAT_SPAWN_RUNTIME.spawn_coef(spawn_config, key)


func _wave_hp_coef(spawn_config: Dictionary) -> float:
	return COMBAT_SPAWN_RUNTIME.wave_hp_coef(spawn_config)


func _monster_spec(monster_id: String) -> Dictionary:
	return COMBAT_MONSTER_CATALOG.get_spec(monster_id)


func _update_monsters(delta: float) -> void:
	active_monsters = COMBAT_MONSTER_RUNTIME.update_monsters(self, delta, MONSTER_WALL_STOP_Y)


func _update_monster_attack(monster: Dictionary, delta: float) -> Dictionary:
	return COMBAT_MONSTER_RUNTIME.update_monster_attack(self, monster, delta)


func _update_statuses(monster: Dictionary, delta: float) -> void:
	COMBAT_DAMAGE_RUNTIME.update_statuses(self, monster, delta)


func _tick_status_damage(monster: Dictionary, status: Dictionary, key: String, delta: float) -> void:
	COMBAT_DAMAGE_RUNTIME.tick_status_damage(self, monster, status, key, delta)


func _monster_speed_mul(monster: Dictionary) -> float:
	return COMBAT_DAMAGE_RUNTIME.monster_speed_mul(monster)


func _update_projectiles(delta: float, router: TriggerRouter) -> void:
	active_projectiles = COMBAT_PROJECTILE_RUNTIME.update_projectiles(self, delta, router, PROJECTILE_START, PROJECTILE_MAX_AGE)


func _update_pending_projectile_spawns(delta: float) -> void:
	pending_projectile_spawns = COMBAT_PROJECTILE_RUNTIME.update_pending_projectile_spawns(
		self, delta, PROJECTILE_START, PROJECTILE_MAX_AGE
	)


func _advance_projectile(projectile: Dictionary, delta: float, router: TriggerRouter, survivors: Array) -> Dictionary:
	return COMBAT_PROJECTILE_RUNTIME.advance_projectile(self, projectile, delta, router, survivors, PROJECTILE_START)


func _advance_linear_pierce_projectile(projectile: Dictionary, delta: float, router: TriggerRouter, survivors: Array) -> Dictionary:
	return COMBAT_PROJECTILE_RUNTIME.advance_linear_pierce_projectile(self, projectile, delta, router, survivors, PROJECTILE_START)


func _update_areas(delta: float, router: TriggerRouter) -> void:
	active_areas = COMBAT_AREA_RUNTIME.update_areas(self, delta, router, PROJECTILE_START)


func _update_combat_effects(delta: float) -> void:
	combat_effects = COMBAT_EFFECT_LOG.update_effects(combat_effects, delta)


func _combat_services() -> Dictionary:
	return {
		EffectExecutor.TYPE_SPAWN_PROJECTILE: Callable(self, "_service_spawn_projectile"),
		EffectExecutor.TYPE_SPAWN_AREA: Callable(self, "_service_spawn_area"),
		EffectExecutor.TYPE_QUERY_TARGETS: Callable(self, "_service_query_targets"),
		EffectExecutor.TYPE_DEAL_DAMAGE: Callable(self, "_service_deal_damage"),
		EffectExecutor.TYPE_APPLY_STATUS: Callable(self, "_service_apply_status"),
		EffectExecutor.TYPE_KNOCKBACK: Callable(self, "_service_knockback"),
	}


func _service_spawn_projectile(command: Dictionary, event: CombatEvent) -> void:
	COMBAT_PROJECTILE_RUNTIME.service_spawn_projectile(self, command, event, PROJECTILE_START, PROJECTILE_MAX_AGE)


func _projectile_spawn_delay(command: Dictionary, event: CombatEvent) -> float:
	return COMBAT_PROJECTILE_RUNTIME.projectile_spawn_delay(command, event)


func _queue_pending_projectile_spawn(command: Dictionary, event: CombatEvent, delay: float) -> void:
	COMBAT_PROJECTILE_RUNTIME.queue_pending_projectile_spawn(self, command, event, delay)


func _spawn_projectile_from_command(command: Dictionary, payload: Dictionary, event_type: StringName) -> void:
	COMBAT_PROJECTILE_RUNTIME.spawn_projectile_from_command(self, command, payload, event_type, PROJECTILE_START, PROJECTILE_MAX_AGE)


func _projectile_target_context(command: Dictionary, payload: Dictionary, event_type: StringName) -> Dictionary:
	return COMBAT_PROJECTILE_RUNTIME.projectile_target_context(command, payload, event_type, PROJECTILE_START)


func _new_projectile(command: Dictionary, payload: Dictionary, target: Dictionary) -> Dictionary:
	return COMBAT_PROJECTILE_RUNTIME.new_projectile(self, command, payload, target, PROJECTILE_START, PROJECTILE_MAX_AGE)


func apply_status_to_nearest_wall(count: int, status_id: String, duration: float, extra: Dictionary = {}) -> int:
	var targets := _alive_monsters_sorted_by_wall()
	return _apply_status_to_target_list(targets, count, status_id, duration, extra)


func apply_status_to_all_living(status_id: String, duration: float, extra: Dictionary = {}) -> int:
	var targets := _alive_monsters_sorted_by_wall()
	return _apply_status_to_target_list(targets, targets.size(), status_id, duration, extra)


func _command_origin(command: Dictionary, payload: Dictionary) -> Vector2:
	return COMBAT_PROJECTILE_RUNTIME.command_origin(command, payload, PROJECTILE_START)


func _add_instant_projectile_effect(projectile: Dictionary, target: Dictionary) -> void:
	COMBAT_PROJECTILE_RUNTIME.add_instant_projectile_effect(self, projectile, target, PROJECTILE_START)


func _service_spawn_area(command: Dictionary, event: CombatEvent) -> void:
	_log_combat_command(command)
	COMBAT_AREA_RUNTIME.spawn_area(self, command, event, PROJECTILE_START)


func _service_query_targets(command: Dictionary, event: CombatEvent) -> void:
	COMBAT_COMMAND_RUNTIME.service_query_targets(self, command, event, PROJECTILE_START)


func _service_deal_damage(command: Dictionary, event: CombatEvent) -> void:
	COMBAT_DAMAGE_RUNTIME.service_deal_damage(self, command, event)


func _service_apply_status(command: Dictionary, _event: CombatEvent) -> void:
	COMBAT_DAMAGE_RUNTIME.service_apply_status(self, command, _event)


func _service_knockback(command: Dictionary, _event: CombatEvent) -> void:
	COMBAT_COMMAND_RUNTIME.service_knockback(self, command, _event, MONSTER_SPAWN_Y)


func _route_area_tick(area: Dictionary, router: TriggerRouter) -> void:
	COMBAT_AREA_RUNTIME.route_area_tick(self, area, router, PROJECTILE_START)


func _resolve_projectile_hit(projectile: Dictionary, target: Dictionary, router: TriggerRouter) -> void:
	COMBAT_PROJECTILE_RUNTIME.resolve_projectile_hit(self, projectile, target, router, PROJECTILE_START)


func _select_target(rule: String, excluded: Array = [], offset: int = 0, context: Dictionary = {}) -> Dictionary:
	return COMBAT_TARGET_SELECTOR.select_target(active_monsters, rule, excluded, offset, context, PROJECTILE_START, 48.0)


func _select_offset_candidate(candidates: Array, offset: int) -> Dictionary:
	return COMBAT_TARGET_SELECTOR.select_offset_candidate(candidates, offset)


func _select_random_offset_candidate(candidates: Array, offset: int, context: Dictionary) -> Dictionary:
	return COMBAT_TARGET_SELECTOR.select_random_offset_candidate(candidates, offset, context)


func _targets_matching_context_range(candidates: Array, excluded: Array, context: Dictionary) -> Array:
	return COMBAT_TARGET_SELECTOR.targets_matching_context_range(candidates, excluded, context, PROJECTILE_START, 48.0)


func _is_monster_in_context_range(monster: Dictionary, context: Dictionary) -> bool:
	return COMBAT_TARGET_SELECTOR.is_monster_in_context_range(monster, context, PROJECTILE_START, 48.0)


func _alive_monsters_sorted_by_wall() -> Array:
	return COMBAT_TARGET_SELECTOR.alive_monsters_sorted_by_wall(active_monsters)


func _sort_by_wall(a: Dictionary, b: Dictionary) -> bool:
	return COMBAT_TARGET_SELECTOR.sort_by_wall(a, b)


func _sort_by_distance_to_point(a: Dictionary, b: Dictionary, point: Vector2) -> bool:
	return COMBAT_TARGET_SELECTOR.sort_by_distance_to_point(a, b, point)


func _targets_in_radius(center: Vector2, radius: float) -> Array:
	return COMBAT_TARGET_SELECTOR.targets_in_radius(active_monsters, center, radius)


func _first_monster_on_segment(start: Vector2, end: Vector2, excluded: Array, width: float) -> Dictionary:
	return COMBAT_TARGET_SELECTOR.first_monster_on_segment(active_monsters, start, end, excluded, width)


func _command_targets(command: Dictionary) -> Array:
	return COMBAT_COMMAND_PAYLOAD.command_targets(command)


func _explosion_effect_center(event: CombatEvent) -> Vector2:
	return COMBAT_COMMAND_PAYLOAD.explosion_effect_center(event, PROJECTILE_START)


func _explosion_effect_radius(command: Dictionary, event: CombatEvent) -> float:
	return _combat_radius(COMBAT_COMMAND_PAYLOAD.explosion_radius_value(command, event))


func _damage_monster(monster_id: String, amount: float, kind: String, effect_extra: Dictionary = {}) -> void:
	COMBAT_DAMAGE_RUNTIME.damage_monster(self, monster_id, amount, kind, effect_extra)


func _monster_damage_taken_mul(monster: Dictionary) -> float:
	return COMBAT_DAMAGE_RUNTIME.monster_damage_taken_mul(monster)


func _apply_status_to_target_list(targets: Array, count: int, status_id: String, duration: float, extra: Dictionary = {}) -> int:
	return COMBAT_DAMAGE_RUNTIME.apply_status_to_target_list(self, targets, count, status_id, duration, extra)


func _apply_status_to_monster(monster_id: String, status_id: String, command: Dictionary) -> void:
	COMBAT_DAMAGE_RUNTIME.apply_status_to_monster(self, monster_id, status_id, command)


func _monster_by_id(monster_id: String) -> Dictionary:
	return COMBAT_MONSTER_RUNTIME.monster_by_id(active_monsters, monster_id)


func _monster_index_by_id(monster_id: String) -> int:
	return COMBAT_MONSTER_RUNTIME.monster_index_by_id(active_monsters, monster_id)


func _on_monster_defeated(monster: Dictionary) -> void:
	COMBAT_MONSTER_RUNTIME.on_monster_defeated(self, monster)


func _gain_exp_from_kill(amount: int) -> void:
	COMBAT_MONSTER_RUNTIME.gain_exp_from_kill(self, amount)


func _combat_radius(value: float) -> float:
	return COMBAT_UNIT_SCALE.radius(value)


func _combat_projectile_speed(value: float) -> float:
	return COMBAT_UNIT_SCALE.projectile_speed(value)


func _next_entity_id(prefix: String) -> String:
	var result := "%s_%d" % [prefix, next_combat_entity_id]
	next_combat_entity_id += 1
	return result


func _add_combat_effect(position: Vector2, kind: String, amount: float, extra: Dictionary = {}) -> void:
	COMBAT_EFFECT_LOG.add_effect(combat_effects, _next_entity_id("effect"), position, kind, amount, extra)


func _damage_element_for_kind(kind: String, explicit_element: String, source_id: String) -> String:
	return COMBAT_DAMAGE_RUNTIME.damage_element_for_kind(kind, explicit_element, source_id)


func _is_critical_damage(command: Dictionary, event: CombatEvent) -> bool:
	return COMBAT_DAMAGE_RUNTIME.is_critical_damage(command, event)


func _log_combat_command(command: Dictionary) -> void:
	var elapsed_time := 0.0
	if state != null:
		elapsed_time = state.elapsed_time
	COMBAT_EFFECT_LOG.log_command(combat_command_log, command, elapsed_time)
