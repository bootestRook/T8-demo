extends RefCounted
class_name PlayerAimPresenter

const DRAW_CENTER := Vector2(540.0, 1370.0)
const DRAW_SIZE := Vector2(96.0, 228.0)
const AIM_HOLD_TIME := 0.42
const AIM_TURN_SPEED := 14.0
const AIM_RETURN_SPEED := 6.0
const FORWARD_ROTATION_OFFSET := 1.5707963267948966

var _player_texture: Texture2D = null
var _aim_rotation := 0.0
var _target_rotation := 0.0
var _aim_hold_timer := 0.0


func setup() -> void:
	_player_texture = AssetRegistry.load_texture(&"sprite", &"player_hero_v1")


func update(snapshot: Dictionary, delta: float) -> void:
	var aim_direction := _latest_gun_projectile_direction(snapshot)
	if absf(aim_direction.x) + absf(aim_direction.y) > 0.001:
		_target_rotation = _rotation_for_direction(aim_direction)
		_aim_hold_timer = AIM_HOLD_TIME
	elif _aim_hold_timer > 0.0:
		_aim_hold_timer = maxf(0.0, _aim_hold_timer - delta)
	else:
		_target_rotation = 0.0
	var speed := AIM_TURN_SPEED if _aim_hold_timer > 0.0 else AIM_RETURN_SPEED
	_aim_rotation = lerp_angle(_aim_rotation, _target_rotation, clampf(delta * speed, 0.0, 1.0))


func draw(canvas: CanvasItem, screen_feedback_offset: Vector2) -> void:
	if _player_texture == null:
		return
	canvas.draw_set_transform(screen_feedback_offset + DRAW_CENTER, _aim_rotation, Vector2.ONE)
	canvas.draw_texture_rect(_player_texture, Rect2(-DRAW_SIZE * 0.5, DRAW_SIZE), false)
	canvas.draw_set_transform(screen_feedback_offset, 0.0, Vector2.ONE)


func _latest_gun_projectile_direction(snapshot: Dictionary) -> Vector2:
	var projectiles: Array = snapshot.get("active_projectiles", [])
	var aim_direction := Vector2.ZERO
	for item in projectiles:
		if not (item is Dictionary):
			continue
		var projectile: Dictionary = item
		if String(projectile.get("projectile_id", "")) != "gun_bullet":
			continue
		var position: Vector2 = projectile.get("position", Vector2.ZERO)
		aim_direction = _projectile_direction(projectile, position)
	return aim_direction


func _rotation_for_direction(direction: Vector2) -> float:
	if absf(direction.x) + absf(direction.y) <= 0.001:
		return 0.0
	return direction.normalized().angle() + FORWARD_ROTATION_OFFSET


func _projectile_direction(projectile: Dictionary, position: Vector2) -> Vector2:
	var direction: Vector2 = projectile.get("direction", Vector2.ZERO)
	if absf(direction.x) + absf(direction.y) <= 0.001:
		var target_position: Vector2 = projectile.get("target_position", position + Vector2(0.0, -1.0))
		direction = target_position - position
	if absf(direction.x) + absf(direction.y) <= 0.001:
		return Vector2(0.0, -1.0)
	return direction.normalized()
