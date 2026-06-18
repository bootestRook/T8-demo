extends RefCounted
class_name GameProjectileDrawer


static func draw_projectiles(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var projectiles: Array = snapshot.get("active_projectiles", [])
	for item in projectiles:
		if not (item is Dictionary):
			continue
		var projectile: Dictionary = item
		var position: Vector2 = projectile.get("position", Vector2.ZERO)
		var projectile_id := String(projectile.get("projectile_id", ""))
		if projectile_id == "gun_bullet" or projectile_id == "split_bullet":
			_draw_line_projectile(canvas, projectile, position, Color(1.0, 0.86, 0.42), 34.0, 4.0)
		elif projectile_id.find("dry_ice") != -1 or projectile_id == "small_ice":
			_draw_bullet_projectile(canvas, projectile, position, Color(0.36, 0.88, 1.0), Color(0.84, 0.98, 1.0), 36.0, 16.0)
		elif projectile_id.find("thermobaric") != -1:
			_draw_bullet_projectile(canvas, projectile, position, Color(1.0, 0.20, 0.10), Color(1.0, 0.72, 0.34), 42.0, 18.0)
		elif projectile_id.find("electro") != -1:
			_draw_line_projectile(canvas, projectile, position, Color(0.34, 0.92, 1.0), 42.0, 5.0)


static func _projectile_direction(projectile: Dictionary, position: Vector2) -> Vector2:
	var direction: Vector2 = projectile.get("direction", Vector2.ZERO)
	if absf(direction.x) + absf(direction.y) <= 0.001:
		var target_position: Vector2 = projectile.get("target_position", position + Vector2(0.0, -1.0))
		direction = target_position - position
	if absf(direction.x) + absf(direction.y) <= 0.001:
		return Vector2(0.0, -1.0)
	return direction.normalized()


static func _draw_line_projectile(
	canvas: CanvasItem, projectile: Dictionary, position: Vector2, color: Color, length: float, width: float
) -> void:
	var direction := _projectile_direction(projectile, position)
	var nose := position + direction * (length * 0.42)
	var tail := position - direction * (length * 0.58)
	canvas.draw_line(tail, nose, Color(color.r, color.g, color.b, 0.82), width, true)
	canvas.draw_line(tail - direction * 10.0, tail, Color(color.r, color.g, color.b, 0.24), width * 1.4, true)


static func _draw_bullet_projectile(
	canvas: CanvasItem, projectile: Dictionary, position: Vector2, shell_color: Color, core_color: Color, length: float, width: float
) -> void:
	var direction := _projectile_direction(projectile, position)
	var side := Vector2(-direction.y, direction.x)
	var nose := position + direction * (length * 0.48)
	var tail := position - direction * (length * 0.52)
	var left := position + side * (width * 0.42) - direction * (length * 0.14)
	var right := position - side * (width * 0.42) - direction * (length * 0.14)
	canvas.draw_line(tail, left, Color(shell_color.r, shell_color.g, shell_color.b, 0.82), 5.0, true)
	canvas.draw_line(left, nose, Color(shell_color.r, shell_color.g, shell_color.b, 0.95), 5.0, true)
	canvas.draw_line(nose, right, Color(shell_color.r, shell_color.g, shell_color.b, 0.95), 5.0, true)
	canvas.draw_line(right, tail, Color(shell_color.r, shell_color.g, shell_color.b, 0.82), 5.0, true)
	canvas.draw_line(tail + direction * 4.0, nose - direction * 7.0, Color(core_color.r, core_color.g, core_color.b, 0.70), 4.0, true)
