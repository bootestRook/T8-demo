extends RefCounted
class_name GunCastRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["fire"]:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"projectile_id": &"gun_bullet",
				"count_key": "gun_projectile_count",
				"target_rule": &"nearest_to_wall",
				"on_hit_event_id": event_ids["bullet_hit"],
				"speed": 920.0,
			},
		],
	}
