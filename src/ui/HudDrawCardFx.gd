extends RefCounted
class_name HudDrawCardFx

const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const DRAW_CARD_FX_DURATION := 0.36
const DRAW_CARD_START_SCALE := 0.58
const DRAW_CARD_ARC_HEIGHT := 132.0
const DRAW_CARD_ARRIVAL_PULSE_TIME := 0.22
const DRAW_PILE_PULSE_TIME := 0.22
const HUD_DRAW_CARD_FX_SPAWN := preload("res://src/ui/HudDrawCardFxSpawn.gd")

var hand_layer: Control
var draw_pile_button: Button
var card_widgets: Array
var previous_hand_instance_ids: Array[String] = []
var draw_card_fx: Array = []
var draw_card_fx_serial := 0
var last_draw_count := -1
var draw_pile_pulse_timer := 0.0


func setup(hand_layer_node: Control, draw_button: Button, widgets: Array) -> void:
	hand_layer = hand_layer_node
	draw_pile_button = draw_button
	card_widgets = widgets


func reset() -> void:
	for fx in draw_card_fx:
		if not (fx is Dictionary):
			continue
		var fx_data: Dictionary = fx as Dictionary
		if not fx_data.has("node"):
			continue
		var node: Node = fx_data["node"] as Node
		if node != null:
			node.queue_free()
	draw_card_fx.clear()
	previous_hand_instance_ids.clear()
	last_draw_count = -1
	draw_pile_pulse_timer = 0.0
	if draw_pile_button != null:
		draw_pile_button.scale = Vector2.ONE
		draw_pile_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	for widget in card_widgets:
		if widget is Dictionary:
			(widget as Dictionary).erase("draw_reveal_pending")
			(widget as Dictionary).erase("draw_arrival_timer")


func set_draw_count(draw_count: int, gameplay_active: bool) -> void:
	if draw_pile_button != null:
		draw_pile_button.pivot_offset = draw_pile_button.size * 0.5
	if gameplay_active and last_draw_count >= 0 and draw_count < last_draw_count:
		draw_pile_pulse_timer = DRAW_PILE_PULSE_TIME
	last_draw_count = draw_count


func sync_after_layout(cards: Array, gameplay_active: bool, suppress_new_cards := false) -> void:
	var current_ids := _hand_instance_ids(cards)
	var should_animate := gameplay_active and not previous_hand_instance_ids.is_empty()
	should_animate = should_animate and current_ids.size() > previous_hand_instance_ids.size()
	should_animate = should_animate and not suppress_new_cards
	if should_animate:
		var spawned_count := 0
		for index in range(current_ids.size()):
			if previous_hand_instance_ids.has(current_ids[index]):
				continue
			if index >= cards.size() or not (cards[index] is Dictionary):
				continue
			_spawn_draw_card_fx(index, float(spawned_count) * 0.055)
			spawned_count += 1
	previous_hand_instance_ids = current_ids


func update(delta: float) -> void:
	_update_draw_pile_feedback(delta)
	_update_draw_card_fx(delta)


func card_feedback(widget: Dictionary, delta: float) -> Dictionary:
	if bool(widget.get("draw_reveal_pending", false)):
		return {"hidden": true, "pulse": 0.0}
	var pulse_timer := float(widget.get("draw_arrival_timer", 0.0))
	if pulse_timer <= 0.0:
		return {"hidden": false, "pulse": 0.0}
	pulse_timer = maxf(0.0, pulse_timer - delta)
	widget["draw_arrival_timer"] = pulse_timer
	return {"hidden": false, "pulse": pulse_timer / DRAW_CARD_ARRIVAL_PULSE_TIME}


func _hand_instance_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for index in range(cards.size()):
		if cards[index] is Dictionary:
			var card: Dictionary = cards[index] as Dictionary
			var fallback := "%s:%d" % [String(card.get("id", "card")), index]
			ids.append(String(card.get("instance_id", fallback)))
		else:
			ids.append("empty:%d" % index)
	return ids


func _spawn_draw_card_fx(index: int, delay: float) -> void:
	var next_serial := draw_card_fx_serial + 1
	var spawn_data := (
		HUD_DRAW_CARD_FX_SPAWN
		. build(
			{
				"index": index,
				"delay": delay,
				"serial": next_serial,
				"hand_layer": hand_layer,
				"draw_pile_button": draw_pile_button,
				"card_widgets": card_widgets,
				"card_size": HAND_CARD_SIZE,
			}
		)
	)
	if spawn_data.is_empty():
		return
	draw_card_fx_serial = next_serial
	var widget: Dictionary = card_widgets[index]
	widget["draw_reveal_pending"] = true
	draw_card_fx.append(spawn_data["fx"])


func _draw_pile_center_in_hand_layer() -> Vector2:
	return HUD_DRAW_CARD_FX_SPAWN.draw_pile_center_in_hand_layer(hand_layer, draw_pile_button)


func _update_draw_pile_feedback(delta: float) -> void:
	if draw_pile_button == null:
		return
	draw_pile_pulse_timer = maxf(0.0, draw_pile_pulse_timer - delta)
	if draw_pile_pulse_timer <= 0.0:
		draw_pile_button.scale = Vector2.ONE
		draw_pile_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var weight := draw_pile_pulse_timer / DRAW_PILE_PULSE_TIME
	var pulse := 1.0 + 0.12 * (1.0 - absf(weight * 2.0 - 1.0))
	draw_pile_button.scale = Vector2(pulse, pulse)
	draw_pile_button.modulate = Color(1.0, 0.92, 0.60, 1.0)


func _update_draw_card_fx(delta: float) -> void:
	for offset in range(draw_card_fx.size()):
		var fx_index := draw_card_fx.size() - 1 - offset
		var fx: Dictionary = draw_card_fx[fx_index] as Dictionary
		var node: PanelContainer = fx["node"] as PanelContainer
		if node == null:
			draw_card_fx.remove_at(fx_index)
			continue
		fx["time"] = float(fx.get("time", 0.0)) + delta
		if _update_one_draw_card_fx(fx, node):
			draw_card_fx[fx_index] = fx
		else:
			draw_card_fx.remove_at(fx_index)


func _update_one_draw_card_fx(fx: Dictionary, node: PanelContainer) -> bool:
	var local_time := float(fx["time"]) - float(fx.get("delay", 0.0))
	if local_time < 0.0:
		node.visible = false
		return true
	node.visible = true
	var target_index := int(fx.get("target_index", -1))
	if not _is_valid_draw_fx_target(target_index):
		node.queue_free()
		return false
	var target_widget: Dictionary = card_widgets[target_index]
	var target_panel: PanelContainer = target_widget["panel"] as PanelContainer
	var target_position: Vector2 = target_widget.get("base_position", target_panel.position)
	var target_scale: Vector2 = target_widget.get("base_scale", target_panel.scale)
	var target_rotation := float(target_widget.get("base_rotation", target_panel.rotation))
	if local_time <= DRAW_CARD_FX_DURATION:
		_apply_draw_card_flight(fx, node, target_position, target_scale, target_rotation, local_time)
		return true
	target_widget["draw_reveal_pending"] = false
	target_widget["draw_arrival_timer"] = DRAW_CARD_ARRIVAL_PULSE_TIME
	target_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	node.queue_free()
	return false


func _apply_draw_card_flight(
	fx: Dictionary, node: PanelContainer, target_position: Vector2, target_scale: Vector2, target_rotation: float, local_time: float
) -> void:
	var t := clampf(local_time / DRAW_CARD_FX_DURATION, 0.0, 1.0)
	var ease := 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
	var start_position: Vector2 = fx["start_position"] as Vector2
	var arc_offset := Vector2(0.0, -DRAW_CARD_ARC_HEIGHT * 4.0 * t * (1.0 - t))
	var start_scale := Vector2(DRAW_CARD_START_SCALE, DRAW_CARD_START_SCALE)
	node.position = start_position + (target_position - start_position) * ease + arc_offset
	node.scale = start_scale + (target_scale - start_scale) * ease
	node.rotation = lerpf(float(fx.get("start_rotation", -0.16)), target_rotation, ease)
	node.modulate = Color(1.0, 1.0, 1.0, clampf(t * 1.7, 0.0, 1.0))


func _is_valid_draw_fx_target(index: int) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return (card_widgets[index]["panel"] as PanelContainer).visible
