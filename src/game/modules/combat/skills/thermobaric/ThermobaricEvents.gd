extends RefCounted
class_name ThermobaricEvents

const ROUTE_TABLE := preload("res://src/game/modules/combat/skills/thermobaric/ThermobaricRouteTable.gd")

const CAST := &"thermobaric.cast"
const HIT := &"thermobaric.hit"
const EXPLOSION_END := &"thermobaric.explosion_end"
const SPARK_HIT := &"thermobaric.spark_hit"


static func get_routes() -> Dictionary:
	return ROUTE_TABLE.get_routes(_event_ids())


static func _event_ids() -> Dictionary:
	return {
		"cast": CAST,
		"hit": HIT,
		"explosion_end": EXPLOSION_END,
		"spark_hit": SPARK_HIT,
	}
