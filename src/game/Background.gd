extends Node2D


func _draw() -> void:
	var rect := get_viewport_rect()
	var top := Color(0.82, 0.91, 0.96)
	var bottom := Color(0.94, 0.97, 0.98)
	draw_rect(Rect2(Vector2.ZERO, rect.size), bottom)
	for i in 12:
		var t := float(i) / 11.0
		var color := top.lerp(bottom, t)
		var y := rect.size.y * t
		draw_rect(Rect2(Vector2(0.0, y), Vector2(rect.size.x, rect.size.y / 11.0 + 1.0)), color)

	for i in 7:
		var x := fmod(float(i * 151 + 43), rect.size.x + 120.0) - 60.0
		var y := 72.0 + float(i % 3) * 92.0
		_draw_soft_mark(Vector2(x, y), 0.60 + float(i % 2) * 0.18)


func _draw_soft_mark(pos: Vector2, scale_value: float) -> void:
	var color := Color(1.0, 1.0, 1.0, 0.26)
	draw_circle(pos + Vector2(24.0, 18.0) * scale_value, 26.0 * scale_value, color)
	draw_circle(pos + Vector2(54.0, 10.0) * scale_value, 34.0 * scale_value, color)
	draw_circle(pos + Vector2(88.0, 20.0) * scale_value, 24.0 * scale_value, color)
