extends RefCounted
class_name HudPileOverlayHeaderView

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func build(column: VBoxContainer, close_callable: Callable) -> Dictionary:
	var top_row := HBoxContainer.new()
	top_row.name = "DrawPileTopRow"
	top_row.add_theme_constant_override("separation", 12)
	column.add_child(top_row)

	var title_spacer := Control.new()
	title_spacer.name = "DrawPileTitleSpacer"
	title_spacer.custom_minimum_size = Vector2(48.0, 48.0)
	top_row.add_child(title_spacer)

	var title_label := _build_title_label()
	top_row.add_child(title_label)

	var close_button := _build_close_button(close_callable)
	top_row.add_child(close_button)

	return {
		"title_label": title_label,
		"close_button": close_button,
	}


static func _build_title_label() -> Label:
	var title_label := Label.new()
	title_label.name = "DrawPileTitle"
	title_label.text = "牌堆"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	return title_label


static func _build_close_button(close_callable: Callable) -> Button:
	var close_button := Button.new()
	close_button.name = "DrawPileCloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(48.0, 48.0)
	HUD_THEME.style_button(close_button, "primary_menu")
	close_button.pressed.connect(close_callable)
	return close_button
