extends RefCounted
class_name HudAcquireCardFxSpawn

const HUD_ACQUIRE_CARD_FX_CARD_BUILDER := preload("res://src/ui/HudAcquireCardFxCardBuilder.gd")


static func build(request: Dictionary) -> Dictionary:
	var event: Dictionary = request["event"] as Dictionary
	var card_variant: Variant = event.get("card", {})
	if not (card_variant is Dictionary):
		return {}
	var destination := String(event.get("destination", ""))
	var target_index := int(event.get("hand_index", -1))
	var card_widgets: Array = request["card_widgets"] as Array
	var card_size: Vector2 = request["card_size"] as Vector2
	var node := HUD_ACQUIRE_CARD_FX_CARD_BUILDER.build(card_variant as Dictionary, destination, target_index, card_widgets, card_size)
	if node == null:
		return {}
	_prepare_node(node, int(request["serial"]), card_size)
	return {
		"node": node,
		"destination": destination,
		"target_index": target_index,
		"fx": _fx_data(request, node, destination, target_index),
	}


static func _prepare_node(node: PanelContainer, serial: int, card_size: Vector2) -> void:
	node.name = "AcquireCardFx%d" % serial
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = card_size
	node.pivot_offset = card_size * 0.5
	node.z_index = 760 + serial
	node.visible = true


static func _fx_data(request: Dictionary, node: PanelContainer, destination: String, target_index: int) -> Dictionary:
	var hand_layer: Control = request["hand_layer"] as Control
	var card_widgets: Array = request["card_widgets"] as Array
	var card_size: Vector2 = request["card_size"] as Vector2
	return {
		"node": node,
		"destination": destination,
		"target_index": target_index,
		"start_position": _source_position_in_hand_layer(request["source_global_center"] as Vector2, hand_layer, card_size),
		"target_position":
		_target_position_for_destination(
			destination, target_index, hand_layer, request["draw_pile_button"] as Button, card_widgets, card_size
		),
		"target_scale": _target_scale_for_destination(destination, float(request["draw_pile_scale"])),
		"target_rotation": _target_rotation_for_destination(destination, target_index, card_widgets),
		"time": 0.0,
		"start_rotation": -0.08,
	}


static func _source_position_in_hand_layer(source_global_center: Vector2, hand_layer: Control, card_size: Vector2) -> Vector2:
	var center := source_global_center
	if center == Vector2.ZERO:
		center = hand_layer.get_global_rect().position + hand_layer.size * 0.5
	var hand_origin := hand_layer.get_global_rect().position
	return center - hand_origin - card_size * 0.5


static func _target_position_for_destination(
	destination: String, target_index: int, hand_layer: Control, draw_pile_button: Button, card_widgets: Array, card_size: Vector2
) -> Vector2:
	if destination == "hand" and _is_valid_hand_target(target_index, card_widgets):
		var target_widget: Dictionary = card_widgets[target_index]
		var target_panel: PanelContainer = target_widget["panel"] as PanelContainer
		return target_widget.get("base_position", target_panel.position)
	if draw_pile_button != null:
		var hand_origin := hand_layer.get_global_rect().position
		var pile_rect := draw_pile_button.get_global_rect()
		return pile_rect.position - hand_origin + pile_rect.size * 0.5 - card_size * 0.5
	return Vector2.ZERO


static func _target_scale_for_destination(destination: String, draw_pile_scale: float) -> Vector2:
	if destination == "draw_pile":
		return Vector2(draw_pile_scale, draw_pile_scale)
	return Vector2.ONE


static func _target_rotation_for_destination(destination: String, target_index: int, card_widgets: Array) -> float:
	if destination == "hand" and _is_valid_hand_target(target_index, card_widgets):
		var target_widget: Dictionary = card_widgets[target_index]
		var target_panel: PanelContainer = target_widget["panel"] as PanelContainer
		return float(target_widget.get("base_rotation", target_panel.rotation))
	return 0.10


static func _is_valid_hand_target(index: int, card_widgets: Array) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return (card_widgets[index]["panel"] as PanelContainer).visible
