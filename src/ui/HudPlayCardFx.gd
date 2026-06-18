extends RefCounted
class_name HudPlayCardFx

const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const FLY_DURATION := 0.20
const HOLD_DURATION := 0.34
const DISSOLVE_DURATION := 0.38
const DISPLAY_SCALE := 1.18
const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")
const HUD_PLAY_CARD_FX_FRAGMENTS := preload("res://src/ui/HudPlayCardFxFragments.gd")

var hand_layer: Control
var card_widgets: Array
var play_card_fx: Array = []
var play_card_fx_serial := 0


func setup(hand_layer_node: Control, widgets: Array) -> void:
	hand_layer = hand_layer_node
	card_widgets = widgets


func reset() -> void:
	for fx in play_card_fx:
		if fx is Dictionary:
			_free_fx(fx as Dictionary)
	play_card_fx.clear()


func update(delta: float) -> void:
	for offset in range(play_card_fx.size()):
		var fx_index := play_card_fx.size() - 1 - offset
		var fx: Dictionary = play_card_fx[fx_index] as Dictionary
		if _update_one_fx(fx, delta):
			play_card_fx[fx_index] = fx
		else:
			_free_fx(fx)
			play_card_fx.remove_at(fx_index)


func capture(index: int) -> Dictionary:
	if hand_layer == null or index < 0 or index >= card_widgets.size():
		return {}
	var widget: Dictionary = card_widgets[index]
	var source_panel: PanelContainer = widget["panel"] as PanelContainer
	if source_panel == null or not source_panel.visible:
		return {}
	var ghost := source_panel.duplicate() as PanelContainer
	if ghost == null:
		return {}
	HUD_CARD_WIDGETS.clear_unique_names(ghost)
	HUD_CARD_WIDGETS.set_card_descendants_mouse_filter(ghost)
	play_card_fx_serial += 1
	ghost.name = "PlayCardFx%d" % play_card_fx_serial
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = HAND_CARD_SIZE
	ghost.pivot_offset = HAND_CARD_SIZE * 0.5
	ghost.z_index = 780 + play_card_fx_serial
	ghost.visible = false
	hand_layer.add_child(ghost)
	return {
		"node": ghost,
		"start_position": widget.get("view_position", source_panel.position),
		"start_scale": widget.get("view_scale", source_panel.scale),
		"start_rotation": float(widget.get("view_rotation", source_panel.rotation)),
		"display_position": _display_position(),
		"time": 0.0,
		"shards": [],
		"shards_spawned": false,
	}


func commit(captured_fx: Dictionary) -> void:
	if captured_fx.is_empty() or not captured_fx.has("node"):
		return
	var node: PanelContainer = captured_fx["node"] as PanelContainer
	if node == null:
		return
	node.visible = true
	play_card_fx.append(captured_fx)


func cancel(captured_fx: Dictionary) -> void:
	if captured_fx.is_empty():
		return
	_free_fx(captured_fx)


func _update_one_fx(fx: Dictionary, delta: float) -> bool:
	var node: PanelContainer = fx.get("node", null) as PanelContainer
	if node == null:
		return false
	var time := float(fx.get("time", 0.0)) + delta
	fx["time"] = time
	if time <= FLY_DURATION:
		_apply_fly(fx, node, time / FLY_DURATION)
		return true
	if time <= FLY_DURATION + HOLD_DURATION:
		_apply_hold(fx, node, (time - FLY_DURATION) / HOLD_DURATION)
		return true
	var dissolve_time := time - FLY_DURATION - HOLD_DURATION
	if not bool(fx.get("shards_spawned", false)):
		_spawn_shards(fx, node)
		fx["shards_spawned"] = true
	if dissolve_time <= DISSOLVE_DURATION:
		_apply_dissolve(fx, node, dissolve_time / DISSOLVE_DURATION)
		return true
	return false


func _apply_fly(fx: Dictionary, node: PanelContainer, raw_t: float) -> void:
	var t := _ease_out(clampf(raw_t, 0.0, 1.0))
	var start_position: Vector2 = fx["start_position"]
	var display_position: Vector2 = fx["display_position"]
	var start_scale: Vector2 = fx["start_scale"]
	node.position = start_position + (display_position - start_position) * t
	node.scale = start_scale + (Vector2(DISPLAY_SCALE, DISPLAY_SCALE) - start_scale) * t
	node.rotation = lerpf(float(fx["start_rotation"]), 0.0, t)
	node.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _apply_hold(fx: Dictionary, node: PanelContainer, raw_t: float) -> void:
	var t := clampf(raw_t, 0.0, 1.0)
	var pulse := 1.0 + 0.035 * (1.0 - absf(t * 2.0 - 1.0))
	node.position = fx["display_position"]
	node.scale = Vector2(DISPLAY_SCALE * pulse, DISPLAY_SCALE * pulse)
	node.rotation = 0.0
	node.modulate = Color(1.0, 0.94, 0.68, 1.0)


func _spawn_shards(fx: Dictionary, node: PanelContainer) -> void:
	var display_position: Vector2 = fx["display_position"]
	var result := HUD_PLAY_CARD_FX_FRAGMENTS.spawn(hand_layer, display_position, node.z_index, play_card_fx_serial)
	fx["shards"] = result.get("shards", [])
	play_card_fx_serial = int(result.get("serial", play_card_fx_serial))


func _apply_dissolve(fx: Dictionary, node: PanelContainer, raw_t: float) -> void:
	var t := _ease_out(clampf(raw_t, 0.0, 1.0))
	var alpha := 1.0 - t
	node.position = fx["display_position"]
	node.scale = Vector2(DISPLAY_SCALE * (1.0 - 0.28 * t), DISPLAY_SCALE * (1.0 - 0.28 * t))
	node.modulate = Color(1.0, 0.78, 0.42, alpha * 0.22)
	var shards: Array = fx.get("shards", [])
	HUD_PLAY_CARD_FX_FRAGMENTS.apply(shards, raw_t)


func _display_position() -> Vector2:
	if hand_layer == null:
		return Vector2.ZERO
	var viewport_size := hand_layer.get_viewport().get_visible_rect().size
	var hand_origin := hand_layer.get_global_rect().position
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.60) - hand_origin
	center.y = minf(center.y, -HAND_CARD_SIZE.y * 0.44)
	return center - HAND_CARD_SIZE * 0.5


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _free_fx(fx: Dictionary) -> void:
	var node: Node = fx.get("node", null) as Node
	if node != null:
		node.queue_free()
	var shards: Array = fx.get("shards", [])
	HUD_PLAY_CARD_FX_FRAGMENTS.free_shards(shards)
