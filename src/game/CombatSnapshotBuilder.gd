extends RefCounted
class_name CombatSnapshotBuilder


static func build(runtime: CombatRuntime) -> Dictionary:
	return {
		"active_monsters": runtime.active_monsters.duplicate(true),
		"active_projectiles": runtime.active_projectiles.duplicate(true),
		"pending_projectile_spawns": runtime.pending_projectile_spawns.duplicate(true),
		"active_areas": runtime.active_areas.duplicate(true),
		"active_spawn_groups": runtime.active_spawn_groups.duplicate(true),
		"combat_effects": runtime.combat_effects.duplicate(true),
		"combat_command_log": runtime.combat_command_log.duplicate(true),
	}
