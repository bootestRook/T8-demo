extends PanelContainer

const STAGING_ART_SOURCE_RECT := Rect2(Vector2(0.0, 220.0), Vector2(1080.0, 240.0))

var _wall_staging_texture: Texture2D = null


func _ready() -> void:
	_wall_staging_texture = AssetRegistry.load_texture(&"sprite", &"defense_wall_staging_v1")
	queue_redraw()


func _draw() -> void:
	if _wall_staging_texture != null:
		draw_texture_rect_region(_wall_staging_texture, Rect2(Vector2.ZERO, size), STAGING_ART_SOURCE_RECT)
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.28, 0.27, 0.24, 0.96), true)
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(w, 20.0)), Color(0.16, 0.16, 0.14, 0.50), true)
	draw_rect(Rect2(Vector2(0.0, h - 18.0), Vector2(w, 18.0)), Color(0.12, 0.11, 0.10, 0.40), true)
	for i in range(5):
		var x := float(i) * w / 4.0
		draw_line(Vector2(x, 24.0), Vector2(x - 76.0, h), Color(0.42, 0.39, 0.32, 0.36), 5.0)
		draw_line(Vector2(x + 58.0, 24.0), Vector2(x + 110.0, h), Color(0.18, 0.17, 0.15, 0.28), 4.0)
	draw_line(Vector2(0.0, 0.0), Vector2(w, 0.0), Color(0.56, 0.55, 0.48, 0.38), 2.0)
