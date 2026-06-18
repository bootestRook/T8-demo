extends RefCounted
class_name MonsterPresenter

const MONSTER_HIT_FLASH := preload("res://src/game/MonsterHitFlash.gd")

var _monster_texture_cache: Dictionary = {}


func draw_monsters(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var monsters: Array = snapshot.get("active_monsters", [])
	for item in monsters:
		if not (item is Dictionary):
			continue
		var monster: Dictionary = item
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		var radius := float(monster.get("radius", 24.0))
		var texture := _monster_texture(monster)
		if texture != null:
			var draw_size := _monster_draw_size(monster, texture, radius)
			var draw_position := position - Vector2(draw_size.x * 0.5, draw_size.y * 0.58)
			var texture_rect := Rect2(draw_position, draw_size)
			var status_tint := _monster_status_tint(monster)
			if status_tint.a > 0.0:
				canvas.draw_circle(position, radius * 1.38, Color(status_tint.r, status_tint.g, status_tint.b, 0.22))
			canvas.draw_texture_rect(texture, texture_rect, false)
			if status_tint.a > 0.0:
				canvas.draw_texture_rect(texture, texture_rect, false, status_tint)
			if MONSTER_HIT_FLASH.flash_weight(monster) > 0.0:
				canvas.draw_texture_rect(texture, texture_rect, false, MONSTER_HIT_FLASH.texture_overlay_color(monster))
			continue
		var color := MONSTER_HIT_FLASH.color_with_flash(_monster_color(monster), monster)
		var eye_color := MONSTER_HIT_FLASH.color_with_flash(Color(0.88, 0.95, 0.76), monster)
		canvas.draw_circle(position, radius, color)
		canvas.draw_circle(position + Vector2(-radius * 0.34, -radius * 0.18), radius * 0.18, eye_color)
		canvas.draw_circle(position + Vector2(radius * 0.34, -radius * 0.18), radius * 0.18, eye_color)


func draw_hp_bars(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var monsters: Array = snapshot.get("active_monsters", [])
	for item in monsters:
		if not (item is Dictionary):
			continue
		var monster: Dictionary = item
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		var radius := float(monster.get("radius", 24.0))
		var hp_max := maxf(1.0, float(monster.get("hp_max", 1.0)))
		var hp_ratio := clampf(float(monster.get("hp", hp_max)) / hp_max, 0.0, 1.0)
		var bar_size := Vector2(radius * 2.0, 7.0)
		var bar_position := position + Vector2(-radius, -radius - 16.0)
		canvas.draw_rect(Rect2(bar_position, bar_size), Color(0.05, 0.04, 0.035, 0.82), true)
		canvas.draw_rect(Rect2(bar_position, Vector2(bar_size.x * hp_ratio, bar_size.y)), Color(0.88, 0.20, 0.14), true)


func _monster_texture(monster: Dictionary) -> Texture2D:
	var asset_id := _monster_asset_id(monster)
	if asset_id.is_empty():
		return null
	if not _monster_texture_cache.has(asset_id):
		match asset_id:
			"monster_grunt":
				_monster_texture_cache[asset_id] = AssetRegistry.load_texture(&"sprite", &"monster_grunt")
			"monster_runner":
				_monster_texture_cache[asset_id] = AssetRegistry.load_texture(&"sprite", &"monster_runner")
			"monster_tank":
				_monster_texture_cache[asset_id] = AssetRegistry.load_texture(&"sprite", &"monster_tank")
			"monster_elite":
				_monster_texture_cache[asset_id] = AssetRegistry.load_texture(&"sprite", &"monster_elite")
			"monster_boss_cathedral":
				_monster_texture_cache[asset_id] = AssetRegistry.load_texture(&"sprite", &"monster_boss_cathedral")
			_:
				_monster_texture_cache[asset_id] = null
	return _monster_texture_cache[asset_id] as Texture2D


func _monster_asset_id(monster: Dictionary) -> String:
	var asset_id := ""
	var model := String(monster.get("model", ""))
	match model:
		"monster_grunt", "monster_advanced":
			asset_id = "monster_grunt"
		"monster_runner":
			asset_id = "monster_runner"
		"monster_tank":
			asset_id = "monster_tank"
		"monster_enhanced", "monster_elite":
			asset_id = "monster_elite"
		"monster_boss_cathedral":
			asset_id = "monster_boss_cathedral"
	if not asset_id.is_empty():
		return asset_id
	var monster_id := String(monster.get("monster_id", ""))
	match monster_id:
		"10", "20", "grunt":
			asset_id = "monster_grunt"
		"30", "brute":
			asset_id = "monster_tank"
		"100", "runner":
			asset_id = "monster_runner"
		"150", "3030", "elite":
			asset_id = "monster_elite"
		"5000", "boss":
			asset_id = "monster_boss_cathedral"
	return asset_id


func _monster_draw_size(monster: Dictionary, texture: Texture2D, radius: float) -> Vector2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2(radius * 2.0, radius * 2.0)
	var target_height := radius * 4.1
	var asset_id := _monster_asset_id(monster)
	if asset_id == "monster_runner":
		target_height = radius * 4.7
	elif asset_id == "monster_tank":
		target_height = radius * 4.3
	elif asset_id == "monster_elite":
		target_height = radius * 4.9
	elif asset_id == "monster_boss_cathedral":
		target_height = radius * 5.1
	target_height = maxf(target_height, 72.0)
	var aspect := texture_size.x / texture_size.y
	return Vector2(target_height * aspect, target_height)


func _monster_color(monster: Dictionary) -> Color:
	var monster_id := String(monster.get("monster_id", "grunt"))
	var color := Color(0.38, 0.68, 0.25)
	if monster_id == "runner":
		color = Color(0.60, 0.82, 0.28)
	elif monster_id == "brute":
		color = Color(0.44, 0.38, 0.22)
	elif monster_id == "elite":
		color = Color(0.54, 0.25, 0.60)
	elif monster_id == "boss":
		color = Color(0.72, 0.18, 0.16)
	var statuses: Dictionary = monster.get("statuses", {})
	if statuses.has("freeze") or statuses.has("frostbite"):
		color = Color(0.34, 0.72, 0.92)
	elif statuses.has("stun"):
		color = Color(0.96, 0.90, 0.36)
	elif statuses.has("weakpoint"):
		color = Color(0.94, 0.30, 0.16)
	elif statuses.has("paralyze") or statuses.has("slow"):
		color = Color(0.22, 0.78, 0.74)
	elif statuses.has("burn"):
		color = Color(0.96, 0.20, 0.10)
	return color


func _monster_status_tint(monster: Dictionary) -> Color:
	var statuses: Dictionary = monster.get("statuses", {})
	if statuses.has("freeze") or statuses.has("frostbite"):
		return Color(0.34, 0.96, 1.85, 0.58)
	if statuses.has("stun"):
		return Color(1.65, 1.42, 0.24, 0.64)
	if statuses.has("weakpoint") or statuses.has("mark") or statuses.has("marked"):
		return Color(1.50, 0.35, 0.18, 0.58)
	if statuses.has("paralyze") or statuses.has("slow"):
		return Color(0.22, 1.20, 1.10, 0.54)
	if statuses.has("burn"):
		return Color(1.85, 0.22, 0.08, 0.62)
	return Color(1.0, 1.0, 1.0, 0.0)
