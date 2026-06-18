extends RefCounted
class_name HudCardLabelStyleGroups

const CARD_BASE_SIZE := Vector2(150.0, 266.667)
const CARD_FONT := preload("res://assets/DroidSansFallback.ttf")
const HUD_CARD_DESCRIPTION_TEXT := preload("res://src/ui/HudCardDescriptionText.gd")


static func card_text_scale(hand_card_size: Vector2) -> float:
	return clampf(minf(hand_card_size.x / CARD_BASE_SIZE.x, hand_card_size.y / CARD_BASE_SIZE.y), 1.0, 2.2)


static func scaled_font_size(base_size: int, scale: float) -> int:
	return maxi(8, int(float(base_size) * scale + 0.5))


static func scaled_constant(base_value: int, scale: float) -> int:
	return maxi(1, int(float(base_value) * scale + 0.5))


static func style_card_labels(widget: Dictionary, theme: Variant) -> void:
	var text_scale := float(widget.get("card_text_scale", 1.0))
	_apply_label_fonts(widget)
	_apply_cost_label(widget, theme, text_scale)
	_apply_art_label(widget, theme, text_scale)
	_apply_name_label(widget, theme, text_scale)
	_apply_type_label(widget, text_scale)
	_apply_description_label(widget, theme, text_scale)
	_apply_school_label(widget, theme, text_scale)


static func _apply_label_fonts(widget: Dictionary) -> void:
	for key in ["cost", "art", "name", "type", "school"]:
		_control(widget, key).add_theme_font_override("font", CARD_FONT)


static func _apply_cost_label(widget: Dictionary, theme: Variant, text_scale: float) -> void:
	var label := _label(widget, "cost")
	label.add_theme_font_size_override("font_size", scaled_font_size(16, text_scale))
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("outline_size", scaled_constant(3, text_scale))
	label.add_theme_stylebox_override("normal", theme.plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))


static func _apply_art_label(widget: Dictionary, theme: Variant, text_scale: float) -> void:
	var label := _label(widget, "art")
	label.add_theme_font_size_override("font_size", scaled_font_size(15, text_scale))
	label.add_theme_color_override("font_color", Color(0.60, 0.76, 0.84, 0.82))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_stylebox_override("normal", theme.panel_style(Color(0.035, 0.095, 0.125, 0.96), Color(0.18, 0.36, 0.45, 0.78), 3, 1))


static func _apply_name_label(widget: Dictionary, theme: Variant, text_scale: float) -> void:
	var label := _label(widget, "name")
	label.add_theme_font_size_override("font_size", scaled_font_size(17, text_scale))
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.24, 0.11, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", scaled_constant(2, text_scale))
	label.add_theme_stylebox_override("normal", theme.plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))


static func _apply_type_label(widget: Dictionary, text_scale: float) -> void:
	var label := _label(widget, "type")
	label.add_theme_font_size_override("font_size", scaled_font_size(12, text_scale))
	label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.42))


static func _apply_description_label(widget: Dictionary, theme: Variant, text_scale: float) -> void:
	var desc_control := _control(widget, "desc")
	for key in ["font", "normal_font", "bold_font", "italics_font", "bold_italics_font"]:
		desc_control.add_theme_font_override(key, CARD_FONT)
	HUD_CARD_DESCRIPTION_TEXT.apply_font_size(desc_control, scaled_font_size(16, text_scale))
	desc_control.add_theme_color_override("default_color", Color(0.0, 0.0, 0.0))
	desc_control.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	desc_control.add_theme_color_override("font_outline_color", Color(0.98, 0.94, 0.84, 0.82))
	desc_control.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	desc_control.add_theme_constant_override("shadow_offset_x", scaled_constant(1, text_scale))
	desc_control.add_theme_constant_override("shadow_offset_y", scaled_constant(1, text_scale))
	desc_control.add_theme_constant_override("outline_size", scaled_constant(1, text_scale))
	desc_control.add_theme_constant_override("line_spacing", 0)
	desc_control.add_theme_stylebox_override("normal", theme.plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))


static func _apply_school_label(widget: Dictionary, theme: Variant, text_scale: float) -> void:
	var label := _label(widget, "school")
	label.add_theme_font_size_override("font_size", scaled_font_size(13, text_scale))
	label.add_theme_color_override("font_color", Color(0.16, 0.09, 0.025))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("outline_size", scaled_constant(1, text_scale))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.70, 0.80))
	label.add_theme_stylebox_override("normal", theme.plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))


static func _control(widget: Dictionary, key: String) -> Control:
	return widget[key] as Control


static func _label(widget: Dictionary, key: String) -> Label:
	return widget[key] as Label
