extends RefCounted
class_name HudCardChainHintNodes

const HUD_CARD_NODE_FINDER := preload("res://src/ui/HudCardNodeFinder.gd")
const SPARKLE_TEXTS := ["✦", "•", "✧"]


static func ensure(widget: Dictionary) -> Dictionary:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	var parent := ((widget["cost"] as Label).get_parent()) as Control
	_hide_legacy_glow_label(panel)
	return {"glow": _glow_panel(panel, parent), "sparkles": _sparkles(panel, parent)}


static func _hide_legacy_glow_label(panel: PanelContainer) -> void:
	var legacy_glow_label := HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "ChainCostGlowLabel")
	if legacy_glow_label != null:
		legacy_glow_label.visible = false


static func _glow_panel(panel: PanelContainer, parent: Control) -> Panel:
	var glow_panel := HUD_CARD_NODE_FINDER.find_panel_by_suffix(panel, "ChainCostGlowPanel")
	if glow_panel == null:
		glow_panel = Panel.new()
		glow_panel.name = "%sChainCostGlowPanel" % String(panel.name)
		glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(glow_panel)
	glow_panel.visible = false
	glow_panel.add_theme_stylebox_override("panel", _glow_style())
	return glow_panel


static func _glow_style() -> StyleBoxFlat:
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.78, 0.12, 0.34)
	glow_style.set_corner_radius_all(18)
	glow_style.shadow_color = Color(1.0, 0.88, 0.18, 0.58)
	glow_style.shadow_size = 8
	return glow_style


static func _sparkles(panel: PanelContainer, parent: Control) -> Array:
	var sparkles: Array = []
	for index in range(SPARKLE_TEXTS.size()):
		sparkles.append(_sparkle(panel, parent, index))
	return sparkles


static func _sparkle(panel: PanelContainer, parent: Control, index: int) -> Label:
	var sparkle := HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "ChainSparkle%dLabel" % index)
	if sparkle == null:
		sparkle = Label.new()
		sparkle.name = "%sChainSparkle%dLabel" % [String(panel.name), index]
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sparkle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		parent.add_child(sparkle)
	sparkle.text = SPARKLE_TEXTS[index]
	sparkle.visible = false
	sparkle.add_theme_color_override("font_color", Color(1.0, 0.96, 0.66, 1.0))
	sparkle.add_theme_color_override("font_outline_color", Color(0.65, 0.36, 0.02, 0.85))
	sparkle.add_theme_constant_override("outline_size", 1)
	return sparkle
