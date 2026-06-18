extends RefCounted
class_name HudCardSnapshotPresenter

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")

var _card_widgets: Array = []
var _default_cards: Array = []
var _theme: Variant = null
var _card_art_fallback_path := ""


func setup(card_widgets: Array, default_cards: Array, theme: Variant, card_art_fallback_path: String) -> void:
	_card_widgets = card_widgets
	_default_cards = default_cards
	_theme = theme
	_card_art_fallback_path = card_art_fallback_path


func cards_from_snapshot(snapshot: Dictionary) -> Array:
	var cards_variant: Variant = snapshot.get("hand_cards", _default_cards)
	if cards_variant is Array:
		return cards_variant as Array
	return _default_cards


func apply(cards: Array, snapshot: Dictionary, energy: int, gameplay_active: bool) -> void:
	var can_play_cards := gameplay_active and bool(snapshot.get("can_play_cards", true))
	for index in range(_card_widgets.size()):
		var widget: Dictionary = _card_widgets[index]
		var is_visible := index < cards.size()
		_set_card_visible(widget, is_visible)
		if not is_visible:
			continue
		_apply_card_widget(widget, _card_at(cards, index), index, energy, can_play_cards)


func _set_card_visible(widget: Dictionary, is_visible: bool) -> void:
	(widget["panel"] as PanelContainer).visible = is_visible
	if not is_visible:
		widget["chain_hint_active"] = false


func _apply_card_widget(widget: Dictionary, card: Dictionary, index: int, energy: int, can_play_cards: bool) -> void:
	var energy_cost: int = int(card.get("energy_cost", card.get("cost", 0)))
	var usable := energy >= energy_cost
	var cooldown_remaining := float(card.get("cooldown_remaining", 0.0))
	var is_disabled := cooldown_remaining > 0.0
	var chain_hint_active := bool(card.get("can_continue_chain", false)) and usable and not is_disabled and can_play_cards

	(widget["cost"] as Label).text = HUD_CARD_WIDGETS.card_display_cost_text(card, energy_cost)
	HUD_CARD_WIDGETS.apply_card_art(widget, card, _card_art_fallback_path)
	(widget["type"] as Label).text = ""
	HUD_CARD_WIDGETS.apply_card_text(widget, card, index, _theme)
	(widget["panel"] as PanelContainer).modulate = Color(1, 1, 1, 1)
	HUD_CARD_WIDGETS.update_card_disabled(widget, is_disabled)
	widget["cooldown_remaining"] = cooldown_remaining
	widget["chain_hint_active"] = chain_hint_active
	_apply_cost_color(widget, card, usable, is_disabled, chain_hint_active)


func _apply_cost_color(widget: Dictionary, card: Dictionary, usable: bool, is_disabled: bool, chain_hint_active: bool) -> void:
	var cost_color := Color(1.0, 0.94, 0.42) if chain_hint_active else HUD_CARD_WIDGETS.card_cost_color(card, usable, is_disabled)
	(widget["cost"] as Label).add_theme_color_override("font_color", cost_color)


func _card_at(cards: Array, index: int) -> Dictionary:
	if index >= 0 and index < cards.size() and cards[index] is Dictionary:
		return cards[index] as Dictionary
	return _default_cards[index % _default_cards.size()]
