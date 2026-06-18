extends RefCounted
class_name HudDiscardHandFxSpawn

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")


static func build(request: Dictionary) -> Dictionary:
	var hand_layer: Control = request.get("hand_layer") as Control
	var card_widgets: Array = request.get("card_widgets", [])
	var card_size: Vector2 = request.get("card_size", Vector2.ZERO)
	var index := int(request.get("index", -1))
	if not _is_valid_discard_fx_source(index, card_widgets) or hand_layer == null:
		return {}
	var source_panel: PanelContainer = (card_widgets[index] as Dictionary)["panel"] as PanelContainer
	var ghost := _prepare_node(source_panel, card_size, int(request.get("serial", 0)))
	if ghost == null:
		return {}
	hand_layer.add_child(ghost)
	return {"fx": _fx_data(ghost, source_panel, index, float(request.get("delay", 0.0)))}


static func discard_pile_center_in_hand_layer(hand_layer: Control, discard_pile_button: Button) -> Vector2:
	if hand_layer == null or discard_pile_button == null:
		return Vector2.ZERO
	var hand_origin := hand_layer.get_global_rect().position
	var pile_rect := discard_pile_button.get_global_rect()
	return pile_rect.position - hand_origin + pile_rect.size * 0.5


static func _prepare_node(source_panel: PanelContainer, card_size: Vector2, serial: int) -> PanelContainer:
	var ghost := source_panel.duplicate() as PanelContainer
	if ghost == null:
		return null
	HUD_CARD_WIDGETS.clear_unique_names(ghost)
	HUD_CARD_WIDGETS.set_card_descendants_mouse_filter(ghost)
	ghost.name = "DiscardCardFx%d" % serial
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = card_size
	ghost.position = source_panel.position
	ghost.scale = source_panel.scale
	ghost.rotation = source_panel.rotation
	ghost.pivot_offset = card_size * 0.5
	ghost.z_index = 760 + serial
	ghost.modulate = Color(1.0, 1.0, 1.0, 1.0)
	return ghost


static func _fx_data(ghost: PanelContainer, source_panel: PanelContainer, index: int, delay: float) -> Dictionary:
	return {
		"node": ghost,
		"delay": delay,
		"time": 0.0,
		"start_position": source_panel.position,
		"start_scale": source_panel.scale,
		"start_rotation": source_panel.rotation,
		"end_rotation": -0.38 + float(index) * 0.055,
	}


static func _is_valid_discard_fx_source(index: int, card_widgets: Array) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return ((card_widgets[index] as Dictionary)["panel"] as PanelContainer).visible
