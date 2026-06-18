extends RefCounted
class_name HudRewardChoiceEntryTypeBadge

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func build(text: String) -> Control:
	var holder := _holder()
	var badge := _badge()
	holder.add_child(badge)
	var margin := _margin()
	badge.add_child(margin)
	margin.add_child(_label(text))
	return holder


static func _holder() -> CenterContainer:
	var holder := CenterContainer.new()
	holder.name = "ChoiceEntryTypeBadgeHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 0.0
	holder.anchor_top = 0.0
	holder.anchor_right = 1.0
	holder.anchor_bottom = 0.0
	holder.offset_left = 0.0
	holder.offset_top = -13.0
	holder.offset_right = 0.0
	holder.offset_bottom = 23.0
	return holder


static func _badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "ChoiceEntryTypeBadge"
	badge.custom_minimum_size = Vector2(92.0, 28.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", HUD_THEME.panel_style(Color(0.33, 0.09, 0.055, 0.98), Color(0.92, 0.58, 0.20, 1.0), 5, 2))
	return badge


static func _margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "ChoiceEntryTypeBadgeMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	return margin


static func _label(text: String) -> Label:
	var label := Label.new()
	label.name = "ChoiceEntryTypeBadgeText"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.56))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.035, 0.02, 0.94))
	label.add_theme_constant_override("outline_size", 1)
	return label
