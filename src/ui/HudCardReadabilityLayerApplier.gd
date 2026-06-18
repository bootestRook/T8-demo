extends RefCounted
class_name HudCardReadabilityLayerApplier

const HUD_CARD_READABILITY_REGION_FRAMES := preload("res://src/ui/HudCardReadabilityRegionFrames.gd")


static func apply(widget: Dictionary, hand_card_size: Vector2, frames: Dictionary) -> void:
	_layout_base_layers(widget, frames)
	_layout_chain_fx(widget, hand_card_size, frames)
	_layout_press_fx(widget, frames)


static func _layout_base_layers(widget: Dictionary, frames: Dictionary) -> void:
	if widget.has("frame_texture"):
		var frame_texture: TextureRect = widget["frame_texture"] as TextureRect
		_apply_rect(frame_texture, frames["frame"])
		frame_texture.z_index = -2

	if widget.has("disabled_overlay"):
		var disabled_overlay: ColorRect = widget["disabled_overlay"] as ColorRect
		_apply_rect(disabled_overlay, frames["disabled_overlay"])
		disabled_overlay.z_index = 8

	if widget.has("disabled_icon"):
		var disabled_icon: Label = widget["disabled_icon"] as Label
		_apply_rect(disabled_icon, frames["disabled_icon"])
		disabled_icon.z_index = 9


static func _layout_chain_fx(widget: Dictionary, hand_card_size: Vector2, frames: Dictionary) -> void:
	if widget.has("chain_cost_glow"):
		var glow_panel: Control = widget["chain_cost_glow"] as Control
		_apply_rect(glow_panel, frames["chain_cost_glow"])
		glow_panel.z_index = 4
		glow_panel.pivot_offset = glow_panel.size * 0.5

	if widget.has("chain_cost_sparkles"):
		var sparkles: Array = widget["chain_cost_sparkles"] as Array
		var scaled_positions: Array = []
		for index in range(sparkles.size()):
			var sparkle: Label = sparkles[index] as Label
			_apply_rect(sparkle, HUD_CARD_READABILITY_REGION_FRAMES.chain_sparkle_frame(index, hand_card_size))
			sparkle.z_index = 7
			sparkle.pivot_offset = sparkle.size * 0.5
			sparkle.add_theme_font_size_override("font_size", _scaled_font_size(15 if index != 1 else 11, float(frames["font_scale"])))
			scaled_positions.append(sparkle.position)
		widget["chain_sparkle_base_positions"] = scaled_positions


static func _layout_press_fx(widget: Dictionary, frames: Dictionary) -> void:
	if widget.has("press_fx"):
		var press_fx: HudCardPressFx = widget["press_fx"] as HudCardPressFx
		_apply_rect(press_fx, frames["press_fx"])
		press_fx.z_index = 3
		press_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _apply_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


static func _scaled_font_size(base_size: int, scale: float) -> int:
	return maxi(8, int(float(base_size) * scale + 0.5))
