extends RefCounted
class_name ElectroPierceTickRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var matrix_tick: StringName = event_ids["matrix_tick"]
	return {
		matrix_tick:
		[
			{
				"type": EffectExecutor.TYPE_QUERY_TARGETS,
				"query": &"circle",
				"center_key": "area_center",
				"radius_key": "area_radius",
				"store_as": &"area_targets",
			},
			{
				"type": EffectExecutor.TYPE_DEAL_DAMAGE,
				"damage_kind": &"matrix",
				"element": &"electric",
				"amount_key": "matrix_tick_damage",
				"target_key": "area_targets",
			},
			{
				"type": EffectExecutor.TYPE_APPLY_STATUS,
				"status_id": &"slow",
				"duration_key": "matrix_slow_duration",
				"slow_mul_key": "matrix_slow_mul",
				"target_key": "area_targets",
			},
		],
	}
