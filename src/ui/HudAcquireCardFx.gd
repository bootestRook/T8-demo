extends RefCounted
class_name HudAcquireCardFx

const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const ACQUIRE_CARD_FX_DURATION := 0.42
const ACQUIRE_CARD_FLIP_DURATION := 0.16
const ACQUIRE_CARD_START_SCALE := 1.05
const ACQUIRE_CARD_DRAW_PILE_SCALE := 0.42
const ACQUIRE_CARD_ARC_HEIGHT := 168.0
const ACQUIRE_CARD_ARRIVAL_PULSE_TIME := 0.24
const ACQUIRE_PILE_PULSE_TIME := 0.28
const HUD_ACQUIRE_CARD_FX_SPAWN := preload("res://src/ui/HudAcquireCardFxSpawn.gd")

var hand_layer: Control
var draw_pile_button: Button
var card_widgets: Array
var acquire_card_fx: Array = []
var acquire_card_fx_serial := 0
var last_acquire_serial := 0
var draw_pile_pulse_timer := 0.0


func setup(hand_layer_node: Control, draw_button: Button, widgets: Array) -> void:
	hand_layer = hand_layer_node
	draw_pile_button = draw_button
	card_widgets = widgets


func reset() -> void:
	for fx in acquire_card_fx:
		if not (fx is Dictionary):
			continue
		var fx_data: Dictionary = fx as Dictionary
		var node: Node = fx_data.get("node", null) as Node
		if node != null:
			node.queue_free()
	acquire_card_fx.clear()
	draw_pile_pulse_timer = 0.0
	if draw_pile_button != null:
		draw_pile_button.scale = Vector2.ONE
		draw_pile_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	for widget in card_widgets:
		if widget is Dictionary:
			(widget as Dictionary).erase("acquire_reveal_pending")
			(widget as Dictionary).erase("acquire_arrival_timer")


func sync_acquire_event(event: Dictionary, source_global_center: Vector2, gameplay_active: bool) -> void:
	if hand_layer == null or not gameplay_active or event.is_empty():
		return
	var serial := int(event.get("serial", 0))
	if serial <= 0 or serial == last_acquire_serial:
		return
	last_acquire_serial = serial
	_spawn_acquire_card_fx(event, source_global_center)


func sync_from_snapshot(snapshot: Dictionary, source_global_center: Vector2, gameplay_active: bool) -> void:
	var event_variant: Variant = snapshot.get("card_acquire_event", {})
	if event_variant is Dictionary:
		sync_acquire_event(event_variant as Dictionary, source_global_center, gameplay_active)


func update(delta: float) -> void:
	_update_draw_pile_feedback(delta)
	_update_acquire_card_fx(delta)


func apply_card_feedback(widget: Dictionary, panel: PanelContainer, delta: float) -> void:
	var feedback := card_feedback(widget, delta)
	if bool(feedback.get("hidden", false)):
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	elif float(feedback.get("pulse", 0.0)) > 0.0:
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


func card_feedback(widget: Dictionary, delta: float) -> Dictionary:
	if bool(widget.get("acquire_reveal_pending", false)):
		return {"hidden": true, "pulse": 0.0}
	var pulse_timer := float(widget.get("acquire_arrival_timer", 0.0))
	if pulse_timer <= 0.0:
		return {"hidden": false, "pulse": 0.0}
	pulse_timer = maxf(0.0, pulse_timer - delta)
	widget["acquire_arrival_timer"] = pulse_timer
	return {"hidden": false, "pulse": pulse_timer / ACQUIRE_CARD_ARRIVAL_PULSE_TIME}


func should_suppress_draw_fx(snapshot: Dictionary) -> bool:
	var event_variant: Variant = snapshot.get("card_acquire_event", {})
	if not (event_variant is Dictionary):
		return false
	var event: Dictionary = event_variant as Dictionary
	return int(event.get("serial", 0)) > last_acquire_serial and String(event.get("destination", "")) == "hand"


func _spawn_acquire_card_fx(event: Dictionary, source_global_center: Vector2) -> void:
	var destination := String(event.get("destination", ""))
	var target_index := int(event.get("hand_index", -1))
	var next_serial := acquire_card_fx_serial + 1
	var spawn_data := HUD_ACQUIRE_CARD_FX_SPAWN.build(_spawn_request(event, source_global_center, next_serial))
	if spawn_data.is_empty():
		return
	acquire_card_fx_serial = next_serial
	var node: PanelContainer = spawn_data["node"] as PanelContainer
	hand_layer.add_child(node)
	if destination == "hand" and _is_valid_hand_target(target_index):
		var target_widget: Dictionary = card_widgets[target_index]
		target_widget["acquire_reveal_pending"] = true
	if destination == "draw_pile":
		draw_pile_pulse_timer = ACQUIRE_PILE_PULSE_TIME
	acquire_card_fx.append(spawn_data["fx"] as Dictionary)


func _spawn_request(event: Dictionary, source_global_center: Vector2, serial: int) -> Dictionary:
	return {
		"event": event,
		"source_global_center": source_global_center,
		"hand_layer": hand_layer,
		"draw_pile_button": draw_pile_button,
		"card_widgets": card_widgets,
		"serial": serial,
		"card_size": HAND_CARD_SIZE,
		"draw_pile_scale": ACQUIRE_CARD_DRAW_PILE_SCALE,
	}


func _update_draw_pile_feedback(delta: float) -> void:
	if draw_pile_button == null:
		return
	draw_pile_pulse_timer = maxf(0.0, draw_pile_pulse_timer - delta)
	if draw_pile_pulse_timer <= 0.0:
		return
	var weight := draw_pile_pulse_timer / ACQUIRE_PILE_PULSE_TIME
	var pulse := 1.0 + 0.16 * (1.0 - absf(weight * 2.0 - 1.0))
	draw_pile_button.scale = Vector2(pulse, pulse)
	draw_pile_button.modulate = Color(1.0, 0.88, 0.42, 1.0)


func _update_acquire_card_fx(delta: float) -> void:
	for offset in range(acquire_card_fx.size()):
		var fx_index := acquire_card_fx.size() - 1 - offset
		var fx: Dictionary = acquire_card_fx[fx_index] as Dictionary
		var node: PanelContainer = fx["node"] as PanelContainer
		if node == null:
			acquire_card_fx.remove_at(fx_index)
			continue
		fx["time"] = float(fx.get("time", 0.0)) + delta
		if _update_one_acquire_card_fx(fx, node):
			acquire_card_fx[fx_index] = fx
		else:
			acquire_card_fx.remove_at(fx_index)


func _update_one_acquire_card_fx(fx: Dictionary, node: PanelContainer) -> bool:
	var local_time := float(fx.get("time", 0.0))
	var target_position: Vector2 = fx["target_position"] as Vector2
	var target_scale: Vector2 = fx["target_scale"] as Vector2
	var target_rotation := float(fx.get("target_rotation", 0.0))
	if local_time <= ACQUIRE_CARD_FX_DURATION:
		_apply_acquire_card_flight(fx, node, target_position, target_scale, target_rotation, local_time)
		return true
	var flip_time := local_time - ACQUIRE_CARD_FX_DURATION
	if flip_time <= ACQUIRE_CARD_FLIP_DURATION:
		_apply_acquire_card_settle(node, target_position, target_scale, target_rotation, flip_time)
		return true
	_finish_acquire_card_fx(fx, node)
	return false


func _apply_acquire_card_flight(
	fx: Dictionary, node: PanelContainer, target_position: Vector2, target_scale: Vector2, target_rotation: float, local_time: float
) -> void:
	var t := clampf(local_time / ACQUIRE_CARD_FX_DURATION, 0.0, 1.0)
	var ease := 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
	var start_position: Vector2 = fx["start_position"] as Vector2
	var arc_offset := Vector2(0.0, -ACQUIRE_CARD_ARC_HEIGHT * 4.0 * t * (1.0 - t))
	var start_scale := Vector2(ACQUIRE_CARD_START_SCALE, ACQUIRE_CARD_START_SCALE)
	node.position = start_position + (target_position - start_position) * ease + arc_offset
	node.scale = start_scale + (target_scale - start_scale) * ease
	node.rotation = lerpf(float(fx.get("start_rotation", -0.08)), target_rotation, ease)
	node.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _apply_acquire_card_settle(
	node: PanelContainer, target_position: Vector2, target_scale: Vector2, target_rotation: float, flip_time: float
) -> void:
	var t := clampf(flip_time / ACQUIRE_CARD_FLIP_DURATION, 0.0, 1.0)
	var pulse := 1.0 + 0.06 * (1.0 - t)
	node.position = target_position + Vector2(0.0, -10.0 * (1.0 - t))
	node.scale = target_scale * pulse
	node.rotation = target_rotation
	node.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _finish_acquire_card_fx(fx: Dictionary, node: PanelContainer) -> void:
	var destination := String(fx.get("destination", ""))
	var target_index := int(fx.get("target_index", -1))
	if destination == "hand" and _is_valid_hand_target(target_index):
		var target_widget: Dictionary = card_widgets[target_index]
		target_widget["acquire_reveal_pending"] = false
		target_widget["acquire_arrival_timer"] = ACQUIRE_CARD_ARRIVAL_PULSE_TIME
		var target_panel: PanelContainer = target_widget["panel"] as PanelContainer
		target_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	node.queue_free()


func _is_valid_hand_target(index: int) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return (card_widgets[index]["panel"] as PanelContainer).visible
