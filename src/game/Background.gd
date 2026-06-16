extends Node2D


func _draw() -> void:
	var rect := get_viewport_rect()
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.045, 0.050, 0.060), true)
	for i in range(12):
		var t := float(i) / 11.0
		var color := Color(0.070, 0.078, 0.092).lerp(Color(0.035, 0.040, 0.050), t)
		var y := rect.size.y * t
		draw_rect(Rect2(Vector2(0.0, y), Vector2(rect.size.x, rect.size.y / 11.0 + 1.0)), color, true)
	for i in range(7):
		var x := fmod(float(i * 173 + 53), rect.size.x + 180.0) - 90.0
		var y := 110.0 + float(i % 5) * 155.0
		_draw_soft_mark(Vector2(x, y), 0.72 + float(i % 3) * 0.10)


func _draw_soft_mark(pos: Vector2, scale_value: float) -> void:
	var color := Color(0.18, 0.26, 0.34, 0.16)
	draw_circle(pos, 46.0 * scale_value, color)
	draw_circle(pos + Vector2(36.0, 22.0) * scale_value, 30.0 * scale_value, color)
	draw_circle(pos + Vector2(82.0, 12.0) * scale_value, 38.0 * scale_value, color)
