extends RefCounted
class_name DryIceEvents

const ROUTE_TABLE := preload("res://src/game/modules/combat/skills/dry_ice/DryIceRouteTable.gd")

const CAST := &"dry_ice.cast"
const HIT := &"dry_ice.hit"
const FIRST_HIT := &"dry_ice.first_hit"
const SMALL_ICE_HIT := &"dry_ice.small_ice_hit"


static func get_routes() -> Dictionary:
	return ROUTE_TABLE.get_routes(_event_ids())


static func _event_ids() -> Dictionary:
	return {
		"cast": CAST,
		"hit": HIT,
		"first_hit": FIRST_HIT,
		"small_ice_hit": SMALL_ICE_HIT,
	}
