extends RefCounted
class_name HudCardInteraction

const HUD_CARD_INTERACTION_PORT := preload("res://src/ui/HudCardInteractionPort.gd")

var port: HudCardInteractionPort = HUD_CARD_INTERACTION_PORT.new()
var hover_index := -1
var hover_suppressed_index := -1
var selected_card_index := -1
var pointer_down_index := -1
var press_was_selected := false
var dragging_card_index := -1
var interaction_owner_index := -1
var pointer_down_position := Vector2.ZERO
var pointer_hold_timer := 0.0
var pointer_position := Vector2(-9999.0, -9999.0)
var drag_velocity := Vector2.ZERO
var drag_playable := false
var reorder_preview_index := -1
var card_reorder_lock_timer := 0.0
var invalid_feedback_index := -1
var invalid_feedback_timer := 0.0
var card_toast_timer := 0.0


func setup(owner: Node) -> void:
	port.setup(owner)


func handle_input(event: InputEvent) -> bool:
	var handled := false
	if not port.can_handle_card_input():
		if interaction_owner_index != -1:
			cancel_card_interaction()
	elif event.is_action_pressed("ui_cancel") and (interaction_owner_index != -1 or selected_card_index != -1):
		cancel_card_interaction()
		port.show_card_toast("已取消选牌")
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move_selected_card(-1)
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move_selected_card(1)
		handled = true
	elif event.is_action_pressed("ui_accept") and selected_card_index != -1:
		port.request_card_play(selected_card_index, "keyboard")
		handled = true
	elif event is InputEventMouseMotion:
		handled = handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		handled = handle_mouse_button(event as InputEventMouseButton)
	return handled


func handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	pointer_position = port.pointer_position()
	drag_velocity = event.velocity
	if pointer_down_index == -1:
		refresh_hover_from_pointer()
		return false
	var delta_from_down := pointer_position - pointer_down_position
	var drag_threshold := port.feel_value("drag_detection_threshold")
	if dragging_card_index == -1 and delta_from_down.length_squared() >= drag_threshold * drag_threshold:
		_begin_card_drag(pointer_down_index)
	if dragging_card_index != -1:
		drag_playable = port.is_pointer_in_play_zone(pointer_position)
		reorder_preview_index = -1 if drag_playable else port.card_reorder_index_at_point(pointer_position, dragging_card_index)
		return true
	return false


func handle_mouse_button(event: InputEventMouseButton) -> bool:
	var handled := false
	if event.button_index == MOUSE_BUTTON_LEFT:
		pointer_position = port.pointer_position()
		handled = _handle_mouse_press() if event.pressed else _handle_mouse_release()
	return handled


func recover_released_card_pointer() -> void:
	if not has_active_card_pointer():
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	pointer_position = port.pointer_position()
	if dragging_card_index != -1:
		var released_drag_index := dragging_card_index
		if port.is_pointer_in_play_zone(pointer_position):
			port.request_card_play(released_drag_index, "drag")
		else:
			_release_drag_to_reorder(released_drag_index)
		return
	if pointer_down_index != -1:
		if pointer_hold_timer >= port.feel_value("card_long_press_clear_time"):
			selected_card_index = -1
			hover_index = -1
			_suppress_hover_for_index(pointer_down_index)
		release_card_interaction()


func has_active_card_pointer() -> bool:
	return pointer_down_index != -1 or dragging_card_index != -1


func release_card_interaction() -> void:
	interaction_owner_index = -1
	pointer_down_index = -1
	press_was_selected = false
	dragging_card_index = -1
	drag_playable = false
	reorder_preview_index = -1
	drag_velocity = Vector2.ZERO
	pointer_hold_timer = 0.0
	card_reorder_lock_timer = maxf(card_reorder_lock_timer, port.feel_value("card_reorder_delay"))


func cancel_card_interaction() -> void:
	release_card_interaction()
	selected_card_index = -1
	hover_index = -1
	hover_suppressed_index = -1


func on_card_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseMotion:
		if handle_mouse_motion(event as InputEventMouseMotion):
			port.mark_input_handled()
		return
	if event is InputEventMouseButton:
		if handle_mouse_button(event as InputEventMouseButton):
			port.mark_input_handled()


func on_card_mouse_entered(panel: PanelContainer) -> void:
	if not port.can_handle_card_input() or dragging_card_index != -1:
		return
	var index := port.card_index_for_panel(panel)
	if index == -1:
		return
	if index == hover_suppressed_index:
		hover_index = -1
		return
	pointer_position = port.pointer_position()
	hover_index = index


func on_card_mouse_exited(panel: PanelContainer) -> void:
	if dragging_card_index != -1:
		return
	var index := port.card_index_for_panel(panel)
	if index != -1 and hover_index == index:
		hover_index = -1
	if index != -1 and hover_suppressed_index == index:
		hover_suppressed_index = -1


func tick_feedback(delta: float) -> void:
	if pointer_down_index != -1:
		pointer_hold_timer += delta
	card_reorder_lock_timer = maxf(0.0, card_reorder_lock_timer - delta)
	invalid_feedback_timer = maxf(0.0, invalid_feedback_timer - delta)
	if invalid_feedback_timer <= 0.0:
		invalid_feedback_index = -1
	card_toast_timer = maxf(0.0, card_toast_timer - delta)
	port.sync_card_toast_visibility()


func clamp_indices_to_hand() -> void:
	var hand_count := port.current_hand_count()
	if hand_count <= 0:
		hover_index = -1
		selected_card_index = -1
		cancel_card_interaction()
		return
	if hover_index >= hand_count:
		hover_index = -1
	if selected_card_index >= hand_count:
		selected_card_index = hand_count - 1
	if pointer_down_index >= hand_count or dragging_card_index >= hand_count or interaction_owner_index >= hand_count:
		cancel_card_interaction()


func refresh_hover_from_pointer() -> void:
	if dragging_card_index != -1:
		return
	var index := port.card_index_at_point(pointer_position)
	if hover_suppressed_index != -1:
		if index == hover_suppressed_index:
			hover_index = -1
			return
		hover_suppressed_index = -1
	hover_index = index


func active_card_index() -> int:
	return dragging_card_index if dragging_card_index != -1 else selected_card_index


func _handle_mouse_press() -> bool:
	var handled := false
	var pressed_index := port.card_index_at_point(pointer_position)
	if pressed_index != -1:
		if port.is_card_cooling_down(pressed_index):
			port.trigger_invalid_feedback(pressed_index, port.card_cooldown_message(pressed_index))
			handled = true
			return handled
		if _claim_card_interaction(pressed_index):
			hover_suppressed_index = -1
			press_was_selected = selected_card_index == pressed_index
			selected_card_index = pressed_index
			hover_index = pressed_index
			pointer_down_index = pressed_index
			pointer_down_position = pointer_position
			pointer_hold_timer = 0.0
			drag_velocity = Vector2.ZERO
		else:
			port.trigger_invalid_feedback(pressed_index, "上一张卡还在操作中")
		handled = true
	elif selected_card_index != -1 or hover_index != -1 or has_active_card_pointer():
		cancel_card_interaction()
		handled = true
	return handled


func _handle_mouse_release() -> bool:
	var handled := false
	if dragging_card_index != -1:
		var released_drag_index := dragging_card_index
		if port.is_pointer_in_play_zone(pointer_position):
			port.request_card_play(released_drag_index, "drag")
		else:
			_release_drag_to_reorder(released_drag_index)
		handled = true
	elif pointer_down_index != -1:
		var released_click_index := pointer_down_index
		if pointer_hold_timer >= port.feel_value("card_long_press_clear_time"):
			selected_card_index = -1
			hover_index = -1
			_suppress_hover_for_index(released_click_index)
			release_card_interaction()
		elif press_was_selected:
			port.request_card_play(released_click_index, "click")
		else:
			port.show_card_toast("再次点击或拖到战场释放")
			release_card_interaction()
		handled = true
	return handled


func _begin_card_drag(index: int) -> void:
	if port.is_card_cooling_down(index):
		port.trigger_invalid_feedback(index, port.card_cooldown_message(index))
		cancel_card_interaction()
		return
	if not _claim_card_interaction(index):
		port.trigger_invalid_feedback(index, "上一张卡还在操作中")
		return
	dragging_card_index = index
	drag_playable = port.is_pointer_in_play_zone(pointer_position)
	reorder_preview_index = -1 if drag_playable else index
	port.show_card_toast("拖到战场上方释放")


func _move_selected_card(direction: int) -> void:
	var hand_count := port.current_hand_count()
	if hand_count <= 0:
		selected_card_index = -1
		return
	if selected_card_index == -1:
		selected_card_index = 0 if direction >= 0 else hand_count - 1
	else:
		selected_card_index = clampi(selected_card_index + direction, 0, hand_count - 1)
	hover_index = selected_card_index
	port.show_card_toast("%s 已选中" % port.card_name_for_index(selected_card_index))


func _claim_card_interaction(index: int) -> bool:
	if interaction_owner_index != -1 and interaction_owner_index != index:
		return false
	interaction_owner_index = index
	return true


func _release_drag_to_reorder(released_drag_index: int) -> void:
	var target_index := reorder_preview_index
	release_card_interaction()
	selected_card_index = -1
	hover_index = -1
	_suppress_hover_for_index(target_index if target_index != -1 else released_drag_index)
	if target_index != -1 and target_index != released_drag_index:
		port.request_card_reorder(released_drag_index, target_index)


func _suppress_hover_for_index(index: int) -> void:
	hover_suppressed_index = index if index >= 0 and index < port.current_hand_count() else -1
