extends RefCounted
class_name GunResolvedRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["bullet_explosion"]: _bullet_explosion_routes(),
		event_ids["bullet_split"]: _bullet_split_routes(event_ids),
	}


static func _bullet_explosion_routes() -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_QUERY_TARGETS,
			"query": &"circle",
			"center_key": "hit_position",
			"radius_key": "bullet_explosion_radius",
			"store_as": &"explosion_targets",
		},
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"bullet_explosion",
			"element": &"physical",
			"amount_key": "bullet_explosion_damage",
			"target_key": "explosion_targets",
		},
	]


static func _bullet_split_routes(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
			"projectile_id": &"split_bullet",
			"count_key": "split_count",
			"origin_key": "hit_position",
			"mode_key": "split_mode",
			"on_hit_event_id": event_ids["split_bullet_hit"],
			"speed": 920.0,
		},
	]
