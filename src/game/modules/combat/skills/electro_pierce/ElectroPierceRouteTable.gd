extends RefCounted
class_name ElectroPierceRouteTable

const CAST_ROUTES := preload("res://src/game/modules/combat/skills/electro_pierce/ElectroPierceCastRoutes.gd")
const HIT_ROUTES := preload("res://src/game/modules/combat/skills/electro_pierce/ElectroPierceHitRoutes.gd")
const RESOLVED_ROUTES := preload("res://src/game/modules/combat/skills/electro_pierce/ElectroPierceResolvedRoutes.gd")
const TICK_ROUTES := preload("res://src/game/modules/combat/skills/electro_pierce/ElectroPierceTickRoutes.gd")


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		CombatEvent.TYPE_CAST: CAST_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_HIT: HIT_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_RESOLVED: RESOLVED_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_TICK: TICK_ROUTES.get_routes(event_ids),
	}
