extends RefCounted
class_name HudLayoutPanelStyleGroups

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func apply(hud: Node) -> void:
	_apply_default_metal_panels(hud)
	_apply_header_panels(hud)
	_apply_status_panels(hud)
	_apply_badge_panels(hud)
	_apply_transparent_panels(hud)


static func _apply_default_metal_panels(hud: Node) -> void:
	var metal_panel := Color(0.115, 0.105, 0.085, 0.94)
	var metal_border := Color(0.545, 0.440, 0.250, 0.86)
	for panel in _metal_panels(hud):
		panel.add_theme_stylebox_override("panel", HUD_THEME.panel_style(metal_panel, metal_border, 8))


static func _apply_header_panels(hud: Node) -> void:
	for panel in [_panel(hud, "%TimePanel"), _panel(hud, "%StagePanel"), _panel(hud, "%WavePanel")]:
		panel.add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.0, 0.0, 0.0, 0.16), 0))


static func _apply_status_panels(hud: Node) -> void:
	_panel(hud, "%ExpPanel").add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.0, 0.0, 0.0, 0.22), 0))
	_panel(hud, "%AmmoPanel").add_theme_stylebox_override(
		"panel", HUD_THEME.compact_panel_style(Color(0.055, 0.075, 0.080, 0.92), Color(0.74, 0.46, 0.20, 0.92), 3, 1)
	)
	_panel(hud, "%WallHpPanel").add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.04, 0.04, 0.035, 0.36), 0))
	_panel(hud, "%HandArea").add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.025, 0.045, 0.052, 0.38), 4))


static func _apply_badge_panels(hud: Node) -> void:
	_panel(hud, "%EnergyBadge").add_theme_stylebox_override(
		"panel", HUD_THEME.panel_style(Color(0.050, 0.075, 0.090, 0.96), Color(0.36, 0.66, 0.92, 0.88), 32)
	)
	_panel(hud, "%UltimateCostBadge").add_theme_stylebox_override(
		"panel", HUD_THEME.panel_style(Color(0.72, 0.08, 0.70, 0.98), Color(0.06, 0.03, 0.12, 0.98), 30, 3)
	)


static func _apply_transparent_panels(hud: Node) -> void:
	for panel in [
		_panel(hud, "%DefenseWallPanel"),
		_panel(hud, "%HeroStatusPanel"),
		_panel(hud, "%HeroPortraitPanel"),
	]:
		panel.add_theme_stylebox_override("panel", HUD_THEME.plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))


static func _metal_panels(hud: Node) -> Array[PanelContainer]:
	return [
		_panel(hud, "%ObjectivePanel"),
		_panel(hud, "%AmmoPanel"),
		_panel(hud, "%DefenseWallPanel"),
		_panel(hud, "%WallHpPanel"),
		_panel(hud, "%HeroStatusPanel"),
		_panel(hud, "%EnergyBadge"),
		_panel(hud, "%HeroPortraitPanel"),
		_panel(hud, "%UltimateCostBadge"),
		_panel(hud, "%HandArea"),
		_prop_panel(hud, "main_menu_panel"),
	]


static func _prop_panel(hud: Node, property_name: String) -> PanelContainer:
	return hud.get(property_name) as PanelContainer


static func _panel(hud: Node, path: NodePath) -> PanelContainer:
	return hud.get_node(path) as PanelContainer
