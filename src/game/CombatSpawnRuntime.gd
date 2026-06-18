extends RefCounted
class_name CombatSpawnRuntime

const MONSTER_SPAWN_Y := 190.0
const MONSTER_SPAWN_MIN_X := 44.0
const MONSTER_SPAWN_MAX_X := 1036.0
const MONSTER_SPAWN_LANE_COUNT := 10
const MONSTER_SPAWN_ROW_STEP := 42.0
const SPAWN_DISTRIBUTION_RANDOM := "random"
const SPAWN_DISTRIBUTION_UNIFORM := "uniform"
const SPAWN_DISTRIBUTION_LEFT := "left"
const SPAWN_DISTRIBUTION_CENTER := "center"
const SPAWN_DISTRIBUTION_RIGHT := "right"
const SPAWN_DISTRIBUTION_BOSS := "boss"


static func spawn_wave(runtime: CombatRuntime, wave: Dictionary) -> void:
	var spawns: Array = wave.get("spawns", [])
	if spawns.is_empty():
		start_spawn_group(runtime, wave, 0)
		return
	var wave_index := int(wave.get("wave_index", 1))
	var spawn_offset := 0
	for item in spawns:
		if not (item is Dictionary):
			continue
		var spawn_config: Dictionary = (item as Dictionary).duplicate(true)
		if not spawn_config.has("wave_index"):
			spawn_config["wave_index"] = wave_index
		start_spawn_group(runtime, spawn_config, spawn_offset)
		spawn_offset += int(spawn_config.get("count", 1))


static func start_spawn_group(runtime: CombatRuntime, spawn_config: Dictionary, spawn_offset: int) -> void:
	var total_count := maxi(0, int(spawn_config.get("count", 1)))
	if total_count <= 0:
		return
	var first_count := mini(total_count, maxi(0, int(spawn_config.get("first_spawn_count", 1))))
	spawn_group_batch(runtime, spawn_config, spawn_offset, 0, first_count, total_count)
	var spawned_count := first_count
	if spawned_count >= total_count:
		return
	(
		runtime
		. active_spawn_groups
		. append(
			{
				"spawn_config": spawn_config.duplicate(true),
				"spawn_offset": spawn_offset,
				"spawned_count": spawned_count,
				"total_count": total_count,
				"timer": maxf(0.0, float(spawn_config.get("spawn_interval", 1.0))),
			}
		)
	)


static func update_spawn_groups(runtime: CombatRuntime, delta: float) -> Array:
	var survivors: Array = []
	for item in runtime.active_spawn_groups:
		if not (item is Dictionary):
			continue
		var group: Dictionary = item
		group["timer"] = float(group.get("timer", 0.0)) - delta
		group = resolve_spawn_group_ticks(runtime, group)
		if int(group.get("spawned_count", 0)) < int(group.get("total_count", 0)):
			survivors.append(group)
	return survivors


static func resolve_spawn_group_ticks(runtime: CombatRuntime, group: Dictionary) -> Dictionary:
	var spawn_config: Dictionary = group.get("spawn_config", {}) as Dictionary
	var interval := maxf(0.01, float(spawn_config.get("spawn_interval", 1.0)))
	while float(group.get("timer", 0.0)) <= 0.0 and int(group.get("spawned_count", 0)) < int(group.get("total_count", 0)):
		var spawned_count := int(group.get("spawned_count", 0))
		var total_count := int(group.get("total_count", 0))
		var tick_count := mini(maxi(1, int(spawn_config.get("spawn_count_per_tick", 1))), total_count - spawned_count)
		spawn_group_batch(runtime, spawn_config, int(group.get("spawn_offset", 0)), spawned_count, tick_count, total_count)
		group["spawned_count"] = spawned_count + tick_count
		group["timer"] = float(group.get("timer", 0.0)) + interval
	return group


static func spawn_group_batch(
	runtime: CombatRuntime, spawn_config: Dictionary, spawn_offset: int, start_index: int, batch_count: int, total_count: int
) -> void:
	var monster_id := String(spawn_config.get("monster_id", "grunt"))
	for index in range(batch_count):
		var local_index := start_index + index
		spawn_monster(runtime, monster_id, local_index, spawn_offset + local_index, total_count, spawn_config)


static func spawn_monster(
	runtime: CombatRuntime, monster_id: String, local_index: int, global_index: int, group_count: int, spawn_config: Dictionary = {}
) -> void:
	var spec := runtime._monster_spec(monster_id)
	var position := spawn_position(local_index, global_index, group_count, spawn_config, spec)
	var hp_value := float(spec.get("hp", 90.0)) * spawn_coef(spawn_config, "hp_coef") * wave_hp_coef(spawn_config)
	var damage_value := int(float(spec.get("damage", 18)) * spawn_coef(spawn_config, "attack_coef"))
	(
		runtime
		. active_monsters
		. append(
			{
				"id": runtime._next_entity_id("monster"),
				"monster_id": monster_id,
				"name": String(spec.get("name", monster_id)),
				"type": String(spec.get("type", "normal")),
				"type_name": String(spec.get("type_name", "")),
				"model": String(spec.get("model", "")),
				"hp": hp_value,
				"hp_max": hp_value,
				"position": position,
				"speed": float(spec.get("speed", 56.0)),
				"damage": damage_value,
				"attack_interval": float(spec.get("attack_interval", 1.4)),
				"attack_timer": float(global_index % 3) * 0.2,
				"exp": int(spec.get("exp", 16)),
				"radius": float(spec.get("radius", 24.0)),
				"skill_id": String(spec.get("skill_id", "")),
				"skill_name": String(spec.get("skill_name", "")),
				"spawn_pattern": String(spawn_config.get("spawn_pattern", "")),
				"statuses": {},
			}
		)
	)


static func spawn_position(local_index: int, global_index: int, group_count: int, spawn_config: Dictionary, spec: Dictionary) -> Vector2:
	var distribution := spawn_distribution(spawn_config, spec)
	if distribution == SPAWN_DISTRIBUTION_BOSS:
		return boss_spawn_position(global_index)
	if distribution == SPAWN_DISTRIBUTION_UNIFORM:
		return uniform_spawn_position(local_index, global_index, group_count)
	if distribution == SPAWN_DISTRIBUTION_LEFT:
		return regional_random_spawn_position(global_index, 0.0, 0.42)
	if distribution == SPAWN_DISTRIBUTION_CENTER:
		return regional_random_spawn_position(global_index, 0.30, 0.70)
	if distribution == SPAWN_DISTRIBUTION_RIGHT:
		return regional_random_spawn_position(global_index, 0.58, 1.0)
	return regional_random_spawn_position(global_index, 0.0, 1.0)


static func spawn_distribution(spawn_config: Dictionary, spec: Dictionary) -> String:
	var monster_id := String(spawn_config.get("monster_id", ""))
	var monster_type := String(spec.get("type", "normal"))
	var event := String(spawn_config.get("event", "spawn"))
	if event == "boss" or monster_id == "5000" or monster_type == "boss":
		return SPAWN_DISTRIBUTION_BOSS
	var pattern := String(spawn_config.get("spawn_pattern", "random_top"))
	if pattern == "uniform" or pattern == "uniform_top":
		return SPAWN_DISTRIBUTION_UNIFORM
	if pattern == "left" or pattern == "left_top":
		return SPAWN_DISTRIBUTION_LEFT
	if pattern == "center" or pattern == "center_top":
		return SPAWN_DISTRIBUTION_CENTER
	if pattern == "right" or pattern == "right_top":
		return SPAWN_DISTRIBUTION_RIGHT
	return SPAWN_DISTRIBUTION_RANDOM


static func boss_spawn_position(global_index: int) -> Vector2:
	var lane_count := MONSTER_SPAWN_LANE_COUNT
	var row := int(float(global_index) / float(lane_count))
	var lane := global_index % lane_count
	var boss_lane := lane - int(lane_count / 2)
	return Vector2(540.0 + float(boss_lane) * 58.0, MONSTER_SPAWN_Y - float(row) * MONSTER_SPAWN_ROW_STEP)


static func uniform_spawn_position(local_index: int, global_index: int, group_count: int) -> Vector2:
	var lane_count := mini(MONSTER_SPAWN_LANE_COUNT, maxi(1, group_count))
	var lane := local_index % lane_count
	var row := int(float(local_index) / float(lane_count)) + int(float(global_index) / float(MONSTER_SPAWN_LANE_COUNT))
	var span := MONSTER_SPAWN_MAX_X - MONSTER_SPAWN_MIN_X
	var lane_spacing := span if lane_count <= 1 else span / float(lane_count - 1)
	var row_offset := lane_spacing * 0.5 if row % 2 == 1 else 0.0
	var lane_position := float(lane) * lane_spacing + row_offset
	if lane_position > span:
		lane_position -= span
	var x := 540.0 if lane_count <= 1 else MONSTER_SPAWN_MIN_X + lane_position
	return Vector2(x, MONSTER_SPAWN_Y - float(row) * MONSTER_SPAWN_ROW_STEP)


static func regional_random_spawn_position(global_index: int, start_ratio: float, end_ratio: float) -> Vector2:
	var row := int(float(global_index) / float(MONSTER_SPAWN_LANE_COUNT))
	var span := MONSTER_SPAWN_MAX_X - MONSTER_SPAWN_MIN_X
	var region_start := MONSTER_SPAWN_MIN_X + span * start_ratio
	var region_end := MONSTER_SPAWN_MIN_X + span * end_ratio
	var x := region_start + (region_end - region_start) * random_unit()
	return Vector2(x, MONSTER_SPAWN_Y - float(row) * MONSTER_SPAWN_ROW_STEP)


static func random_unit() -> float:
	return float(randi() % 10000) / 9999.0


static func spawn_coef(spawn_config: Dictionary, key: String) -> float:
	if spawn_config.has(key):
		return float(spawn_config.get(key, 1.0))
	var level_config := ContentUnits.get_active_level_config()
	return float(level_config.get(key, 1.0))


static func wave_hp_coef(spawn_config: Dictionary) -> float:
	var wave_index := maxi(1, int(spawn_config.get("wave_index", 1)))
	return 1.0 + float(wave_index - 1) * 0.1
