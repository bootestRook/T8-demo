extends RefCounted
class_name HudLayoutLabelStyleApplier

const HUD_LAYOUT_LABEL_STYLE_GROUPS := preload("res://src/ui/HudLayoutLabelStyleGroups.gd")


static func apply(hud: Node) -> void:
	HUD_LAYOUT_LABEL_STYLE_GROUPS.apply(hud)
