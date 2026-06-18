extends RefCounted
class_name HudCardVisualTarget

const HUD_CARD_VISUAL_TARGET_MOTION := preload("res://src/ui/HudCardVisualTargetMotion.gd")
const HUD_CARD_VISUAL_TARGET_PRESS := preload("res://src/ui/HudCardVisualTargetPress.gd")
const HUD_CARD_VISUAL_TARGET_SLOTS := preload("res://src/ui/HudCardVisualTargetSlots.gd")


static func build(
	index: int,
	widget: Dictionary,
	card_widgets: Array,
	hand_count: int,
	interaction: HudCardInteraction,
	hand_layer: Control,
	hand_card_size: Vector2,
	feel_config: Dictionary,
	press_feedback: Dictionary,
	is_disabled: bool,
	spread_focus_index: int
) -> Dictionary:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	var target := HUD_CARD_VISUAL_TARGET_SLOTS.base(widget, panel, feel_config)
	HUD_CARD_VISUAL_TARGET_SLOTS.apply_reorder_preview(target, index, card_widgets, hand_count, interaction)
	HUD_CARD_VISUAL_TARGET_SLOTS.apply_hover_spread(target, index, spread_focus_index, hand_layer, hand_card_size, feel_config)
	if not is_disabled:
		HUD_CARD_VISUAL_TARGET_MOTION.apply_drag_or_hover(target, index, interaction, hand_layer, hand_card_size, feel_config)
	HUD_CARD_VISUAL_TARGET_PRESS.apply(target, press_feedback, feel_config)
	return target
