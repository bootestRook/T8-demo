extends RefCounted
class_name HudCardReadabilityRegionFrames

const CARD_BASE_SIZE := Vector2(150.0, 266.667)
const COST_BADGE_CENTER := Vector2(20.0, 20.0)
const COST_TEXT_SIZE := Vector2(20.0, 20.0)
const COST_TEXT_VISUAL_OFFSET := Vector2(0.0, -1.6)
const CHAIN_SPARKLE_POSITIONS := [
	Vector2(4.0, 2.0),
	Vector2(28.0, 3.0),
	Vector2(25.0, 25.0),
]
const CHAIN_SPARKLE_SIZES := [
	Vector2(17.0, 17.0),
	Vector2(12.0, 12.0),
	Vector2(15.0, 15.0),
]


static func build(hand_card_size: Vector2) -> Dictionary:
	var scale := scale_for_size(hand_card_size)
	var cost_position := COST_BADGE_CENTER - COST_TEXT_SIZE * 0.5 + COST_TEXT_VISUAL_OFFSET
	return {
		"frame": _scaled_rect(Vector2.ZERO, CARD_BASE_SIZE, scale),
		"disabled_overlay": _scaled_rect(Vector2.ZERO, CARD_BASE_SIZE, scale),
		"disabled_icon": _scaled_rect(Vector2(42.0, 78.0), Vector2(66.0, 66.0), scale),
		"chain_cost_glow": _scaled_rect(Vector2(3.9, 3.4), Vector2(32.0, 32.0), scale),
		"press_fx": _scaled_rect(Vector2.ZERO, CARD_BASE_SIZE, scale),
		"cost": _scaled_rect(cost_position, COST_TEXT_SIZE, scale),
		"name": _scaled_rect(Vector2(31.7, 7.7), Vector2(110.3, 24.4), scale),
		"type": _scaled_rect(Vector2(50.0, 39.0), Vector2(86.0, 14.0), scale),
		"art": _scaled_rect(Vector2(28.3, 43.3), Vector2(93.4, 93.4), scale),
		"desc": _scaled_rect(Vector2(14.8, 160.0), Vector2(120.4, 88.0), scale),
		"school": _scaled_rect(Vector2(22.0, 244.0), Vector2(106.0, 18.0), scale),
		"font_scale": minf(scale.x, scale.y),
	}


static func chain_sparkle_frame(index: int, hand_card_size: Vector2) -> Rect2:
	var scale := scale_for_size(hand_card_size)
	var position: Vector2 = CHAIN_SPARKLE_POSITIONS[index % CHAIN_SPARKLE_POSITIONS.size()]
	var size: Vector2 = CHAIN_SPARKLE_SIZES[index % CHAIN_SPARKLE_SIZES.size()]
	return _scaled_rect(position, size, scale)


static func scale_for_size(hand_card_size: Vector2) -> Vector2:
	return Vector2(hand_card_size.x / CARD_BASE_SIZE.x, hand_card_size.y / CARD_BASE_SIZE.y)


static func _scaled_rect(base_position: Vector2, base_size: Vector2, scale: Vector2) -> Rect2:
	return Rect2(Vector2(base_position.x * scale.x, base_position.y * scale.y), Vector2(base_size.x * scale.x, base_size.y * scale.y))
