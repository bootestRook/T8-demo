extends CharacterBody2D
class_name PlayerController2D

signal moved(direction: Vector2, current_velocity: Vector2)
signal input_enabled_changed(enabled: bool)

@export var max_speed := 220.0
@export var acceleration := 1400.0
@export var friction := 1600.0
@export var use_ui_fallback := true
@export var auto_register_default_actions := true

var input_enabled := true


func _ready() -> void:
	if auto_register_default_actions:
		var profile := InputProfile.new()
		profile.ensure_actions()
		profile.free()


func set_input_enabled(enabled: bool) -> void:
	if input_enabled == enabled:
		return
	input_enabled = enabled
	input_enabled_changed.emit(input_enabled)


func read_move_vector() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	var direction := Vector2(
		_action_strength(&"move_right") - _action_strength(&"move_left"), _action_strength(&"move_down") - _action_strength(&"move_up")
	)
	if direction.length_squared() == 0.0 and use_ui_fallback:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return direction.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var direction := read_move_vector()
	var target_velocity := direction * max_speed
	var response := acceleration if direction.length_squared() > 0.0 else friction
	velocity = velocity.move_toward(target_velocity, response * delta)
	move_and_slide()
	if direction.length_squared() > 0.0:
		moved.emit(direction, velocity)


func _action_strength(action_name: StringName) -> float:
	if not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)
