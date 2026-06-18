extends RefCounted
class_name ThermobaricResolvedRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["explosion_end"]:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"requires_flag": "spawn_sparks_enabled",
				"projectile_id": &"thermobaric_spark",
				"count_key": "spark_count",
				"origin_key": "hit_position",
				"target_rule": &"near_explosion_unhit_first",
				"on_hit_event_id": event_ids["spark_hit"],
			},
		],
	}
