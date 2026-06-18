extends RefCounted
class_name HudLayoutPanelStyleApplier

const HUD_LAYOUT_PANEL_STYLE_GROUPS := preload("res://src/ui/HudLayoutPanelStyleGroups.gd")


static func apply(hud: Node) -> void:
	HUD_LAYOUT_PANEL_STYLE_GROUPS.apply(hud)
