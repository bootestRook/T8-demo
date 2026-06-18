extends RefCounted
class_name HudCardHandLayout


static func layout(card_widgets: Array, visible_count: int, hand_width: float, hand_card_size: Vector2, should_snap: bool) -> void:
	if hand_width <= 0.0:
		hand_width = 1080.0
	var count_pressure := clampf(float(visible_count - 5) / 7.0, 0.0, 1.0)
	var overflow_pressure := clampf(float(visible_count - 10) / 4.0, 0.0, 1.0)
	var card_scale := lerpf(lerpf(1.24, 1.06, count_pressure), 0.94, overflow_pressure)
	var size_pressure := clampf((hand_card_size.x - 150.0) / 42.0, 0.0, 1.0)
	card_scale = minf(card_scale, lerpf(card_scale, 1.14, size_pressure))
	var scaled_card_size := hand_card_size * card_scale
	var center_min := 82.0 + scaled_card_size.x * 0.5
	var center_max := maxf(center_min, hand_width - 82.0 - scaled_card_size.x * 0.5)
	var desired_span := scaled_card_size.x * _hand_overlap_spacing_ratio(visible_count) * float(maxi(0, visible_count - 1))
	var center_span := minf(center_max - center_min, desired_span)
	center_min = hand_width * 0.5 - center_span * 0.5
	var max_rotation := lerpf(0.11, 0.045, count_pressure)
	var top_y := lerpf(106.0, 78.0, size_pressure) + lerpf(0.0, 24.0, count_pressure)
	var index := 0
	while index < card_widgets.size():
		_layout_card(
			card_widgets[index] as Dictionary,
			index,
			visible_count,
			{
				"hand_card_size": hand_card_size,
				"card_scale": card_scale,
				"center_min": center_min,
				"center_span": center_span,
				"top_y": top_y,
				"max_rotation": max_rotation,
			},
			should_snap
		)
		index += 1


static func snap(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	panel.position = widget.get("base_position", panel.position)
	panel.scale = widget.get("base_scale", panel.scale)
	panel.rotation = float(widget.get("base_rotation", panel.rotation))
	panel.z_index = int(widget.get("base_z_index", panel.z_index))
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	widget["view_position"] = panel.position
	widget["view_scale"] = panel.scale
	widget["view_rotation"] = panel.rotation


static func _layout_card(widget: Dictionary, index: int, visible_count: int, config: Dictionary, should_snap: bool) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	if index >= visible_count:
		panel.visible = false
		return
	var ratio := 0.5
	if visible_count > 1:
		ratio = float(index) / float(visible_count - 1)
	var signed := ratio * 2.0 - 1.0
	var hand_card_size: Vector2 = config["hand_card_size"]
	panel.visible = true
	panel.size = hand_card_size
	panel.pivot_offset = hand_card_size * 0.5
	widget["base_position"] = Vector2(
		float(config["center_min"]) + float(config["center_span"]) * ratio - hand_card_size.x * 0.5,
		float(config["top_y"]) + absf(signed) * 12.0
	)
	widget["base_scale"] = Vector2(float(config["card_scale"]), float(config["card_scale"]))
	widget["base_rotation"] = signed * float(config["max_rotation"])
	widget["base_z_index"] = 100 + index * 50
	if should_snap or not widget.has("view_position"):
		snap(widget)


static func _hand_overlap_spacing_ratio(visible_count: int) -> float:
	if visible_count <= 1:
		return 0.0
	if visible_count <= 3:
		return 0.82
	if visible_count == 4:
		return 0.84
	if visible_count == 5:
		return 0.74
	return maxf(0.38, 0.48 - float(visible_count - 6) * 0.025)
