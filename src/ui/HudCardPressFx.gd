extends Control
class_name HudCardPressFx

const PRESS_STEPS := 7
const HIGHLIGHT_STEPS := 6

var press_point := Vector2.ZERO
var lift_point := Vector2.ZERO
var press_weight := 0.0


func set_press_state(active: bool, point: Vector2, lift: Vector2, weight: float) -> void:
	press_point = point
	lift_point = lift
	press_weight = clampf(weight, 0.0, 1.0) if active else 0.0
	visible = press_weight > 0.01
	queue_redraw()


func _draw() -> void:
	if press_weight <= 0.01 or size.x <= 0.0 or size.y <= 0.0:
		return
	var card_rect := Rect2(Vector2.ZERO, size)
	draw_rect(card_rect, Color(0.0, 0.0, 0.0, 0.026 * press_weight), true)
	_draw_radial(press_point, minf(size.x, size.y) * 0.34, Color(0.018, 0.010, 0.004, 0.205 * press_weight), PRESS_STEPS)
	_draw_radial(press_point, minf(size.x, size.y) * 0.18, Color(0.0, 0.0, 0.0, 0.135 * press_weight), PRESS_STEPS)
	_draw_radial(lift_point, minf(size.x, size.y) * 0.68, Color(1.0, 0.94, 0.66, 0.170 * press_weight), HIGHLIGHT_STEPS)
	_draw_edge_sheen()


func _draw_radial(center: Vector2, radius: float, color: Color, steps: int) -> void:
	for step in range(steps, 0, -1):
		var t := float(step) / float(steps)
		var c := color
		c.a *= (1.0 - t) * (1.0 - t)
		draw_circle(center, radius * t, c, true, -1.0, true)


func _draw_edge_sheen() -> void:
	var edge_alpha := 0.080 * press_weight
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 3.0)), Color(1.0, 0.92, 0.55, edge_alpha), true)
	draw_rect(Rect2(Vector2(0.0, size.y - 8.0), Vector2(size.x, 8.0)), Color(0.0, 0.0, 0.0, edge_alpha), true)
	draw_rect(Rect2(Vector2(0.0, size.y - 18.0), Vector2(size.x, 10.0)), Color(0.0, 0.0, 0.0, 0.035 * press_weight), true)
