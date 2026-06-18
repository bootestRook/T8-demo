extends RefCounted
class_name ThermobaricRouteTable

const CAST_ROUTES := preload("res://src/game/modules/combat/skills/thermobaric/ThermobaricCastRoutes.gd")
const HIT_ROUTES := preload("res://src/game/modules/combat/skills/thermobaric/ThermobaricHitRoutes.gd")
const RESOLVED_ROUTES := preload("res://src/game/modules/combat/skills/thermobaric/ThermobaricResolvedRoutes.gd")


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		CombatEvent.TYPE_CAST: CAST_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_HIT: HIT_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_RESOLVED: RESOLVED_ROUTES.get_routes(event_ids),
	}
