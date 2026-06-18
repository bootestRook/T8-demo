extends RefCounted
class_name DryIceCastRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var cast: StringName = event_ids["cast"]
	return {
		cast:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"projectile_id": &"dry_ice",
				"count_key": "projectile_count",
				"release_interval_key": "release_interval",
				"target_rule": &"nearest_to_player_different_first",
				"travel_mode": &"linear_pierce",
				"line_width": 42.0,
				"on_hit_event_id": event_ids["hit"],
				"speed_key": "projectile_speed",
				"pierce_count_key": "pierce_count",
			},
		],
	}
