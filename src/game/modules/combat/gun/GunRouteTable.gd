extends RefCounted
class_name GunRouteTable

const CAST_ROUTES := preload("res://src/game/modules/combat/gun/GunCastRoutes.gd")
const HIT_ROUTES := preload("res://src/game/modules/combat/gun/GunHitRoutes.gd")
const RESOLVED_ROUTES := preload("res://src/game/modules/combat/gun/GunResolvedRoutes.gd")


static func get_routes(event_ids: Dictionary) -> Dictionary:
	return {
		CombatEvent.TYPE_CAST: CAST_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_HIT: HIT_ROUTES.get_routes(event_ids),
		CombatEvent.TYPE_RESOLVED: RESOLVED_ROUTES.get_routes(event_ids),
	}
