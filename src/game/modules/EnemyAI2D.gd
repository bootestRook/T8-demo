extends CharacterBody2D
class_name EnemyAI2D

enum Mode { IDLE, CHASE, WANDER }

signal target_changed(target: Node2D)
signal reached_target(target: Node2D)

@export var mode: Mode = Mode.CHASE
@export var speed := 120.0
@export var detection_range := 360.0
@export var stop_distance := 16.0
@export var target_path: NodePath

var ai_enabled := true
var target: Node2D
var _wander_direction := Vector2.RIGHT
var _wander_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if String(target_path) != "":
		set_target(get_node_or_null(target_path) as Node2D)


func set_target(new_target: Node2D) -> void:
	target = new_target
	target_changed.emit(target)


func _physics_process(delta: float) -> void:
	if not ai_enabled:
		velocity = Vector2.ZERO
		return
	var direction := _desired_direction(delta)
	velocity = direction * speed
	move_and_slide()
	if _has_valid_target() and global_position.distance_to(target.global_position) <= stop_distance:
		reached_target.emit(target)


func _desired_direction(delta: float) -> Vector2:
	match mode:
		Mode.IDLE:
			return Vector2.ZERO
		Mode.WANDER:
			return _wander(delta)
		Mode.CHASE:
			return _chase()
	return Vector2.ZERO


func _chase() -> Vector2:
	if not _has_valid_target():
		return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	if distance > detection_range or distance <= stop_distance:
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)


func _wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _rng.randf_range(0.6, 1.4)
		_wander_direction = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
	return _wander_direction


func _has_valid_target() -> bool:
	if target == null:
		return false
	if is_instance_valid(target):
		return true
	set_target(null)
	return false
