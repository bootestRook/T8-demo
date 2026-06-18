extends RefCounted
class_name MonsterHitFlash

const DURATION := 0.5
const COOLDOWN := 0.5
const REMAINING_KEY := "hit_flash_remaining"
const COOLDOWN_KEY := "hit_flash_cooldown"


static func tick(monster: Dictionary, delta: float) -> void:
	if delta <= 0.0:
		return
	var remaining := maxf(0.0, float(monster.get(REMAINING_KEY, 0.0)) - delta)
	var cooldown := maxf(0.0, float(monster.get(COOLDOWN_KEY, 0.0)) - delta)
	if remaining > 0.0:
		monster[REMAINING_KEY] = remaining
	elif monster.has(REMAINING_KEY):
		monster.erase(REMAINING_KEY)
	if cooldown > 0.0:
		monster[COOLDOWN_KEY] = cooldown
	elif monster.has(COOLDOWN_KEY):
		monster.erase(COOLDOWN_KEY)


static func trigger(monster: Dictionary) -> void:
	if float(monster.get(COOLDOWN_KEY, 0.0)) > 0.0:
		return
	monster[REMAINING_KEY] = DURATION
	monster[COOLDOWN_KEY] = COOLDOWN


static func flash_weight(monster: Dictionary) -> float:
	return clampf(float(monster.get(REMAINING_KEY, 0.0)) / DURATION, 0.0, 1.0)


static func color_with_flash(base_color: Color, monster: Dictionary) -> Color:
	var weight := flash_weight(monster)
	return base_color.lerp(Color(1.0, 1.0, 1.0, base_color.a), weight)


static func texture_overlay_color(monster: Dictionary) -> Color:
	return Color(2.35, 2.35, 2.35, 0.72 * flash_weight(monster))
