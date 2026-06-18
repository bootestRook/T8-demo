extends RefCounted
class_name HudTheme


static func school_name(index: int) -> String:
	var names := ["温压弹", "干冰弹", "电磁穿刺"]
	return names[index % names.size()]


static func style_button(button: Button, kind: String) -> void:
	var bg := Color(0.105, 0.095, 0.078, 0.96)
	var border := Color(0.56, 0.46, 0.27, 0.92)
	if kind == "pause":
		bg = Color(0.090, 0.082, 0.068, 0.98)
	if kind == "menu":
		bg = Color(0.145, 0.132, 0.102, 0.98)
	if kind == "primary_menu":
		bg = Color(0.96, 0.86, 0.04, 1.0)
		border = Color(1.0, 0.96, 0.42, 1.0)
	button.add_theme_stylebox_override("normal", panel_style(bg, border, 7))
	button.add_theme_stylebox_override("hover", panel_style(bg.lightened(0.10), border.lightened(0.12), 7))
	button.add_theme_stylebox_override("pressed", panel_style(bg.darkened(0.12), border, 7))
	if kind == "primary_menu":
		var primary_text := Color(0.02, 0.018, 0.012)
		button.add_theme_color_override("font_color", primary_text)
		button.add_theme_color_override("font_hover_color", primary_text)
		button.add_theme_color_override("font_pressed_color", primary_text)
		button.add_theme_color_override("font_focus_color", primary_text)
		button.add_theme_color_override("font_disabled_color", Color(0.08, 0.07, 0.04, 0.74))
		button.add_theme_constant_override("outline_size", 0)
	else:
		button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
	button.add_theme_font_size_override("font_size", 24)


static func style_icon_button(button: Button, texture: Texture2D, clear_text := false) -> void:
	if button == null or texture == null:
		return
	var transparent_style := plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0)
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("focus", transparent_style)
	button.add_theme_stylebox_override("disabled", transparent_style)
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if clear_text:
		button.text = ""


static func style_progress(bar: ProgressBar, fill: Color, background: Color) -> void:
	bar.add_theme_stylebox_override("background", panel_style(background, Color(0.30, 0.26, 0.18, 0.92), 5, 1))
	bar.add_theme_stylebox_override("fill", panel_style(fill, fill.lightened(0.10), 5, 1))


static func panel_style(bg: Color, border: Color, radius: int, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func card_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


static func plain_panel_style(bg: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


static func compact_panel_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := panel_style(bg, border, radius, border_width)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


static func format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [floori(float(total) / 60.0), total % 60]


static func fit_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.left(maxi(1, max_chars - 3)) + "..."


static func card_text_size(text: String, large: int, medium: int, small: int, tiny: int) -> int:
	var plain := text.replace("\n", "")
	var length := plain.length()
	if length <= 6:
		return large
	if length <= 10:
		return medium
	if length <= 16:
		return small
	return tiny


static func card_effect_text_size(text: String) -> int:
	var plain := text.replace("\n", "")
	var line_count := text.split("\n", false).size()
	var length := plain.length()
	if line_count <= 2 and length <= 22:
		return 14
	if line_count <= 4 and length <= 42:
		return 13
	if line_count <= 5 and length <= 62:
		return 12
	return 11


static func format_card_effect_text(text: String) -> String:
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return ""
	return clean_text.replace("。", "。\n").replace("；", "；\n").strip_edges()


static func school_icon(index: int) -> String:
	var icons := ["冰", "穿", "修", "雷", "盾"]
	return icons[index % icons.size()]


static func clean_label_prefix(text: String) -> String:
	for prefix in ["目标：", "目标:"]:
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return text
