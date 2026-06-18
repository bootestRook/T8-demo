extends RefCounted
class_name ProgressRules


static func get_exp_required_for_level(wave_configs: Array, target_level: int) -> int:
	return wave_monster_count_for_level(wave_configs, target_level)


static func wave_monster_count_for_level(wave_configs: Array, target_level: int) -> int:
	if wave_configs.is_empty():
		return 1
	var wave_position := mini(wave_configs.size() - 1, maxi(0, target_level - 1))
	var wave: Dictionary = wave_configs[wave_position] as Dictionary
	return wave_monster_count(wave)


static func wave_monster_count(wave: Dictionary) -> int:
	var spawns: Array = wave.get("spawns", [])
	if spawns.is_empty():
		return maxi(1, int(wave.get("count", 1)))
	var total := 0
	for item in spawns:
		if item is Dictionary:
			total += int((item as Dictionary).get("count", 0))
	return maxi(1, total)
