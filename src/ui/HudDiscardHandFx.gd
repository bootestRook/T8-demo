extends RefCounted
class_name HudDiscardHandFx

const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const DISCARD_CARD_FX_DURATION := 0.34
const DISCARD_CARD_STAGGER := 0.055
const DISCARD_CARD_END_SCALE := 0.34
const DISCARD_CARD_ARC_HEIGHT := 92.0
const DISCARD_PILE_PULSE_TIME := 0.24
const HUD_DISCARD_HAND_FX_SPAWN := preload("res://src/ui/HudDiscardHandFxSpawn.gd")

var hand_layer: Control
var discard_pile_button: Button
var card_widgets: Array
var discard_card_fx: Array = []
var discard_card_fx_serial := 0
var active := false
var completion_pending := false
var discard_pile_pulse_timer := 0.0


func setup(hand_layer_node: Control, discard_button: Button, widgets: Array) -> void:
	hand_layer = hand_layer_node
	discard_pile_button = discard_button
	card_widgets = widgets


func reset() -> void:
	for fx in discard_card_fx:
		if not (fx is Dictionary):
			continue
		var fx_data: Dictionary = fx as Dictionary
		if not fx_data.has("node"):
			continue
		var node: Node = fx_data["node"] as Node
		if node != null:
			node.queue_free()
	discard_card_fx.clear()
	_clear_pending_flags()
	active = false
	completion_pending = false
	discard_pile_pulse_timer = 0.0
	if discard_pile_button != null:
		discard_pile_button.scale = Vector2.ONE
		discard_pile_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func start(hand_count: int) -> bool:
	if active or hand_layer == null:
		return false
	_clear_pending_flags()
	var spawned_count := 0
	var visible_count := mini(hand_count, card_widgets.size())
	for index in range(visible_count):
		if _spawn_discard_card_fx(index, float(spawned_count) * DISCARD_CARD_STAGGER):
			spawned_count += 1
	if spawned_count <= 0:
		return false
	active = true
	completion_pending = false
	return true


func update(delta: float) -> void:
	_update_discard_pile_feedback(delta)
	_update_discard_card_fx(delta)


func is_active() -> bool:
	return active


func consume_completed() -> bool:
	if not completion_pending:
		return false
	completion_pending = false
	_clear_pending_flags()
	return true


func card_feedback(widget: Dictionary) -> Dictionary:
	return {"hidden": bool(widget.get("discard_flight_pending", false))}


func _spawn_discard_card_fx(index: int, delay: float) -> bool:
	var next_serial := discard_card_fx_serial + 1
	var spawn_data := (
		HUD_DISCARD_HAND_FX_SPAWN
		. build(
			{
				"index": index,
				"delay": delay,
				"serial": next_serial,
				"hand_layer": hand_layer,
				"card_widgets": card_widgets,
				"card_size": HAND_CARD_SIZE,
			}
		)
	)
	if spawn_data.is_empty():
		return false
	discard_card_fx_serial = next_serial
	var widget: Dictionary = card_widgets[index]
	widget["discard_flight_pending"] = true
	discard_card_fx.append(spawn_data["fx"])
	return true


func _update_discard_card_fx(delta: float) -> void:
	if discard_card_fx.is_empty():
		if active:
			active = false
			completion_pending = true
		return
	for offset in range(discard_card_fx.size()):
		var fx_index := discard_card_fx.size() - 1 - offset
		var fx: Dictionary = discard_card_fx[fx_index] as Dictionary
		var node: PanelContainer = fx["node"] as PanelContainer
		if node == null:
			discard_card_fx.remove_at(fx_index)
			continue
		fx["time"] = float(fx.get("time", 0.0)) + delta
		if _update_one_discard_card_fx(fx, node):
			discard_card_fx[fx_index] = fx
		else:
			discard_card_fx.remove_at(fx_index)


func _update_one_discard_card_fx(fx: Dictionary, node: PanelContainer) -> bool:
	var local_time := float(fx["time"]) - float(fx.get("delay", 0.0))
	if local_time < 0.0:
		node.visible = false
		return true
	node.visible = true
	if local_time <= DISCARD_CARD_FX_DURATION:
		_apply_discard_card_flight(fx, node, local_time)
		return true
	node.queue_free()
	discard_pile_pulse_timer = DISCARD_PILE_PULSE_TIME
	return false


func _apply_discard_card_flight(fx: Dictionary, node: PanelContainer, local_time: float) -> void:
	var t := clampf(local_time / DISCARD_CARD_FX_DURATION, 0.0, 1.0)
	var ease := t * t * (3.0 - 2.0 * t)
	var start_position: Vector2 = fx["start_position"] as Vector2
	var start_scale: Vector2 = fx["start_scale"] as Vector2
	var end_scale := Vector2(DISCARD_CARD_END_SCALE, DISCARD_CARD_END_SCALE)
	var end_position := _discard_pile_center_in_hand_layer() - HAND_CARD_SIZE * 0.5
	var arc_offset := Vector2(0.0, -DISCARD_CARD_ARC_HEIGHT * 4.0 * t * (1.0 - t))
	node.position = start_position + (end_position - start_position) * ease + arc_offset
	node.scale = start_scale + (end_scale - start_scale) * ease
	node.rotation = lerpf(float(fx.get("start_rotation", 0.0)), float(fx.get("end_rotation", -0.38)), ease)
	var alpha := 1.0 - clampf((t - 0.72) / 0.28, 0.0, 1.0)
	node.modulate = Color(1.0, 0.92 + 0.08 * (1.0 - t), 0.72 + 0.28 * (1.0 - t), alpha)


func _discard_pile_center_in_hand_layer() -> Vector2:
	return HUD_DISCARD_HAND_FX_SPAWN.discard_pile_center_in_hand_layer(hand_layer, discard_pile_button)


func _update_discard_pile_feedback(delta: float) -> void:
	if discard_pile_button == null:
		return
	discard_pile_button.pivot_offset = discard_pile_button.size * 0.5
	discard_pile_pulse_timer = maxf(0.0, discard_pile_pulse_timer - delta)
	if discard_pile_pulse_timer <= 0.0:
		discard_pile_button.scale = Vector2.ONE
		discard_pile_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var weight := discard_pile_pulse_timer / DISCARD_PILE_PULSE_TIME
	var pulse := 1.0 + 0.14 * (1.0 - absf(weight * 2.0 - 1.0))
	discard_pile_button.scale = Vector2(pulse, pulse)
	discard_pile_button.modulate = Color(1.0, 0.84, 0.50, 1.0)


func _clear_pending_flags() -> void:
	for widget in card_widgets:
		if widget is Dictionary:
			(widget as Dictionary).erase("discard_flight_pending")
