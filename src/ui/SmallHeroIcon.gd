extends Control

const HERO_DRAW_RECT := Rect2(Vector2(16.0, -72.0), Vector2(88.0, 209.0))
const RECOIL_DURATION := 0.16
const RECOIL_KICKBACK := 8.0
const RECOIL_SHAKE := 3.2
const RELOAD_DIP := 7.0
const RELOAD_SWAY := 2.6

var _hero_texture: Texture2D = null
var _last_shot_time := -1.0
var _recoil_timer := 0.0
var _is_reloading := false
var _reload_timer := 0.0
var _reload_time := 2.0
var _reload_anim_time := 0.0


func _ready() -> void:
	_hero_texture = AssetRegistry.load_texture(&"sprite", &"player_hero_v1")
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	if _recoil_timer > 0.0:
		_recoil_timer = maxf(0.0, _recoil_timer - delta)
		needs_redraw = true
	if _is_reloading:
		_reload_anim_time += delta
		needs_redraw = true
	elif _reload_anim_time > 0.0:
		_reload_anim_time = 0.0
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func set_battle_snapshot(snapshot: Dictionary) -> void:
	var gun_runtime: Dictionary = snapshot.get("gun_runtime", {}) as Dictionary
	_update_shot_motion(gun_runtime)
	_is_reloading = bool(snapshot.get("is_reloading", false))
	_reload_timer = float(snapshot.get("reload_timer", 0.0))
	_reload_time = maxf(0.01, float(gun_runtime.get("reload_time", _reload_time)))
	if not _is_reloading:
		_reload_timer = 0.0
	queue_redraw()


func _draw() -> void:
	if _hero_texture != null:
		draw_texture_rect(_hero_texture, _animated_hero_rect(), false)
		return
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


func _update_shot_motion(gun_runtime: Dictionary) -> void:
	var shot_log: Array = gun_runtime.get("shot_log", []) as Array
	if shot_log.is_empty():
		_last_shot_time = -1.0
		return
	var last_entry: Dictionary = shot_log[shot_log.size() - 1] as Dictionary
	var shot_time := float(last_entry.get("time", -1.0))
	if _last_shot_time < 0.0 or shot_time > _last_shot_time + 0.001:
		_recoil_timer = RECOIL_DURATION
	_last_shot_time = shot_time


func _animated_hero_rect() -> Rect2:
	var offset := _recoil_offset() + _reload_offset()
	var scale := 1.0 + _recoil_scale()
	var scaled_size := HERO_DRAW_RECT.size * scale
	var center := HERO_DRAW_RECT.position + HERO_DRAW_RECT.size * 0.5 + offset
	return Rect2(center - scaled_size * 0.5, scaled_size)


func _recoil_offset() -> Vector2:
	if _recoil_timer <= 0.0:
		return Vector2.ZERO
	var progress := clampf(1.0 - _recoil_timer / RECOIL_DURATION, 0.0, 1.0)
	var strength := 1.0 - progress
	var kick := RECOIL_KICKBACK * strength
	var shake := _recoil_shake_sign(progress) * RECOIL_SHAKE * strength
	return Vector2(shake, kick)


func _recoil_scale() -> float:
	if _recoil_timer <= 0.0:
		return 0.0
	var progress := clampf(1.0 - _recoil_timer / RECOIL_DURATION, 0.0, 1.0)
	return 0.012 * (1.0 - progress)


func _reload_offset() -> Vector2:
	if not _is_reloading:
		return Vector2.ZERO
	var progress := clampf(1.0 - _reload_timer / _reload_time, 0.0, 1.0)
	var dip := RELOAD_DIP * _reload_dip_curve(progress)
	var sway := RELOAD_SWAY * _triangle_wave(_reload_anim_time * 2.35)
	return Vector2(sway, dip)


func _reload_dip_curve(progress: float) -> float:
	if progress < 0.18:
		return progress / 0.18
	if progress > 0.84:
		return maxf(0.0, (1.0 - progress) / 0.16)
	return 1.0


func _recoil_shake_sign(progress: float) -> float:
	if progress < 0.25:
		return -1.0
	if progress < 0.50:
		return 1.0
	if progress < 0.75:
		return -0.45
	return 0.0


func _triangle_wave(value: float) -> float:
	var wrapped := value - floorf(value)
	if wrapped < 0.25:
		return wrapped * 4.0
	if wrapped < 0.75:
		return 2.0 - wrapped * 4.0
	return wrapped * 4.0 - 4.0
