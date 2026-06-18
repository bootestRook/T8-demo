extends RefCounted
class_name HudCardVisualFeedback

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")


static func apply(
	index: int,
	widget: Dictionary,
	panel: PanelContainer,
	target: Dictionary,
	delta: float,
	chain_hint_time: float,
	interaction: HudCardInteraction,
	feel_config: Dictionary,
	draw_card_fx: RefCounted,
	acquire_card_fx: RefCounted,
	discard_hand_fx: RefCounted
) -> Dictionary:
	var result := target.duplicate()
	_apply_invalid_feedback(index, panel, result, interaction, feel_config)
	_apply_draw_feedback(index, widget, panel, result, delta, draw_card_fx)
	acquire_card_fx.apply_card_feedback(widget, panel, delta)
	_apply_discard_feedback(widget, panel, discard_hand_fx)
	HUD_CARD_WIDGETS.update_card_chain_hint(widget, bool(widget.get("chain_hint_active", false)), chain_hint_time)
	return result


static func _apply_invalid_feedback(
	index: int, panel: PanelContainer, target: Dictionary, interaction: HudCardInteraction, feel_config: Dictionary
) -> void:
	if index != interaction.invalid_feedback_index or interaction.invalid_feedback_timer <= 0.0:
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var full_time := maxf(0.01, _feel_value(feel_config, "invalid_shake_time"))
	var weight := interaction.invalid_feedback_timer / full_time
	var shake_tick := int(interaction.invalid_feedback_timer * _feel_value(feel_config, "invalid_shake_vibrato") * 10.0) % 2
	var shake_dir := -1.0 if shake_tick == 0 else 1.0
	var position: Vector2 = target["position"]
	var scale: Vector2 = target["scale"]
	position.x += shake_dir * _feel_value(feel_config, "invalid_shake_amplitude") * weight
	position.y -= _feel_value(feel_config, "invalid_height_offset") * weight
	target["position"] = position
	target["scale"] = scale * _feel_value(feel_config, "invalid_scale")
	target["z_index"] = 520 + index
	panel.modulate = Color(1.0, 0.78, 0.94, 1.0)


static func _apply_draw_feedback(
	index: int, widget: Dictionary, panel: PanelContainer, target: Dictionary, delta: float, draw_card_fx: RefCounted
) -> void:
	var draw_feedback: Dictionary = draw_card_fx.card_feedback(widget, delta)
	if bool(draw_feedback.get("hidden", false)):
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return
	var pulse_weight := float(draw_feedback.get("pulse", 0.0))
	if pulse_weight <= 0.0:
		return
	var position: Vector2 = target["position"]
	var scale: Vector2 = target["scale"]
	position.y -= 16.0 * pulse_weight
	target["position"] = position
	target["scale"] = scale * (1.0 + 0.09 * pulse_weight)
	target["z_index"] = 560 + index
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


static func _apply_discard_feedback(widget: Dictionary, panel: PanelContainer, discard_hand_fx: RefCounted) -> void:
	var discard_feedback: Dictionary = discard_hand_fx.card_feedback(widget)
	if bool(discard_feedback.get("hidden", false)):
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)


static func _feel_value(feel_config: Dictionary, key: String) -> float:
	return float(feel_config.get(key, 0.0))
