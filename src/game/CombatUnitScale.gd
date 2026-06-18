extends RefCounted
class_name CombatUnitScale


static func radius(value: float) -> float:
	if value <= 10.0:
		return value * 92.0
	return value


static func projectile_speed(value: float) -> float:
	if value <= 50.0:
		return value * 40.0
	return value
