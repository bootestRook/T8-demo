extends RefCounted
class_name GunHitRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		event_ids["bullet_hit"]: _bullet_hit_routes(event_ids),
		event_ids["split_bullet_hit"]: _split_bullet_hit_routes(),
	}


static func _bullet_hit_routes(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"bullet",
			"element": &"physical",
			"amount_key": "bullet_damage",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"requires_tag": &"bullet_explosion",
			"tag_list_key": "on_hit_effects",
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["bullet_explosion"],
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"requires_tag": &"split_bullet",
			"tag_list_key": "on_hit_effects",
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["bullet_split"],
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"requires_tag": &"split_bullet_four_way",
			"tag_list_key": "on_hit_effects",
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["bullet_split"],
			"payload": {"split_count": 4, "split_mode": &"four_direction"},
		},
	]


static func _split_bullet_hit_routes() -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"split_bullet",
			"element": &"physical",
			"amount_key": "split_bullet_damage",
			"target_key": "hit_target",
		},
	]
