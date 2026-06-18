extends Label
class_name HudShieldIconLabel

const FILL_COLOR := Color(0.42, 0.84, 1.0, 0.98)
const INNER_COLOR := Color(0.16, 0.42, 0.52, 0.95)
const OUTLINE_COLOR := Color(0.83, 0.97, 1.0, 0.95)


func _ready() -> void:
	text = ""
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var icon_size := minf(size.x, size.y)
	if icon_size <= 0.0:
		return
	var shield_width := icon_size * 0.78
	var shield_height := icon_size * 0.88
	var left := (size.x - shield_width) * 0.5
	var top := (size.y - shield_height) * 0.5
	var right := left + shield_width
	var bottom := top + shield_height
	var center_x := size.x * 0.5
	var body := PackedVector2Array(
		[
			Vector2(center_x, top),
			Vector2(right, top + shield_height * 0.20),
			Vector2(right - shield_width * 0.12, top + shield_height * 0.64),
			Vector2(center_x, bottom),
			Vector2(left + shield_width * 0.12, top + shield_height * 0.64),
			Vector2(left, top + shield_height * 0.20),
		]
	)
	var outline := PackedVector2Array(body)
	outline.append(body[0])
	draw_colored_polygon(body, FILL_COLOR)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(center_x, top + shield_height * 0.14),
				Vector2(right - shield_width * 0.17, top + shield_height * 0.29),
				Vector2(right - shield_width * 0.25, top + shield_height * 0.58),
				Vector2(center_x, bottom - shield_height * 0.13),
			]
		),
		INNER_COLOR
	)
	draw_polyline(outline, OUTLINE_COLOR, maxf(1.8, icon_size * 0.08), true)
