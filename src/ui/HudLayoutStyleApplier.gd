extends RefCounted
class_name HudLayoutStyleApplier

const HUD_LAYOUT_PANEL_STYLE_APPLIER := preload("res://src/ui/HudLayoutPanelStyleApplier.gd")
const HUD_LAYOUT_LABEL_STYLE_APPLIER := preload("res://src/ui/HudLayoutLabelStyleApplier.gd")
const HUD_LAYOUT_CONTROL_STYLE_APPLIER := preload("res://src/ui/HudLayoutControlStyleApplier.gd")


static func apply(hud: Node) -> void:
	HUD_LAYOUT_PANEL_STYLE_APPLIER.apply(hud)
	HUD_LAYOUT_LABEL_STYLE_APPLIER.apply(hud)
	HUD_LAYOUT_CONTROL_STYLE_APPLIER.apply(hud)
	hud.call("_style_cards")
