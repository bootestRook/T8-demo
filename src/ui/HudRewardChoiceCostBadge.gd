extends RefCounted
class_name HudRewardChoiceCostBadge

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func build_card_cost_badge(text: String) -> Control:
	var badge := PanelContainer.new()
	badge.name = "ChoiceCardCostBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(12.0, 11.0)
	badge.size = Vector2(42.0, 42.0)
	badge.z_index = 4
	badge.add_theme_stylebox_override("panel", HUD_THEME.panel_style(Color(0.035, 0.19, 0.38, 0.98), Color(0.88, 0.75, 0.38, 0.98), 21, 3))

	var label := Label.new()
	label.name = "ChoiceCardCostText"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
	label.add_theme_constant_override("outline_size", 3)
	badge.add_child(label)
	return badge


static func build_cost_count_label(text: String) -> Control:
	var label := Label.new()
	label.name = "ChoiceCostCountText"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(12.0, 55.0)
	label.size = Vector2(42.0, 26.0)
	label.z_index = 5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 2)
	return label
