extends RefCounted
class_name HudCardVisualTargetSlots


static func base(widget: Dictionary, panel: PanelContainer, feel_config: Dictionary) -> Dictionary:
	return {
		"position": widget.get("base_position", panel.position),
		"scale": widget.get("base_scale", panel.scale),
		"rotation": float(widget.get("base_rotation", panel.rotation)),
		"z_index": int(widget.get("base_z_index", panel.z_index)),
		"follow_speed": _feel_value(feel_config, "hover_move_speed"),
	}


static func apply_reorder_preview(
	target: Dictionary, index: int, card_widgets: Array, hand_count: int, interaction: HudCardInteraction
) -> void:
	var preview_slot_index := _reorder_visual_slot_index(index, hand_count, interaction)
	if preview_slot_index == index:
		return
	var slot_widget: Dictionary = card_widgets[preview_slot_index]
	target["position"] = slot_widget.get("base_position", target["position"])
	target["rotation"] = float(slot_widget.get("base_rotation", target["rotation"]))
	target["z_index"] = int(slot_widget.get("base_z_index", target["z_index"]))


static func apply_hover_spread(
	target: Dictionary, index: int, spread_focus_index: int, hand_layer: Control, hand_card_size: Vector2, feel_config: Dictionary
) -> void:
	if spread_focus_index == -1 or index == spread_focus_index:
		return
	var target_position: Vector2 = target["position"]
	target_position.x += _hover_spread_offset(index, spread_focus_index, feel_config)
	target_position.x = _clamp_card_x(target_position.x, hand_layer, hand_card_size)
	target["position"] = target_position


static func _reorder_visual_slot_index(index: int, hand_count: int, interaction: HudCardInteraction) -> int:
	var dragged_index := interaction.dragging_card_index
	var preview_index := interaction.reorder_preview_index
	if dragged_index == -1 or preview_index == -1 or interaction.drag_playable:
		return index
	if dragged_index < 0 or dragged_index >= hand_count or preview_index < 0 or preview_index >= hand_count:
		return index
	if index == dragged_index or dragged_index == preview_index:
		return index
	if dragged_index < preview_index and index > dragged_index and index <= preview_index:
		return index - 1
	if dragged_index > preview_index and index >= preview_index and index < dragged_index:
		return index + 1
	return index


static func _hover_spread_offset(index: int, focus_index: int, feel_config: Dictionary) -> float:
	var distance := index - focus_index
	if distance == 0:
		return 0.0
	var direction := -1.0 if distance < 0 else 1.0
	var distance_abs := absf(float(distance))
	var spread := (
		_feel_value(feel_config, "hover_spread_min_offset")
		+ maxf(0.0, distance_abs - 1.0) * _feel_value(feel_config, "hover_spread_step_offset")
	)
	spread = minf(spread, _feel_value(feel_config, "hover_spread_max_offset"))
	return direction * spread


static func _clamp_card_x(x: float, hand_layer: Control, hand_card_size: Vector2) -> float:
	if hand_layer == null:
		return x
	var max_x := hand_layer.size.x - hand_card_size.x
	if max_x <= 0.0:
		return x
	return clampf(x, 0.0, max_x)


static func _feel_value(feel_config: Dictionary, key: String) -> float:
	return float(feel_config.get(key, 0.0))
