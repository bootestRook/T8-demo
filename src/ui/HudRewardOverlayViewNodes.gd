extends RefCounted
class_name HudRewardOverlayViewNodes

const MENU_OVERLAY_Z_INDEX := 900
const MODAL_BACKDROP_COLOR := Color(0.02, 0.018, 0.014, 0.68)
const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func build(root: Control) -> Dictionary:
	var overlay := Control.new()
	_setup_overlay(overlay)
	root.add_child(overlay)

	_add_backdrop(overlay)
	var center := _add_center(overlay)
	var panel := _add_panel(center)
	var margin := _add_margin(panel)
	var column := _add_column(margin)
	_add_title(column)
	var button_box := _add_choice_box(column)

	return {
		"overlay": overlay,
		"center": center,
		"panel": panel,
		"button_box": button_box,
	}


static func _setup_overlay(overlay: Control) -> void:
	overlay.name = "LevelRewardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = MENU_OVERLAY_Z_INDEX


static func _add_backdrop(overlay: Control) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = "LevelRewardBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = MODAL_BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = 0
	overlay.add_child(backdrop)
	return backdrop


static func _add_center(overlay: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.name = "LevelRewardCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.z_index = 1
	overlay.add_child(center)
	return center


static func _add_panel(center: CenterContainer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LevelRewardPanel"
	panel.custom_minimum_size = Vector2(900.0, 540.0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.10, 0.09, 0.07, 0.88), 8))
	center.add_child(panel)
	return panel


static func _add_margin(panel: PanelContainer) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "LevelRewardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	return margin


static func _add_column(margin: MarginContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "LevelRewardLayout"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	return column


static func _add_title(column: VBoxContainer) -> Label:
	var title := Label.new()
	title.name = "LevelRewardTitle"
	title.text = "选择技能"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	column.add_child(title)
	return title


static func _add_choice_box(column: VBoxContainer) -> HBoxContainer:
	var button_box := HBoxContainer.new()
	button_box.name = "LevelRewardChoices"
	button_box.mouse_filter = Control.MOUSE_FILTER_PASS
	button_box.add_theme_constant_override("separation", 18)
	column.add_child(button_box)
	return button_box
