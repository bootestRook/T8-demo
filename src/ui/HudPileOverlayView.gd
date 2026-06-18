extends RefCounted
class_name HudPileOverlayView

const MENU_OVERLAY_Z_INDEX := 920
const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_PILE_OVERLAY_HEADER_VIEW := preload("res://src/ui/HudPileOverlayHeaderView.gd")
const HUD_PILE_OVERLAY_CONTENT_VIEW := preload("res://src/ui/HudPileOverlayContentView.gd")


static func build(root: Control, close_callable: Callable, shade_input_callable: Callable) -> Dictionary:
	var overlay := _build_overlay(root)
	_build_shade(overlay, shade_input_callable)
	var center := _build_center(overlay)
	var panel := _build_panel(center)
	var column := _build_column(panel)
	var header := HUD_PILE_OVERLAY_HEADER_VIEW.build(column, close_callable)
	var content := HUD_PILE_OVERLAY_CONTENT_VIEW.build(column)

	return {
		"overlay": overlay,
		"panel": panel,
		"title_label": header["title_label"],
		"close_button": header["close_button"],
		"scroll": content["scroll"],
		"grid_margin": content["grid_margin"],
		"grid": content["grid"],
		"empty_label": content["empty_label"],
	}


static func _build_overlay(root: Control) -> Control:
	var overlay := Control.new()
	overlay.name = "DrawPileOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = MENU_OVERLAY_Z_INDEX
	root.add_child(overlay)
	return overlay


static func _build_shade(overlay: Control, shade_input_callable: Callable) -> void:
	var shade := ColorRect.new()
	shade.name = "DrawPileShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.018, 0.016, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(shade_input_callable)
	overlay.add_child(shade)


static func _build_center(overlay: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.name = "DrawPileCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	return center


static func _build_panel(center: CenterContainer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "DrawPilePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HUD_THEME.panel_style(Color(0.105, 0.095, 0.078, 0.96), Color(0.56, 0.46, 0.27, 0.92), 8, 2))
	center.add_child(panel)
	return panel


static func _build_column(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "DrawPileMargin"
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "DrawPileLayout"
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	return column
