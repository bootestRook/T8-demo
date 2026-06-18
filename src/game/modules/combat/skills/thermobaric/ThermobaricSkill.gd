extends RefCounted
class_name ThermobaricSkill

const SKILL_ID := &"thermobaric"


static func register(router: TriggerRouter) -> void:
	router.register_routes(ThermobaricEvents.get_routes())


static func default_payload() -> Dictionary:
	return {
		"skill_id": SKILL_ID,
		"projectile_count": 1,
		"release_count": 1,
		"release_interval": 0.15,
		"target_radius": 1100.0,
		"projectile_speed": 16.0,
		"impact_damage": 125.0,
		"explosion_damage": 100.0,
		"explosion_radius": 1.1,
		"knockback_distance": 0.7,
		"burn_enabled": false,
		"burn_duration": 2.0,
		"burn_total_damage": 60.0,
		"burn_total_damage_max_hp_ratio": 0.0,
		"spawn_sparks_enabled": false,
		"spark_count": 1,
		"spark_damage": 35.0,
	}


static func build_cast_event(owner_id: StringName, payload: Dictionary = {}) -> CombatEvent:
	var merged := default_payload()
	for key in payload.keys():
		merged[key] = payload[key]
	return CombatEvent.create(CombatEvent.TYPE_CAST, ThermobaricEvents.CAST, SKILL_ID, owner_id, merged)
