extends RefCounted
class_name DryIceSkill

const SKILL_ID := &"dry_ice"


static func register(router: TriggerRouter) -> void:
	router.register_routes(DryIceEvents.get_routes())


static func default_payload() -> Dictionary:
	return {
		"skill_id": SKILL_ID,
		"projectile_count": 1,
		"release_count": 1,
		"release_interval": 0.18,
		"target_radius": 950.0,
		"projectile_speed": 18.0,
		"damage": 90.0,
		"pierce_count": 3,
		"knockback_distance": 0.25,
		"freeze_enabled": false,
		"freeze_duration": 2.0,
		"frostbite_enabled": false,
		"frostbite_duration": 10.0,
		"frostbite_tick_damage": 2.7,
		"frostbite_max_stack": 5,
		"split_on_first_hit": false,
		"small_ice_count": 3,
		"small_ice_damage": 45.0,
		"small_ice_pierce_count": 1,
	}


static func build_cast_event(owner_id: StringName, payload: Dictionary = {}) -> CombatEvent:
	var merged := default_payload()
	for key in payload.keys():
		merged[key] = payload[key]
	return CombatEvent.create(CombatEvent.TYPE_CAST, DryIceEvents.CAST, SKILL_ID, owner_id, merged)
