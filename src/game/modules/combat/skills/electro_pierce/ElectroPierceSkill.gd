extends RefCounted
class_name ElectroPierceSkill

const SKILL_ID := &"electro_pierce"


static func register(router: TriggerRouter) -> void:
	router.register_routes(ElectroPierceEvents.get_routes())


static func default_payload() -> Dictionary:
	return {
		"skill_id": SKILL_ID,
		"projectile_count": 1,
		"release_count": 1,
		"release_interval": 0.18,
		"target_radius": 800.0,
		"pierce_damage": 100.0,
		"paralyze_duration": 0.3,
		"explosion_enabled": false,
		"explosion_damage": 55.0,
		"explosion_radius": 1.0,
		"matrix_enabled": false,
		"matrix_duration": 1.0,
		"matrix_tick_interval": 0.5,
		"matrix_tick_damage": 10.0,
		"matrix_slow_duration": 0.6,
		"matrix_slow_mul": 0.65,
		"fission_enabled": false,
		"particle_count": 2,
		"particle_pierce_count": 5,
		"particle_damage": 31.5,
	}


static func build_cast_event(owner_id: StringName, payload: Dictionary = {}) -> CombatEvent:
	var merged := default_payload()
	for key in payload.keys():
		merged[key] = payload[key]
	return CombatEvent.create(CombatEvent.TYPE_CAST, ElectroPierceEvents.CAST, SKILL_ID, owner_id, merged)
