extends RefCounted
class_name ElectroPierceResolvedRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var explosion: StringName = event_ids["explosion"]
	var explosion_end: StringName = event_ids["explosion_end"]
	return {
		explosion: _explosion_effects(event_ids),
		explosion_end: _explosion_end_effects(event_ids),
	}


static func _explosion_effects(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_QUERY_TARGETS,
			"query": &"circle",
			"center_key": "hit_position",
			"radius_key": "explosion_radius",
			"store_as": &"explosion_targets",
		},
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"explosion",
			"element": &"electric",
			"amount_key": "explosion_damage",
			"target_key": "explosion_targets",
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["explosion_end"],
		},
	]


static func _explosion_end_effects(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_SPAWN_AREA,
			"requires_flag": "matrix_enabled",
			"area_id": &"electro_matrix",
			"center_key": "hit_position",
			"radius_key": "explosion_radius",
			"duration_key": "matrix_duration",
			"tick_interval_key": "matrix_tick_interval",
			"on_tick_event_id": event_ids["matrix_tick"],
		},
	]
