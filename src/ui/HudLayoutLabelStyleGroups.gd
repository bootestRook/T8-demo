extends RefCounted
class_name HudLayoutLabelStyleGroups


static func apply(hud: Node) -> void:
	var blue_text := Color(0.82, 0.93, 1.0)
	var warm_text := Color(1.0, 0.88, 0.58)
	var plain_text := Color(0.92, 0.90, 0.84)

	_apply_base_labels(hud, plain_text)
	_apply_warm_labels(hud, warm_text)
	_apply_main_menu_labels(hud, warm_text, plain_text)
	_apply_pause_labels(hud)
	_apply_combat_header_labels(hud)
	_apply_runtime_labels(hud, blue_text)


static func _apply_base_labels(hud: Node, plain_text: Color) -> void:
	for label_variant in _all_labels(hud):
		var label: Label = label_variant as Label
		if label == null:
			continue
		_apply_shadow(label, plain_text, Color(0.0, 0.0, 0.0, 0.70), 2)
		label.add_theme_font_size_override("font_size", 23)


static func _apply_warm_labels(hud: Node, warm_text: Color) -> void:
	for label in [_label(hud, "stage_label"), _label(hud, "pause_title_label"), _label(hud, "energy_value_label")]:
		label.add_theme_color_override("font_color", warm_text)
		label.add_theme_font_size_override("font_size", 34)


static func _apply_main_menu_labels(hud: Node, warm_text: Color, plain_text: Color) -> void:
	var main_menu_title_label := _label(hud, "main_menu_title_label")
	for label in [main_menu_title_label, _label(hud, "main_menu_summary_label")]:
		var font_color := warm_text if label == main_menu_title_label else plain_text
		_apply_shadow(label, font_color, Color(0.0, 0.0, 0.0, 0.82), 2)
	main_menu_title_label.add_theme_font_size_override("font_size", 42)
	_label(hud, "main_menu_summary_label").add_theme_font_size_override("font_size", 22)


static func _apply_pause_labels(hud: Node) -> void:
	_apply_shadow(_label(hud, "pause_title_label"), Color(0.96, 0.95, 0.92), Color(0.0, 0.0, 0.0, 0.86), 3)
	_apply_shadow(_label(hud, "pause_summary_label"), Color(1.0, 0.96, 0.88), Color(0.25, 0.10, 0.02, 0.92), 2)
	_label(hud, "pause_title_label").add_theme_font_size_override("font_size", 50)
	_label(hud, "pause_summary_label").add_theme_font_size_override("font_size", 32)


static func _apply_combat_header_labels(hud: Node) -> void:
	for label in [_label(hud, "time_label"), _label(hud, "stage_label"), _label(hud, "wave_label"), _label(hud, "level_value_label")]:
		_apply_shadow(label, Color(0.98, 0.96, 0.88), Color(0.0, 0.0, 0.0, 0.95), 3)
	_label(hud, "time_label").add_theme_font_size_override("font_size", 25)
	_label(hud, "stage_label").add_theme_font_size_override("font_size", 34)
	_label(hud, "wave_label").add_theme_font_size_override("font_size", 25)


static func _apply_runtime_labels(hud: Node, blue_text: Color) -> void:
	_apply_progress_labels(hud)
	_apply_resource_labels(hud)
	_apply_defense_labels(hud)
	_label(hud, "objective_label").add_theme_color_override("font_color", blue_text)


static func _apply_progress_labels(hud: Node) -> void:
	_label(hud, "level_title_label").add_theme_font_size_override("font_size", 22)
	_label(hud, "level_value_label").add_theme_font_size_override("font_size", 20)
	_label(hud, "exp_value_label").add_theme_font_size_override("font_size", 22)
	_label(hud, "hint_label").add_theme_font_size_override("font_size", 20)
	_label(hud, "bottom_toast_label").add_theme_font_size_override("font_size", 18)
	_label(hud, "bottom_toast_label").add_theme_color_override("font_color", Color(0.78, 0.88, 0.96))


static func _apply_resource_labels(hud: Node) -> void:
	_label(hud, "ammo_value_label").add_theme_font_size_override("font_size", 28)
	_label(hud, "ammo_value_label").add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_label(hud, "hero_name_label").add_theme_font_size_override("font_size", 29)
	_label(hud, "ultimate_cost_label").add_theme_font_size_override("font_size", 32)
	_label(hud, "ultimate_cost_label").add_theme_color_override("font_color", Color(0.98, 0.92, 1.0))
	_label(hud, "energy_value_label").add_theme_color_override("font_color", Color(0.42, 0.84, 1.0))


static func _apply_defense_labels(hud: Node) -> void:
	_label(hud, "shield_icon_label").add_theme_color_override("font_color", Color(0.42, 0.84, 1.0))
	_label(hud, "shield_icon_label").add_theme_font_size_override("font_size", 32)
	_label(hud, "shield_value_label").add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	_label(hud, "shield_value_label").add_theme_font_size_override("font_size", 23)
	_label(hud, "shield_icon_label").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(hud, "wall_hp_icon_label").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(hud, "shield_value_label").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(hud, "wall_hp_value_label").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(hud, "wall_hp_icon_label").add_theme_color_override("font_color", Color(0.20, 0.95, 0.32))
	_label(hud, "wall_hp_icon_label").add_theme_font_size_override("font_size", 26)


static func _apply_shadow(label: Label, font_color: Color, shadow_color: Color, offset: int) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", offset)
	label.add_theme_constant_override("shadow_offset_y", offset)


static func _all_labels(hud: Node) -> Array:
	return hud.call("_all_labels") as Array


static func _label(hud: Node, property_name: String) -> Label:
	return hud.get(property_name) as Label
