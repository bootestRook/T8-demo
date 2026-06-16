extends Control


func _draw() -> void:
	var center := size * 0.5
	var head := center + Vector2(0.0, -22.0)
	var body_top := center + Vector2(0.0, -6.0)
	var body_bottom := center + Vector2(0.0, 24.0)
	var skin := Color(0.95, 0.72, 0.42)
	var armor := Color(0.34, 0.26, 0.18)
	var metal := Color(0.62, 0.76, 0.86)
	var shadow := Color(0.0, 0.0, 0.0, 0.32)
	var shield_center := center + Vector2(34.0, 14.0)

	draw_ellipse(center + Vector2(0.0, 27.0), 28.0, 7.0, shadow)
	draw_circle(shield_center, 16.0, Color(0.36, 0.70, 0.80, 0.92))
	draw_circle(shield_center, 9.0, Color(0.16, 0.34, 0.38, 0.96))
	draw_arc(shield_center, 21.0, -0.6, 2.2, 18, Color(0.82, 0.95, 1.0, 0.62), 3.0)
	draw_circle(head, 13.0, skin)
	draw_circle(head + Vector2(-5.0, -4.0), 3.0, Color(0.98, 0.86, 0.50))
	draw_circle(head + Vector2(5.0, -4.0), 3.0, Color(0.98, 0.86, 0.50))
	draw_line(body_top, body_bottom, armor, 16.0)
	draw_line(body_top + Vector2(-8.0, 4.0), center + Vector2(-28.0, 12.0), armor, 8.0)
	draw_line(body_top + Vector2(8.0, 4.0), center + Vector2(30.0, -18.0), armor, 8.0)
	draw_line(center + Vector2(26.0, -22.0), center + Vector2(52.0, -66.0), metal, 8.0)
	draw_line(center + Vector2(42.0, -63.0), center + Vector2(58.0, -72.0), Color(0.80, 0.92, 1.0), 5.0)
	draw_circle(center + Vector2(27.0, -21.0), 5.0, Color(0.12, 0.16, 0.18))
	draw_line(body_bottom, center + Vector2(-17.0, 44.0), armor, 9.0)
	draw_line(body_bottom, center + Vector2(19.0, 44.0), armor, 9.0)
