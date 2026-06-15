extends Node2D

const WORLD_SIZE := Vector2(1080.0, 1920.0)
const WALL_Y := 1680.0
const BATTLE_TOP := 180.0
const BATTLE_BOTTOM := 1450.0
const HERO_POS := Vector2(540.0, 1498.0)

@onready var hud: CanvasLayer = $Hud
@onready var runtime_animation_player: AnimationPlayer = $RuntimeAnimationPlayer

var _snapshot: Dictionary = {}
var _world_scale := 1.0
var _world_offset := Vector2.ZERO


func _ready() -> void:
	add_to_group("playable_game")
	# AnimationPlayer is kept as runtime animation evidence; enemies, boss and projectiles are procedurally animated in _draw.
	runtime_animation_player.playback_active = true
	get_viewport().size_changed.connect(queue_redraw)
	PrototypeState.state_changed.connect(_on_state_changed)
	PrototypeState.feedback_requested.connect(_on_feedback_requested)
	PrototypeState.reset()
	queue_redraw()


func _process(delta: float) -> void:
	PrototypeState.tick(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Touch is primary; KEY_LEFT / KEY_RIGHT / KEY_A / KEY_D are intentionally unused in this vertical card battler.
	if event.is_action_pressed("ui_accept") and PrototypeState.phase in [PrototypeState.Phase.WON, PrototypeState.Phase.LOST]:
		PrototypeState.reset()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		PrototypeState.discard_hand()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R:
			PrototypeState.reset()
			get_viewport().set_input_as_handled()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_4:
			PrototypeState.try_play_hand(key.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	_update_transform()
	draw_set_transform(_world_offset, 0.0, Vector2(_world_scale, _world_scale))
	_draw_world()
	_draw_wall_and_hero()
	_draw_effects()
	_draw_projectiles()
	_draw_enemies()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if hud.has_method("set_battle_snapshot"):
		hud.call("set_battle_snapshot", snapshot)


func _on_feedback_requested(kind: String, _payload: Dictionary) -> void:
	if kind in ["card", "upgrade"]:
		FeedbackDirector.screen_shake(5.0, 0.12)
	elif kind == "discard":
		FeedbackDirector.screen_shake(3.0, 0.08)


func _update_transform() -> void:
	var viewport_size := get_viewport_rect().size
	_world_scale = minf(viewport_size.x / WORLD_SIZE.x, viewport_size.y / WORLD_SIZE.y)
	_world_offset = (viewport_size - WORLD_SIZE * _world_scale) * 0.5


func _draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.035, 0.048, 0.065), true)
	draw_rect(Rect2(Vector2(64.0, BATTLE_TOP), Vector2(952.0, BATTLE_BOTTOM - BATTLE_TOP)), Color(0.065, 0.086, 0.105), true)
	for i in range(10):
		var y := BATTLE_TOP + float(i) * 126.0
		draw_line(Vector2(92.0, y), Vector2(988.0, y + 28.0), Color(0.13, 0.16, 0.18), 4.0)
		draw_line(Vector2(92.0, y + 58.0), Vector2(988.0, y + 86.0), Color(0.04, 0.06, 0.07), 2.0)
	for lane_x in PrototypeState.LANES:
		draw_line(Vector2(lane_x, BATTLE_TOP), Vector2(lane_x, BATTLE_BOTTOM), Color(0.12, 0.22, 0.25, 0.35), 2.0)
	draw_rect(Rect2(Vector2(64.0, BATTLE_TOP), Vector2(952.0, BATTLE_BOTTOM - BATTLE_TOP)), Color(0.25, 0.45, 0.52, 0.5), false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(82.0, 150.0), "怪物从上方推进", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(0.56, 0.78, 0.84))


func _draw_wall_and_hero() -> void:
	# 城墙和主角炮手是玩家判断防线压力的主要视觉锚点。
	draw_rect(Rect2(Vector2(54.0, WALL_Y - 30.0), Vector2(972.0, 145.0)), Color(0.18, 0.20, 0.22), true)
	draw_rect(Rect2(Vector2(54.0, WALL_Y - 30.0), Vector2(972.0, 145.0)), Color(0.70, 0.82, 0.86), false, 7.0)
	for i in range(8):
		var x := 80.0 + float(i) * 118.0
		draw_rect(Rect2(Vector2(x, WALL_Y - 18.0), Vector2(82.0, 38.0)), Color(0.28, 0.31, 0.33), true)
	var hp_ratio := float(_snapshot.get("wall_hp", 0.0)) / maxf(1.0, float(_snapshot.get("wall_max_hp", 1000.0)))
	draw_rect(Rect2(Vector2(112.0, WALL_Y + 58.0), Vector2(856.0, 24.0)), Color(0.08, 0.04, 0.04), true)
	draw_rect(Rect2(Vector2(112.0, WALL_Y + 58.0), Vector2(856.0 * hp_ratio, 24.0)), Color(0.22, 0.92, 0.48), true)
	draw_string(ThemeDB.fallback_font, Vector2(430.0, WALL_Y + 100.0), "城墙防线", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color(0.88, 0.96, 0.98))
	_draw_hero_gunner()


func _draw_hero_gunner() -> void:
	draw_circle(HERO_POS + Vector2(10.0, 14.0), 54.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_circle(HERO_POS + Vector2(0.0, -42.0), 34.0, Color(0.98, 0.78, 0.45))
	draw_rect(Rect2(HERO_POS + Vector2(-38.0, -12.0), Vector2(76.0, 78.0)), Color(0.12, 0.32, 0.42), true)
	draw_rect(Rect2(HERO_POS + Vector2(14.0, -30.0), Vector2(132.0, 22.0)), Color(0.78, 0.84, 0.82), true)
	draw_rect(Rect2(HERO_POS + Vector2(116.0, -36.0), Vector2(42.0, 34.0)), Color(0.18, 0.20, 0.22), true)
	draw_circle(HERO_POS + Vector2(158.0, -18.0), 10.0, Color(1.0, 0.78, 0.22))
	var ammo := int(_snapshot.get("gun_ammo", 0))
	var max_ammo := maxi(1, int(_snapshot.get("gun_max_ammo", 30)))
	draw_rect(Rect2(HERO_POS + Vector2(-54.0, 78.0), Vector2(108.0, 14.0)), Color(0.05, 0.07, 0.08), true)
	draw_rect(Rect2(HERO_POS + Vector2(-54.0, 78.0), Vector2(108.0 * float(ammo) / float(max_ammo), 14.0)), Color(1.0, 0.80, 0.22), true)
	draw_string(
		ThemeDB.fallback_font, HERO_POS + Vector2(-58.0, 122.0), "主角自动射击", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.95, 0.96, 0.88)
	)


func _draw_enemies() -> void:
	for enemy in _snapshot.get("enemies", []):
		var pos := enemy.get("pos", Vector2.ZERO) as Vector2
		var radius := float(enemy.get("radius", 28.0))
		var kind := String(enemy.get("kind", "normal"))
		var color := _enemy_color(kind)
		if float(enemy.get("frozen", 0.0)) > 0.0:
			color = Color(0.45, 0.88, 1.0)
		elif float(enemy.get("paralyzed", 0.0)) > 0.0:
			color = Color(0.78, 0.62, 1.0)
		draw_circle(pos + Vector2(9.0, 13.0), radius * 1.05, Color(0.0, 0.0, 0.0, 0.34))
		draw_circle(pos + Vector2(0.0, -radius * 0.35), radius * 0.72, color)
		draw_rect(Rect2(pos + Vector2(-radius * 0.62, -radius * 0.15), Vector2(radius * 1.24, radius * 1.42)), color, true)
		draw_line(pos + Vector2(-radius * 0.8, radius * 0.2), pos + Vector2(-radius * 1.45, radius * 0.9), color.lightened(0.25), 6.0)
		draw_line(pos + Vector2(radius * 0.8, radius * 0.2), pos + Vector2(radius * 1.45, radius * 0.9), color.lightened(0.25), 6.0)
		draw_circle(pos + Vector2(-radius * 0.22, -radius * 0.48), 4.0, Color(0.02, 0.02, 0.02))
		draw_circle(pos + Vector2(radius * 0.22, -radius * 0.48), 4.0, Color(0.02, 0.02, 0.02))
		draw_rect(
			Rect2(pos + Vector2(-radius * 0.64, -radius * 1.04), Vector2(radius * 1.28, radius * 2.0)), Color(0.92, 0.98, 1.0), false, 3.0
		)
		if kind == "boss":
			draw_circle(pos, radius + 18.0, Color(1.0, 0.18, 0.08), false, 7.0)
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(-44.0, -radius - 38.0),
				"BOSS",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				24,
				Color(1.0, 0.32, 0.16)
			)
		elif kind == "elite":
			draw_circle(pos, radius + 10.0, Color(1.0, 0.66, 0.20), false, 5.0)
		var hp_ratio := clampf(float(enemy.get("hp", 0.0)) / maxf(1.0, float(enemy.get("max_hp", 1.0))), 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 18.0), Vector2(radius * 2.0, 8.0)), Color(0.12, 0.05, 0.05), true)
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 18.0), Vector2(radius * 2.0 * hp_ratio, 8.0)), Color(1.0, 0.20, 0.16), true)


func _draw_projectiles() -> void:
	for projectile in _snapshot.get("projectiles", []):
		var pos := projectile.get("pos", Vector2.ZERO) as Vector2
		var color := projectile.get("color", Color.WHITE) as Color
		var kind := String(projectile.get("kind", ""))
		var radius := 8.0
		if kind == "thermobaric":
			radius = 16.0
		elif kind == "dry_ice":
			radius = 13.0
		elif kind == "electro_pierce":
			radius = 11.0
		draw_line(pos + Vector2(-34.0, 24.0), pos, Color(color.r, color.g, color.b, 0.28), radius * 0.9)
		draw_circle(pos, radius, color)
		draw_circle(pos, radius + 8.0, Color(color.r, color.g, color.b, 0.32), false, 5.0)


func _draw_effects() -> void:
	for effect in _snapshot.get("effects", []):
		var pos := effect.get("pos", Vector2.ZERO) as Vector2
		var radius := float(effect.get("radius", 60.0))
		var ttl := float(effect.get("ttl", 0.0))
		var max_ttl := maxf(0.01, float(effect.get("max_ttl", 0.3)))
		var alpha := clampf(ttl / max_ttl, 0.0, 1.0)
		var color := effect.get("color", Color.WHITE) as Color
		if String(effect.get("kind", "")) == "matrix":
			draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.16))
			draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.55), false, 5.0)
		else:
			draw_circle(pos, radius * (1.15 - alpha * 0.25), Color(color.r, color.g, color.b, 0.24 * alpha))
			draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.7 * alpha), false, 5.0)


func _draw_floaters() -> void:
	for floater in _snapshot.get("floaters", []):
		var color := floater.get("color", Color.WHITE) as Color
		color.a = clampf(float(floater.get("ttl", 0.0)) / 0.7, 0.0, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			floater.get("pos", Vector2.ZERO),
			String(floater.get("text", "")),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1.0,
			26,
			color
		)


func _enemy_color(kind: String) -> Color:
	match kind:
		"fast":
			return Color(0.58, 0.95, 0.44)
		"tank":
			return Color(0.72, 0.45, 0.28)
		"elite":
			return Color(1.0, 0.55, 0.18)
		"boss":
			return Color(0.85, 0.10, 0.08)
	return Color(0.42, 0.72, 0.50)
