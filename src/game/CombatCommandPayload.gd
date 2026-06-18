extends RefCounted
class_name CombatCommandPayload


static func command_targets(command: Dictionary) -> Array:
	var raw: Variant = command.get("target", null)
	if raw is Array:
		return raw as Array
	if raw == null:
		return []
	return [raw]


static func explosion_effect_center(event: CombatEvent, default_center: Vector2) -> Vector2:
	var hit_position: Variant = event.payload.get("hit_position", null)
	if hit_position is Vector2:
		return hit_position
	var area_center: Variant = event.payload.get("area_center", null)
	if area_center is Vector2:
		return area_center
	return default_center


static func explosion_radius_value(command: Dictionary, event: CombatEvent) -> float:
	var radius_value := float(event.payload.get("explosion_radius", event.payload.get("bullet_explosion_radius", 1.0)))
	if command.has("radius"):
		radius_value = float(command.get("radius", radius_value))
	return radius_value
