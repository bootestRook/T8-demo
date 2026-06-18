extends RefCounted
class_name DryIceResolvedRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var first_hit: StringName = event_ids["first_hit"]
	return {
		first_hit:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"requires_flag": "split_on_first_hit",
				"projectile_id": &"small_ice",
				"count_key": "small_ice_count",
				"origin_key": "hit_position",
				"pierce_count_key": "small_ice_pierce_count",
				"on_hit_event_id": event_ids["small_ice_hit"],
			},
		],
	}
