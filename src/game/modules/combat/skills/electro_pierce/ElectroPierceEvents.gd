extends RefCounted
class_name ElectroPierceEvents

const ROUTE_TABLE := preload("res://src/game/modules/combat/skills/electro_pierce/ElectroPierceRouteTable.gd")

const CAST := &"electro_pierce.cast"
const HIT := &"electro_pierce.hit"
const EXPLOSION := &"electro_pierce.explosion"
const EXPLOSION_END := &"electro_pierce.explosion_end"
const MATRIX_TICK := &"electro_pierce.matrix_tick"
const PARTICLE_HIT := &"electro_pierce.particle_hit"


static func get_routes() -> Dictionary:
	return ROUTE_TABLE.get_routes(_event_ids())


static func _event_ids() -> Dictionary:
	return {
		"cast": CAST,
		"hit": HIT,
		"explosion": EXPLOSION,
		"explosion_end": EXPLOSION_END,
		"matrix_tick": MATRIX_TICK,
		"particle_hit": PARTICLE_HIT,
	}
