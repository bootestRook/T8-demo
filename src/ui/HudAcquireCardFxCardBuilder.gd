extends RefCounted
class_name HudAcquireCardFxCardBuilder

const CARD_FRAME_PATH := "res://assets/ui/cards/card_frame_v1.png"
const CARD_ART_FALLBACK_PATH := "res://assets/ui/cards/card_art_fallback_v1.png"
const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")


static func build(card: Dictionary, destination: String, target_index: int, card_widgets: Array, card_size: Vector2) -> PanelContainer:
	var source_panel := _source_panel(destination, target_index, card_widgets)
	if source_panel == null:
		return null
	var panel := source_panel.duplicate() as PanelContainer
	if panel == null:
		return null
	HUD_CARD_WIDGETS.clear_unique_names(panel)
	HUD_CARD_WIDGETS.set_card_descendants_mouse_filter(panel)
	var widget := HUD_CARD_WIDGETS.card_widget_from_panel(panel)
	HUD_CARD_WIDGETS.ensure_card_texture_widgets([widget], CARD_FRAME_PATH)
	HUD_CARD_WIDGETS.style_card_widget(widget, HUD_THEME, card_size)
	var energy_cost := int(card.get("energy_cost", card.get("cost", 0)))
	(widget["cost"] as Label).text = HUD_CARD_WIDGETS.card_display_cost_text(card, energy_cost)
	HUD_CARD_WIDGETS.apply_card_art(widget, card, CARD_ART_FALLBACK_PATH)
	HUD_CARD_WIDGETS.apply_card_text(widget, card, target_index, HUD_THEME)
	HUD_CARD_WIDGETS.update_card_disabled(widget, false)
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	return panel


static func _source_panel(destination: String, target_index: int, card_widgets: Array) -> PanelContainer:
	if destination == "hand" and _is_valid_hand_target(target_index, card_widgets):
		return card_widgets[target_index]["panel"] as PanelContainer
	if not card_widgets.is_empty():
		return card_widgets[0]["panel"] as PanelContainer
	return null


static func _is_valid_hand_target(index: int, card_widgets: Array) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return (card_widgets[index]["panel"] as PanelContainer).visible
