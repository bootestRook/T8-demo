extends RefCounted
class_name HudRewardChoiceSchoolBadge

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func build_school_badge_row(school: String, count_text: String) -> Control:
	var row := CenterContainer.new()
	row.name = "ChoiceSchoolBadgeRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(170.0, 30.0)

	var stack := Control.new()
	stack.name = "ChoiceSchoolBadgeStack"
	stack.custom_minimum_size = Vector2(170.0, 30.0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stack)

	var badge := build_school_badge(school)
	badge.position = Vector2(8.0, 0.0)
	stack.add_child(badge)

	if not count_text.is_empty():
		var count_label := build_school_count_label(count_text)
		count_label.position = Vector2(126.0, 4.0)
		stack.add_child(count_label)
	return row


static func build_school_count_label(text: String) -> Control:
	var label := Label.new()
	label.name = "ChoiceSchoolCountText"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(42.0, 26.0)
	label.z_index = 5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 2)
	return label


static func build_school_badge(school: String) -> Control:
	var holder := CenterContainer.new()
	holder.name = "ChoiceSchoolBadgeHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge := PanelContainer.new()
	badge.name = "ChoiceSchoolBadge"
	badge.custom_minimum_size = Vector2(116.0, 30.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", HUD_THEME.panel_style(Color(0.78, 0.68, 0.48, 0.96), Color(0.95, 0.78, 0.28, 1.0), 15, 2))
	holder.add_child(badge)

	var margin := MarginContainer.new()
	margin.name = "ChoiceSchoolBadgeMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	badge.add_child(margin)

	var label := Label.new()
	label.name = "ChoiceSchoolBadgeText"
	label.text = school
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.20, 0.13, 0.055))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.72, 0.50))
	label.add_theme_constant_override("outline_size", 1)
	margin.add_child(label)
	return holder
