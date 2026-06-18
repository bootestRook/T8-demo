extends RefCounted
class_name CombatMonsterCatalog

const DEFAULT_MONSTER_SPECS := {
	"grunt": {"hp": 90.0, "speed": 56.0, "damage": 18, "attack_interval": 1.4, "exp": 16, "radius": 24.0},
	"runner": {"hp": 70.0, "speed": 92.0, "damage": 14, "attack_interval": 1.0, "exp": 18, "radius": 21.0},
	"brute": {"hp": 230.0, "speed": 34.0, "damage": 34, "attack_interval": 1.8, "exp": 42, "radius": 34.0},
	"elite": {"hp": 650.0, "speed": 28.0, "damage": 52, "attack_interval": 1.8, "exp": 110, "radius": 42.0},
	"boss": {"hp": 1800.0, "speed": 20.0, "damage": 80, "attack_interval": 2.0, "exp": 300, "radius": 58.0},
}


static func get_spec(monster_id: String) -> Dictionary:
	var custom := ContentUnits.get_monster_spec(monster_id)
	if not custom.is_empty():
		return custom
	return (DEFAULT_MONSTER_SPECS.get(monster_id, DEFAULT_MONSTER_SPECS["grunt"]) as Dictionary).duplicate(true)
