extends RefCounted

class_name GameBattlefieldDrawer


static func draw_base(
	canvas: CanvasItem,
	world_size: Vector2,
	ui_background_texture: Texture2D,
	battlefield_texture: Texture2D,
	defense_wall_staging_texture: Texture2D
) -> void:
	var world_rect := Rect2(Vector2.ZERO, world_size)
	if ui_background_texture != null:
		canvas.draw_texture_rect(ui_background_texture, world_rect, false)
		canvas.draw_rect(world_rect, Color(0.0, 0.0, 0.0, 0.14), true)
	else:
		canvas.draw_rect(world_rect, Color(0.040, 0.045, 0.040), true)
	var field := Rect2(Vector2(0.0, 130.0), Vector2(1080.0, 1030.0))
	if battlefield_texture != null:
		canvas.draw_texture_rect(battlefield_texture, field, false)
	else:
		_draw_field_fallback(canvas, field)
	var wall := Rect2(Vector2(0.0, 1160.0), Vector2(1080.0, 120.0))
	if defense_wall_staging_texture != null:
		canvas.draw_texture_rect(defense_wall_staging_texture, Rect2(Vector2(0.0, 1060.0), Vector2(1080.0, 460.0)), false)
	else:
		_draw_wall_fallback(canvas, wall)
	canvas.draw_circle(Vector2(620.0, 1410.0), 38.0, Color(0.26, 0.55, 0.68))
	canvas.draw_circle(Vector2(620.0, 1410.0), 19.0, Color(0.08, 0.18, 0.22))


static func draw_combat_areas(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var areas: Array = snapshot.get("active_areas", [])
	for item in areas:
		if not (item is Dictionary):
			continue
		var area: Dictionary = item
		var position: Vector2 = area.get("position", Vector2.ZERO)
		var radius := float(area.get("radius", 80.0))
		var color := Color(0.20, 0.75, 1.0, 0.16)
		if String(area.get("area_id", "")) == "electro_matrix":
			color = Color(0.12, 0.80, 1.0, 0.22)
		canvas.draw_circle(position, radius, color)
		canvas.draw_circle(position, radius * 0.96, Color(color.r, color.g, color.b, 0.08))


static func _draw_field_fallback(canvas: CanvasItem, field: Rect2) -> void:
	var center_path := Rect2(Vector2(176.0, field.position.y), Vector2(728.0, field.size.y))
	canvas.draw_rect(field, Color(0.160, 0.165, 0.135), true)
	canvas.draw_rect(center_path, Color(0.300, 0.300, 0.250), true)
	_draw_plaza_side_band(canvas, Rect2(Vector2(0.0, field.position.y), Vector2(176.0, field.size.y)), -1)
	_draw_plaza_side_band(canvas, Rect2(Vector2(904.0, field.position.y), Vector2(176.0, field.size.y)), 1)
	for i in range(10):
		var y := field.position.y + float(i) * 108.0
		canvas.draw_line(Vector2(field.position.x + 28.0, y), Vector2(field.end.x - 28.0, y), Color(0.42, 0.41, 0.34, 0.34), 2.0)
	for i in range(10):
		var x := field.position.x + 44.0 + float(i) * 110.0
		canvas.draw_line(Vector2(x, field.position.y + 24.0), Vector2(x, field.end.y - 24.0), Color(0.22, 0.23, 0.19, 0.30), 2.0)
	for i in range(9):
		var marker_x := 44.0 + float(i) * 124.0
		canvas.draw_rect(Rect2(Vector2(marker_x - 20.0, field.position.y + 38.0), Vector2(40.0, 8.0)), Color(0.34, 0.38, 0.28, 0.42), true)


static func _draw_wall_fallback(canvas: CanvasItem, wall: Rect2) -> void:
	canvas.draw_rect(wall, Color(0.145, 0.145, 0.135), true)
	canvas.draw_rect(Rect2(Vector2(0.0, 1186.0), Vector2(1080.0, 58.0)), Color(0.070, 0.075, 0.073), true)
	for i in range(10):
		var block := Rect2(Vector2(float(i) * 112.0 - 8.0, 1162.0), Vector2(92.0, 112.0))
		canvas.draw_rect(block, Color(0.22, 0.22, 0.20), false, 3.0)
	canvas.draw_rect(Rect2(Vector2(0.0, 1280.0), Vector2(1080.0, 240.0)), Color(0.120, 0.105, 0.082), true)


static func _draw_plaza_side_band(canvas: CanvasItem, rect: Rect2, side: int) -> void:
	canvas.draw_rect(rect, Color(0.105, 0.130, 0.085), true)
	var edge_x := rect.end.x if side < 0 else rect.position.x
	canvas.draw_rect(Rect2(Vector2(edge_x - 10.0, rect.position.y), Vector2(20.0, rect.size.y)), Color(0.050, 0.065, 0.045, 0.88), true)
	for i in range(15):
		var offset := Vector2(float((i * 47) % int(rect.size.x)), float((i * 73) % int(rect.size.y)))
		var center := rect.position + offset
		canvas.draw_circle(center, 18.0 + float(i % 4) * 5.0, Color(0.080, 0.120, 0.055, 0.42))
	for i in range(8):
		var y := rect.position.y + 62.0 + float(i) * 126.0
		canvas.draw_line(Vector2(rect.position.x + 22.0, y), Vector2(rect.end.x - 22.0, y + 16.0), Color(0.24, 0.25, 0.20, 0.25), 2.0)
