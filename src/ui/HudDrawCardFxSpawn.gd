extends RefCounted
class_name HudDrawCardFxSpawn

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")


static func build(request: Dictionary) -> Dictionary:
	var hand_layer: Control = request.get("hand_layer") as Control
	var card_widgets: Array = request.get("card_widgets", [])
	var index := int(request.get("index", -1))
	if not _is_valid_draw_fx_target(index, card_widgets) or hand_layer == null:
		return {}
	var target_panel: PanelContainer = (card_widgets[index] as Dictionary)["panel"] as PanelContainer
	var ghost := _prepare_node(target_panel, Vector2(request.get("card_size", Vector2.ZERO)), int(request.get("serial", 0)))
	if ghost == null:
		return {}
	hand_layer.add_child(ghost)
	var source_center := draw_pile_center_in_hand_layer(hand_layer, request.get("draw_pile_button") as Button)
	return {"fx": _fx_data(ghost, index, source_center, Vector2(request.get("card_size", Vector2.ZERO)), float(request.get("delay", 0.0)))}


static func draw_pile_center_in_hand_layer(hand_layer: Control, draw_pile_button: Button) -> Vector2:
	if hand_layer == null or draw_pile_button == null:
		return Vector2.ZERO
	var hand_origin := hand_layer.get_global_rect().position
	var pile_rect := draw_pile_button.get_global_rect()
	return pile_rect.position - hand_origin + pile_rect.size * 0.5


static func _prepare_node(target_panel: PanelContainer, card_size: Vector2, serial: int) -> PanelContainer:
	var ghost := target_panel.duplicate() as PanelContainer
	if ghost == null:
		return null
	HUD_CARD_WIDGETS.clear_unique_names(ghost)
	HUD_CARD_WIDGETS.set_card_descendants_mouse_filter(ghost)
	ghost.name = "DrawCardFx%d" % serial
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = card_size
	ghost.pivot_offset = card_size * 0.5
	ghost.z_index = 720 + serial
	ghost.visible = false
	return ghost


static func _fx_data(ghost: PanelContainer, index: int, source_center: Vector2, card_size: Vector2, delay: float) -> Dictionary:
	return {
		"node": ghost,
		"target_index": index,
		"start_position": source_center - card_size * 0.5,
		"delay": delay,
		"time": 0.0,
		"start_rotation": -0.16,
	}


static func _is_valid_draw_fx_target(index: int, card_widgets: Array) -> bool:
	if index < 0 or index >= card_widgets.size():
		return false
	return ((card_widgets[index] as Dictionary)["panel"] as PanelContainer).visible
