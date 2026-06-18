extends RefCounted
class_name ThermobaricCastRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["cast"]:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"projectile_id": &"thermobaric",
				"count_key": "projectile_count",
				"release_interval_key": "release_interval",
				"target_rule": &"nearest_to_player_different_first",
				"on_hit_event_id": event_ids["hit"],
				"speed_key": "projectile_speed",
			},
		],
	}
