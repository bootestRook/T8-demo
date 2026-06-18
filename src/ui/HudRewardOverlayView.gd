extends RefCounted
class_name HudRewardOverlayView

const HUD_REWARD_OVERLAY_VIEW_NODES := preload("res://src/ui/HudRewardOverlayViewNodes.gd")


static func build(root: Control) -> Dictionary:
	return HUD_REWARD_OVERLAY_VIEW_NODES.build(root)
