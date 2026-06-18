extends Control
class_name HudCastRangeOverlay

const DASH_COUNT := 56
const FULL_ANGLE := 6.28318530718

var _preview: Dictionary = {}


func set_preview(preview: Dictionary) -> void:
	_preview = preview.duplicate(true)
	visible = bool(_preview.get("visible", false))
	queue_redraw()


func _draw() -> void:
	if not bool(_preview.get("visible", false)):
		return
	var center: Vector2 = _preview.get("position", Vector2(549.0, 1235.0))
	var radius := float(_preview.get("radius", 1280.0))
	draw_circle(center, radius, Color(1.0, 0.12, 0.10, 0.075), true)
	draw_circle(center, radius, Color(1.0, 0.32, 0.27, 0.20), false, 9.0, true)
	_draw_dashed_circle(center, radius, Color(1.0, 0.25, 0.22, 0.92), 5.0)


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	var dash_angle := FULL_ANGLE / float(DASH_COUNT)
	for index in range(DASH_COUNT):
		var start_angle := float(index) * dash_angle
		var end_angle := start_angle + dash_angle * 0.54
		draw_arc(center, radius, start_angle, end_angle, 10, color, width, true)
