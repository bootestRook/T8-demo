extends RefCounted
class_name ThermobaricHitRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["hit"]: _impact_hit_routes(event_ids),
		event_ids["spark_hit"]: _spark_hit_routes(),
	}


static func _impact_hit_routes(event_ids: Dictionary) -> Array:
	return [
		_impact_damage_route(),
		_query_explosion_targets_route(),
		_explosion_damage_route(),
		_knockback_route(),
		_burn_status_route(),
		_explosion_end_route(event_ids),
	]


static func _spark_hit_routes() -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"spark",
			"element": &"fire",
			"amount_key": "spark_damage",
			"target_key": "hit_target",
		},
	]


static func _impact_damage_route() -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_DEAL_DAMAGE,
		"damage_kind": &"impact",
		"element": &"fire",
		"amount_key": "impact_damage",
		"target_key": "hit_target",
	}


static func _query_explosion_targets_route() -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_QUERY_TARGETS,
		"query": &"circle",
		"center_key": "hit_position",
		"radius_key": "explosion_radius",
		"store_as": &"explosion_targets",
	}


static func _explosion_damage_route() -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_DEAL_DAMAGE,
		"damage_kind": &"explosion",
		"element": &"fire",
		"amount_key": "explosion_damage",
		"target_key": "explosion_targets",
	}


static func _knockback_route() -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_KNOCKBACK,
		"mode": &"away_from_wall",
		"distance_key": "knockback_distance",
		"target_key": "explosion_targets",
	}


static func _burn_status_route() -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_APPLY_STATUS,
		"requires_flag": "burn_enabled",
		"status_id": &"burn",
		"duration_key": "burn_duration",
		"total_damage_key": "burn_total_damage",
		"total_damage_max_hp_ratio_key": "burn_total_damage_max_hp_ratio",
		"target_key": "explosion_targets",
	}


static func _explosion_end_route(event_ids: Dictionary) -> Dictionary:
	return {
		"type": EffectExecutor.TYPE_EMIT_EVENT,
		"event_type": CombatEvent.TYPE_RESOLVED,
		"event_id": event_ids["explosion_end"],
	}
