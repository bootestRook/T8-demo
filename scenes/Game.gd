extends Node2D

const WORLD_SIZE := Vector2(1080.0, 1920.0)

@onready var hud: CanvasLayer = $Hud
@onready var runtime_animation_player: AnimationPlayer = $RuntimeAnimationPlayer

var _snapshot: Dictionary = {}
var _screen_feedback_offset := Vector2.ZERO


func _ready() -> void:
	add_to_group("playable_game")
	runtime_animation_player.playback_active = true
	get_viewport().size_changed.connect(queue_redraw)
	PrototypeState.state_changed.connect(_on_state_changed)
	PrototypeState.reset()
	queue_redraw()


func _process(delta: float) -> void:
	PrototypeState.tick(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		PrototypeState.reset()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R:
			PrototypeState.reset()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_set_transform(_screen_feedback_offset, 0.0, Vector2.ONE)
	_draw_starter_canvas()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if hud.has_method("set_battle_snapshot"):
		hud.call("set_battle_snapshot", snapshot)


func set_screen_feedback_offset(offset: Vector2) -> void:
	_screen_feedback_offset = offset
	queue_redraw()


func _draw_starter_canvas() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.040, 0.045, 0.040), true)
	var field := Rect2(Vector2(0.0, 130.0), Vector2(1080.0, 1100.0))
	var path := Rect2(Vector2(216.0, field.position.y), Vector2(648.0, field.size.y))
	draw_rect(field, Color(0.050, 0.070, 0.045), true)
	draw_rect(path, Color(0.285, 0.285, 0.235), true)
	for i in range(10):
		var y := path.position.y + float(i) * 108.0
		draw_line(Vector2(path.position.x + 18.0, y), Vector2(path.end.x - 18.0, y), Color(0.42, 0.41, 0.34, 0.38), 2.0)
	for i in range(6):
		var x := path.position.x + float(i) * 120.0
		draw_line(Vector2(x, path.position.y + 24.0), Vector2(x, path.end.y - 24.0), Color(0.23, 0.24, 0.20, 0.34), 2.0)
	_draw_foliage_band(Rect2(Vector2(0.0, field.position.y), Vector2(206.0, field.size.y)))
	_draw_foliage_band(Rect2(Vector2(874.0, field.position.y), Vector2(206.0, field.size.y)))
	_draw_enemy(Vector2(405.0, 330.0), "敌", 0.72)
	_draw_enemy(Vector2(675.0, 370.0), "敌", 0.58)
	_draw_enemy(Vector2(540.0, 530.0), "精", 0.46)
	draw_circle(Vector2(540.0, 650.0), 92.0, Color(0.18, 0.45, 0.84, 0.12))
	draw_circle(Vector2(540.0, 650.0), 92.0, Color(0.55, 0.80, 1.00, 0.38), false, 5.0)
	var wall := Rect2(Vector2(0.0, 1160.0), Vector2(1080.0, 120.0))
	draw_rect(wall, Color(0.145, 0.145, 0.135), true)
	draw_rect(Rect2(Vector2(0.0, 1186.0), Vector2(1080.0, 58.0)), Color(0.070, 0.075, 0.073), true)
	for i in range(10):
		var block := Rect2(Vector2(float(i) * 112.0 - 8.0, 1162.0), Vector2(92.0, 112.0))
		draw_rect(block, Color(0.22, 0.22, 0.20), false, 3.0)
	draw_rect(Rect2(Vector2(0.0, 1280.0), Vector2(1080.0, 240.0)), Color(0.120, 0.105, 0.082), true)
	draw_circle(Vector2(500.0, 1390.0), 42.0, Color(0.86, 0.72, 0.42))
	draw_rect(Rect2(Vector2(470.0, 1424.0), Vector2(62.0, 66.0)), Color(0.18, 0.18, 0.17), true)
	draw_circle(Vector2(620.0, 1410.0), 38.0, Color(0.26, 0.55, 0.68))
	draw_circle(Vector2(620.0, 1410.0), 19.0, Color(0.08, 0.18, 0.22))


func _draw_foliage_band(rect: Rect2) -> void:
	draw_rect(rect, Color(0.070, 0.105, 0.044), true)
	for i in range(15):
		var offset := Vector2(float((i * 41) % int(rect.size.x)), float((i * 73) % int(rect.size.y)))
		var center := rect.position + offset
		draw_circle(center, 24.0 + float(i % 4) * 6.0, Color(0.130, 0.175, 0.070, 0.56))


func _draw_enemy(position: Vector2, label: String, hp_ratio: float) -> void:
	draw_circle(position, 30.0, Color(0.34, 0.49, 0.45))
	draw_rect(Rect2(position + Vector2(-34.0, -48.0), Vector2(68.0, 7.0)), Color(0.12, 0.04, 0.035), true)
	draw_rect(Rect2(position + Vector2(-34.0, -48.0), Vector2(68.0 * clampf(hp_ratio, 0.0, 1.0), 7.0)), Color(0.94, 0.20, 0.13), true)
	draw_string(
		ThemeDB.fallback_font, position + Vector2(-18.0, 9.0), label, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 22, Color(0.92, 0.86, 0.64)
	)
