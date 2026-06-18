extends RefCounted
class_name GunEvents

const ROUTE_TABLE := preload("res://src/game/modules/combat/gun/GunRouteTable.gd")

const FIRE := &"gun.fire"
const BULLET_HIT := &"gun.bullet_hit"
const BULLET_EXPLOSION := &"gun.bullet_explosion"
const BULLET_SPLIT := &"gun.bullet_split"
const SPLIT_BULLET_HIT := &"gun.split_bullet_hit"


static func register(router: TriggerRouter) -> void:
	router.register_routes(get_routes())


static func get_routes() -> Dictionary:
	return ROUTE_TABLE.get_routes(_event_ids())


static func _event_ids() -> Dictionary:
	return {
		"fire": FIRE,
		"bullet_hit": BULLET_HIT,
		"bullet_explosion": BULLET_EXPLOSION,
		"bullet_split": BULLET_SPLIT,
		"split_bullet_hit": SPLIT_BULLET_HIT,
	}
