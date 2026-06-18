extends RefCounted
class_name ElectroPierceCastRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var cast: StringName = event_ids["cast"]
	var hit: StringName = event_ids["hit"]
	return {
		cast:
		[
			{
				"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
				"projectile_id": &"electro_pierce",
				"count_key": "projectile_count",
				"release_interval_key": "release_interval",
				"travel_mode": &"instant",
				"target_rule": &"random_in_range",
				"target_rule_key": "target_rule",
				"target_radius_key": "target_radius",
				"on_hit_event_id": hit,
			},
		],
	}
