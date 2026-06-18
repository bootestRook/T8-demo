extends RefCounted
class_name HudRewardChoiceButtons

const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_REWARD_CHOICE_CONTENT := preload("res://src/ui/HudRewardChoiceContent.gd")


static func rebuild(button_box: HBoxContainer, choices: Array, pressed_callback: Callable) -> void:
	clear(button_box)
	var index := 0
	while index < choices.size():
		if choices[index] is Dictionary:
			button_box.add_child(build_button(choices[index] as Dictionary, index, pressed_callback))
		index += 1


static func clear(button_box: HBoxContainer) -> void:
	while button_box.get_child_count() > 0:
		var child := button_box.get_child(0)
		button_box.remove_child(child)
		child.queue_free()


static func build_button(choice: Dictionary, index: int, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.name = "LevelRewardChoice%d" % (index + 1)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(255.0, 360.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.add_child(build_button_content(choice))
	button.pressed.connect(pressed_callback.bind(index))
	style_button(button)
	return button


static func style_button(button: Button) -> void:
	var bg := Color(0.145, 0.132, 0.102, 0.96)
	var border := Color(0.66, 0.52, 0.28, 0.96)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_stylebox_override("normal", HUD_THEME.panel_style(bg, border, 5, 2))
	button.add_theme_stylebox_override("hover", HUD_THEME.panel_style(bg.lightened(0.10), border.lightened(0.18), 5, 2))
	button.add_theme_stylebox_override("pressed", HUD_THEME.panel_style(bg.darkened(0.10), border, 5, 2))
	button.add_theme_stylebox_override("focus", HUD_THEME.panel_style(bg.lightened(0.05), Color(0.95, 0.88, 0.58, 1.0), 5, 3))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
	button.add_theme_color_override("font_pressed_color", Color(0.98, 0.86, 0.38))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.62))
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_font_size_override("font_size", 25)


static func build_button_content(choice: Dictionary) -> Control:
	return HUD_REWARD_CHOICE_CONTENT.build(choice)
