extends RefCounted
class_name DryIceHitRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var hit: StringName = event_ids["hit"]
	var small_ice_hit: StringName = event_ids["small_ice_hit"]
	return {
		hit: _hit_effects(event_ids),
		small_ice_hit: _small_ice_hit_effects(),
	}


static func _hit_effects(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"projectile",
			"element": &"ice",
			"amount_key": "damage",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_KNOCKBACK,
			"mode": &"away_from_wall",
			"distance_key": "knockback_distance",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_APPLY_STATUS,
			"requires_flag": "freeze_enabled",
			"status_id": &"freeze",
			"duration_key": "freeze_duration",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_APPLY_STATUS,
			"requires_flag": "frostbite_enabled",
			"status_id": &"frostbite",
			"duration_key": "frostbite_duration",
			"tick_damage_key": "frostbite_tick_damage",
			"max_stack_key": "frostbite_max_stack",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"requires_payload": {"is_first_hit": true},
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["first_hit"],
		},
	]


static func _small_ice_hit_effects() -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"small_ice",
			"element": &"ice",
			"amount_key": "small_ice_damage",
			"target_key": "hit_target",
		},
	]
