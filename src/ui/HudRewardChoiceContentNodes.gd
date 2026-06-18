extends RefCounted
class_name HudRewardChoiceContentNodes

const HUD_REWARD_CHOICE_BADGES := preload("res://src/ui/HudRewardChoiceBadges.gd")
const HUD_REWARD_CHOICE_TEXT := preload("res://src/ui/HudRewardChoiceText.gd")


static func build(choice: Dictionary) -> Control:
	var content_root := _build_root()
	var column := _build_text_column(content_root)
	column.add_child(_build_title_label(choice))
	column.add_child(_build_body_label(choice))
	_add_school_badge_row(column, choice)
	_add_corner_badges(content_root, choice)
	return content_root


static func _build_root() -> Control:
	var content_root := Control.new()
	content_root.name = "ChoiceContentRoot"
	content_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return content_root


static func _build_text_column(content_root: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "ChoiceTextMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 24)
	content_root.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "ChoiceTextColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	return column


static func _build_title_label(choice: Dictionary) -> Label:
	var title_label := Label.new()
	title_label.name = "ChoiceTitle"
	title_label.text = HUD_REWARD_CHOICE_TEXT.title(choice)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.54))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.055, 0.02, 0.94))
	title_label.add_theme_constant_override("outline_size", 2)
	return title_label


static func _build_body_label(choice: Dictionary) -> Label:
	var body_label := Label.new()
	body_label.name = "ChoiceBody"
	body_label.text = HUD_REWARD_CHOICE_TEXT.visible_description(choice)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 22)
	body_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
	body_label.add_theme_color_override("font_outline_color", Color(0.04, 0.035, 0.025, 0.90))
	body_label.add_theme_constant_override("outline_size", 1)
	return body_label


static func _add_school_badge_row(column: VBoxContainer, choice: Dictionary) -> void:
	var school := HUD_REWARD_CHOICE_TEXT.school(choice)
	if school.is_empty():
		return
	var owned_school_count_text := HUD_REWARD_CHOICE_TEXT.school_count_text(choice)
	column.add_child(HUD_REWARD_CHOICE_BADGES.build_school_badge_row(school, owned_school_count_text))


static func _add_corner_badges(content_root: Control, choice: Dictionary) -> void:
	var entry_type_badge := HUD_REWARD_CHOICE_TEXT.entry_type_badge_text(choice)
	if not entry_type_badge.is_empty():
		content_root.add_child(HUD_REWARD_CHOICE_BADGES.build_entry_type_badge(entry_type_badge))
	var cost_text := HUD_REWARD_CHOICE_TEXT.card_cost_text(choice)
	if not cost_text.is_empty():
		content_root.add_child(HUD_REWARD_CHOICE_BADGES.build_card_cost_badge(cost_text))
	var owned_cost_count_text := HUD_REWARD_CHOICE_TEXT.cost_count_text(choice)
	if not owned_cost_count_text.is_empty():
		content_root.add_child(HUD_REWARD_CHOICE_BADGES.build_cost_count_label(owned_cost_count_text))
