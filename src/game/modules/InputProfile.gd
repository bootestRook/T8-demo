extends Node
class_name InputProfile

const DEFAULT_ACTIONS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"primary_action": [KEY_SPACE, MOUSE_BUTTON_LEFT],
	&"secondary_action": [KEY_SHIFT, MOUSE_BUTTON_RIGHT],
	&"menu_cancel": [KEY_ESCAPE],
}
const UI_COMPAT_ACTIONS := {
	&"ui_left": [KEY_LEFT],
	&"ui_right": [KEY_RIGHT],
	&"ui_up": [KEY_UP],
	&"ui_down": [KEY_DOWN],
}

var action_map: Dictionary = DEFAULT_ACTIONS.duplicate(true)


func ensure_actions() -> void:
	for action_name in action_map:
		_ensure_action_events(action_name, action_map[action_name])
	for action_name in UI_COMPAT_ACTIONS:
		_ensure_action_events(action_name, UI_COMPAT_ACTIONS[action_name])


func get_move_vector() -> Vector2:
	var direction := Vector2(
		_action_strength(&"move_right") - _action_strength(&"move_left"), _action_strength(&"move_down") - _action_strength(&"move_up")
	)
	return direction.limit_length(1.0)


func pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)


func held(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func _action_strength(action_name: StringName) -> float:
	if not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)


func _ensure_action_events(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keycodes:
		if not _has_event(action_name, int(keycode)):
			InputMap.action_add_event(action_name, _event_for_code(int(keycode)))


func _has_event(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true
		if event is InputEventMouseButton and event.button_index == keycode:
			return true
	return false


func _event_for_code(keycode: int) -> InputEvent:
	if keycode == MOUSE_BUTTON_LEFT or keycode == MOUSE_BUTTON_RIGHT:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = keycode
		return mouse_event
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	return key_event
