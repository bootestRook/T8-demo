extends RefCounted
class_name HudCardVisuals

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")
const HUD_CARD_PRESS_FEEDBACK := preload("res://src/ui/HudCardPressFeedback.gd")
const HUD_CARD_VISUAL_FEEDBACK := preload("res://src/ui/HudCardVisualFeedback.gd")
const HUD_CARD_VISUAL_INTERPOLATOR := preload("res://src/ui/HudCardVisualInterpolator.gd")
const HUD_CARD_VISUAL_TARGET := preload("res://src/ui/HudCardVisualTarget.gd")

var card_widgets: Array = []
var hand_layer: Control = null
var interaction: HudCardInteraction = null
var feel_config: Dictionary = {}
var hand_card_size := Vector2.ZERO
var draw_card_fx: RefCounted = null
var acquire_card_fx: RefCounted = null
var discard_hand_fx: RefCounted = null
var chain_hint_time := 0.0


func setup(
	widgets: Array,
	layer: Control,
	interaction_state: HudCardInteraction,
	config: Dictionary,
	card_size: Vector2,
	draw_fx: RefCounted,
	acquire_fx: RefCounted,
	discard_fx: RefCounted
) -> void:
	card_widgets = widgets
	hand_layer = layer
	interaction = interaction_state
	feel_config = config
	hand_card_size = card_size
	draw_card_fx = draw_fx
	acquire_card_fx = acquire_fx
	discard_hand_fx = discard_fx


func update(delta: float, hand_count: int) -> void:
	chain_hint_time += delta
	var spread_focus_index := _spread_focus_index(hand_count)
	for index in range(card_widgets.size()):
		var widget: Dictionary = card_widgets[index]
		var panel: PanelContainer = widget["panel"] as PanelContainer
		if index >= hand_count or not panel.visible:
			HUD_CARD_WIDGETS.update_card_chain_hint(widget, false, chain_hint_time)
			_update_card_press_fx(widget, {"weight": 0.0})
			continue
		_ensure_card_feel_state(widget)
		var is_disabled := _is_card_cooling_down(widget)
		var press_feedback: Dictionary = HUD_CARD_PRESS_FEEDBACK.build(panel, index, is_disabled, interaction, hand_card_size)
		var target := HUD_CARD_VISUAL_TARGET.build(
			index,
			widget,
			card_widgets,
			hand_count,
			interaction,
			hand_layer,
			hand_card_size,
			feel_config,
			press_feedback,
			is_disabled,
			spread_focus_index
		)
		target = HUD_CARD_VISUAL_FEEDBACK.apply(
			index, widget, panel, target, delta, chain_hint_time, interaction, feel_config, draw_card_fx, acquire_card_fx, discard_hand_fx
		)
		_update_card_press_fx(widget, press_feedback)
		HUD_CARD_VISUAL_INTERPOLATOR.apply(widget, panel, target, delta)


func _ensure_card_feel_state(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	if not widget.has("view_position"):
		widget["view_position"] = widget.get("base_position", panel.position)
	if not widget.has("view_scale"):
		widget["view_scale"] = widget.get("base_scale", panel.scale)
	if not widget.has("view_rotation"):
		widget["view_rotation"] = widget.get("base_rotation", panel.rotation)


func _is_card_cooling_down(widget: Dictionary) -> bool:
	return maxf(0.0, float(widget.get("cooldown_remaining", 0.0))) > 0.0


func _update_card_press_fx(widget: Dictionary, _feedback: Dictionary) -> void:
	var press_fx: HudCardPressFx = widget.get("press_fx", null) as HudCardPressFx
	if press_fx == null:
		return
	press_fx.set_press_state(false, hand_card_size * 0.5, hand_card_size * 0.5, 0.0)


func _spread_focus_index(hand_count: int) -> int:
	if interaction.dragging_card_index != -1:
		return -1
	var focus_index := interaction.hover_index
	if focus_index == -1:
		focus_index = interaction.selected_card_index
	if focus_index < 0 or focus_index >= hand_count or focus_index >= card_widgets.size():
		return -1
	var focus_widget: Dictionary = card_widgets[focus_index]
	var focus_panel: PanelContainer = focus_widget["panel"] as PanelContainer
	if not focus_panel.visible or _is_card_cooling_down(focus_widget):
		return -1
	return focus_index
