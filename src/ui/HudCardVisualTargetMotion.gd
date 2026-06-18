extends RefCounted
class_name HudCardVisualTargetMotion


static func apply_drag_or_hover(
	target: Dictionary, index: int, interaction: HudCardInteraction, hand_layer: Control, hand_card_size: Vector2, feel_config: Dictionary
) -> void:
	if index == interaction.dragging_card_index:
		_apply_drag_target(target, interaction, hand_layer, hand_card_size, feel_config)
	elif index == interaction.hover_index or index == interaction.selected_card_index:
		_apply_hover_target(target, index, feel_config)


static func _apply_drag_target(
	target: Dictionary, interaction: HudCardInteraction, hand_layer: Control, hand_card_size: Vector2, feel_config: Dictionary
) -> void:
	var hand_origin := hand_layer.get_global_rect().position
	var target_position := interaction.pointer_position - hand_origin - hand_card_size * 0.5
	target_position.x += _feel_value(feel_config, "drag_x_offset_from_hover")
	target_position.y -= _feel_value(feel_config, "drag_height_offset")
	var target_scale: Vector2 = target["scale"]
	var drag_scale := (
		_feel_value(feel_config, "playable_position_scale_multiplier")
		if interaction.drag_playable
		else _feel_value(feel_config, "hover_scale")
	)
	var rotation_limit := _feel_value(feel_config, "dragged_rotation_amount")
	target["position"] = target_position
	target["scale"] = target_scale * drag_scale
	target["rotation"] = clampf(
		interaction.drag_velocity.x * _feel_value(feel_config, "dragged_rotation_velocity_multiplier"), -rotation_limit, rotation_limit
	)
	target["z_index"] = 500
	target["follow_speed"] = _feel_value(feel_config, "dragged_follow_speed")


static func _apply_hover_target(target: Dictionary, index: int, feel_config: Dictionary) -> void:
	var target_position: Vector2 = target["position"]
	var target_scale: Vector2 = target["scale"]
	target_position.y -= _feel_value(feel_config, "hover_height_offset")
	target["position"] = target_position
	target["scale"] = target_scale * _feel_value(feel_config, "hover_scale")
	target["z_index"] = 350 + index


static func _feel_value(feel_config: Dictionary, key: String) -> float:
	return float(feel_config.get(key, 0.0))
