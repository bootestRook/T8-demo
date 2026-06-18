extends RefCounted
class_name HudCardReadabilityRegions

const HUD_CARD_READABILITY_REGION_FRAMES := preload("res://src/ui/HudCardReadabilityRegionFrames.gd")
const HUD_CARD_READABILITY_LAYER_APPLIER := preload("res://src/ui/HudCardReadabilityLayerApplier.gd")
const HUD_CARD_READABILITY_TEXT_APPLIER := preload("res://src/ui/HudCardReadabilityTextApplier.gd")


static func layout_card_readability_regions(widget: Dictionary, hand_card_size: Vector2) -> void:
	var frames: Dictionary = HUD_CARD_READABILITY_REGION_FRAMES.build(hand_card_size)
	HUD_CARD_READABILITY_LAYER_APPLIER.apply(widget, hand_card_size, frames)
	HUD_CARD_READABILITY_TEXT_APPLIER.apply(widget, frames)
