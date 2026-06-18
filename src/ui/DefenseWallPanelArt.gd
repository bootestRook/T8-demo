extends PanelContainer

const WALL_ART_SOURCE_RECT := Rect2(Vector2(0.0, 0.0), Vector2(1080.0, 220.0))

var _wall_staging_texture: Texture2D = null


func _ready() -> void:
	_wall_staging_texture = AssetRegistry.load_texture(&"sprite", &"defense_wall_staging_v1")
	queue_redraw()


func _draw() -> void:
	if _wall_staging_texture != null:
		draw_texture_rect_region(_wall_staging_texture, Rect2(Vector2.ZERO, size), WALL_ART_SOURCE_RECT)
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.21, 0.19, 0.95), true)
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(w, 12.0)), Color(0.38, 0.40, 0.38, 0.95), true)
	draw_rect(Rect2(Vector2(0.0, h - 14.0), Vector2(w, 14.0)), Color(0.10, 0.11, 0.10, 0.92), true)
	for i in range(6):
		var x := float(i) * w / 5.0
		draw_rect(Rect2(Vector2(x - 18.0, 12.0), Vector2(36.0, h - 26.0)), Color(0.16, 0.17, 0.16, 0.78), true)
		draw_rect(Rect2(Vector2(x - 13.0, 17.0), Vector2(26.0, h - 36.0)), Color(0.34, 0.36, 0.34, 0.88), false, 2.0)
	for i in range(18):
		var x := float(i) * w / 17.0
		draw_line(Vector2(x, 18.0), Vector2(x + 32.0, h - 18.0), Color(0.05, 0.055, 0.05, 0.34), 2.0)
	draw_line(Vector2(0.0, h - 1.0), Vector2(w, h - 1.0), Color(0.50, 0.54, 0.50, 0.55), 2.0)
