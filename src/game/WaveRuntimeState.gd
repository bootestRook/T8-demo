extends RefCounted
class_name WaveRuntimeState

const SPAWN_LOG_LIMIT := 12

var wave_configs: Array = []
var next_wave_index := 0
var active_spawn_log: Array = []
var boss_spawned := false
var boss_defeated := false


func reset() -> void:
	next_wave_index = 0
	active_spawn_log.clear()
	boss_spawned = false
	boss_defeated = false


func load_waves(default_waves: Array, content_waves: Array) -> void:
	var source_waves: Array = _to_dictionary_array(default_waves)
	if content_waves.size() > 0:
		source_waves = _to_dictionary_array(content_waves)
	wave_configs = _to_dictionary_array(source_waves)
	wave_configs.sort_custom(func(a, b) -> bool: return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))


func update(elapsed_time: float, combat_runtime: CombatRuntime) -> String:
	var status_text := ""
	while next_wave_index < wave_configs.size() and float(wave_configs[next_wave_index].get("time", 0.0)) <= elapsed_time:
		status_text = spawn_wave(wave_configs[next_wave_index], elapsed_time, combat_runtime)
		next_wave_index += 1
	return status_text


func spawn_wave(wave: Dictionary, elapsed_time: float, combat_runtime: CombatRuntime) -> String:
	var event: Dictionary = wave.duplicate(true)
	event["spawned_at"] = elapsed_time
	active_spawn_log.append(event)
	while active_spawn_log.size() > SPAWN_LOG_LIMIT:
		active_spawn_log.remove_at(0)
	if String(event.get("event", "")) == "boss":
		boss_spawned = true
	if combat_runtime != null:
		combat_runtime.spawn_wave(event)
	return "wave %s" % str(event.get("wave_index", event.get("wave_id", "unknown")))


func mark_boss_defeated() -> bool:
	if not boss_spawned:
		return false
	boss_defeated = true
	return true


func is_battle_cleared(combat_runtime: CombatRuntime) -> bool:
	if next_wave_index < wave_configs.size():
		return false
	return combat_runtime == null or not combat_runtime.has_living_targets()


func _to_dictionary_array(source: Array) -> Array:
	var result: Array = []
	for item in source:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result
