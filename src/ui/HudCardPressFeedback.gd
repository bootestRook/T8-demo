extends RefCounted
class_name HudCardPressFeedback


static func build(
	panel: PanelContainer, index: int, is_disabled: bool, interaction: HudCardInteraction, hand_card_size: Vector2
) -> Dictionary:
	if is_disabled or interaction.dragging_card_index != -1 or index != interaction.hover_index:
		return {"weight": 0.0}
	var rect := panel.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return {"weight": 0.0}
	if not rect.has_point(interaction.pointer_position):
		return {"weight": 0.0}
	var local := interaction.pointer_position - rect.position
	local.x = clampf(local.x, 0.0, rect.size.x)
	local.y = clampf(local.y, 0.0, rect.size.y)
	var card_point := _card_point(local, rect.size, hand_card_size)
	return {
		"weight": 1.0,
		"point": card_point,
		"lift": _lift_point(card_point, hand_card_size),
		"normal": _normal(local, rect.size),
	}


static func _card_point(local: Vector2, rect_size: Vector2, hand_card_size: Vector2) -> Vector2:
	return Vector2(local.x / maxf(1.0, rect_size.x) * hand_card_size.x, local.y / maxf(1.0, rect_size.y) * hand_card_size.y)


static func _lift_point(card_point: Vector2, hand_card_size: Vector2) -> Vector2:
	var lift_point := hand_card_size * 0.5 - (card_point - hand_card_size * 0.5) * 0.78
	lift_point.x = clampf(lift_point.x, 0.0, hand_card_size.x)
	lift_point.y = clampf(lift_point.y, 0.0, hand_card_size.y)
	return lift_point


static func _normal(local: Vector2, rect_size: Vector2) -> Vector2:
	return Vector2((local.x / maxf(1.0, rect_size.x)) * 2.0 - 1.0, (local.y / maxf(1.0, rect_size.y)) * 2.0 - 1.0)
