extends RefCounted
class_name ElectroPierceHitRoutes


static func get_routes(event_ids: Dictionary) -> Dictionary:
	var hit: StringName = event_ids["hit"]
	var particle_hit: StringName = event_ids["particle_hit"]
	return {
		hit: _hit_effects(event_ids),
		particle_hit: _particle_hit_effects(),
	}


static func _hit_effects(event_ids: Dictionary) -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_QUERY_TARGETS,
			"query": &"circle",
			"center_key": "hit_position",
			"radius_key": "explosion_radius",
			"store_as": &"bolt_targets",
		},
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"electro_bolt",
			"element": &"electric",
			"amount_key": "pierce_damage",
			"target_key": "bolt_targets",
		},
		{
			"type": EffectExecutor.TYPE_APPLY_STATUS,
			"status_id": &"paralyze",
			"duration_key": "paralyze_duration",
			"target_key": "hit_target",
		},
		{
			"type": EffectExecutor.TYPE_EMIT_EVENT,
			"requires_flag": "explosion_enabled",
			"event_type": CombatEvent.TYPE_RESOLVED,
			"event_id": event_ids["explosion"],
		},
		{
			"type": EffectExecutor.TYPE_SPAWN_PROJECTILE,
			"requires_flag": "fission_enabled",
			"projectile_id": &"electro_particle",
			"count_key": "particle_count",
			"origin_key": "hit_position",
			"pierce_count_key": "particle_pierce_count",
			"on_hit_event_id": event_ids["particle_hit"],
		},
	]


static func _particle_hit_effects() -> Array:
	return [
		{
			"type": EffectExecutor.TYPE_DEAL_DAMAGE,
			"damage_kind": &"particle",
			"element": &"electric",
			"amount_key": "particle_damage",
			"target_key": "hit_target",
		},
	]
