extends RefCounted
class_name HudCardInteractionPort

var hud: Node = null


func setup(owner: Node) -> void:
	hud = owner


func pointer_position() -> Vector2:
	return hud.get_viewport().get_mouse_position()


func mark_input_handled() -> void:
	hud.get_viewport().set_input_as_handled()


func sync_card_toast_visibility() -> void:
	hud.call("_sync_card_toast_visibility")


func can_handle_card_input() -> bool:
	return bool(hud.call("_can_handle_card_input"))


func current_hand_count() -> int:
	return int(hud.call("_current_hand_count"))


func card_index_at_point(point: Vector2) -> int:
	return int(hud.call("_card_index_at_point", point))


func card_index_for_panel(panel: PanelContainer) -> int:
	return int(hud.call("_card_index_for_panel", panel))


func is_card_cooling_down(index: int) -> bool:
	return bool(hud.call("_is_card_cooling_down", index))


func card_cooldown_message(index: int) -> String:
	return String(hud.call("_card_cooldown_message", index))


func is_pointer_in_play_zone(point: Vector2) -> bool:
	return bool(hud.call("_is_pointer_in_play_zone", point))


func card_reorder_index_at_point(point: Vector2, dragged_index: int) -> int:
	return int(hud.call("_card_reorder_index_at_point", point, dragged_index))


func card_name_for_index(index: int) -> String:
	return String(hud.call("_card_name_for_index", index))


func request_card_play(index: int, source: String) -> void:
	hud.call("_request_card_play", index, source)


func request_card_reorder(from_index: int, to_index: int) -> bool:
	return bool(hud.call("_request_card_reorder", from_index, to_index))


func trigger_invalid_feedback(index: int, message: String) -> void:
	hud.call("_trigger_invalid_feedback", index, message)


func show_card_toast(message: String) -> void:
	hud.call("_show_card_toast", message)


func feel_value(key: String) -> float:
	return float(hud.call("_feel_value", key))
