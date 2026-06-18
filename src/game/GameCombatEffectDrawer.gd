extends RefCounted
class_name GameCombatEffectDrawer

const FULL_CIRCLE := 6.283185307179586


static func draw_effect_rings(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var effects: Array = snapshot.get("combat_effects", [])
	for item in effects:
		if not (item is Dictionary):
			continue
		var effect: Dictionary = item
		_draw_effect_ring(canvas, effect)


static func _draw_effect_ring(canvas: CanvasItem, effect: Dictionary) -> void:
	var position: Vector2 = effect.get("position", Vector2.ZERO)
	var remaining := float(effect.get("remaining", 0.0))
	var duration := maxf(0.01, float(effect.get("duration", 0.34)))
	var ratio := clampf(remaining / duration, 0.0, 1.0)
	var amount := float(effect.get("amount", 0.0))
	var radius := 18.0 + minf(40.0, amount * 0.18) * (1.0 - ratio)
	var color := Color(1.0, 0.86, 0.22, 0.50 * ratio)
	var kind := String(effect.get("kind", ""))
	if kind == "explosion_area":
		_draw_explosion_area(canvas, effect, position, radius, ratio)
		return
	if kind == "electro_pierce":
		_draw_electro_pierce_effect(canvas, effect, ratio)
		return
	if kind == "defeat":
		color = Color(0.70, 1.0, 0.30, 0.58 * ratio)
	elif kind == "freeze" or kind == "frostbite":
		color = Color(0.46, 0.90, 1.0, 0.54 * ratio)
	elif kind == "weakpoint":
		color = Color(1.0, 0.28, 0.16, 0.56 * ratio)
		radius = 34.0 + 18.0 * (1.0 - ratio)
	elif kind == "flash" or kind == "stun":
		color = Color(1.0, 0.96, 0.58, 0.62 * ratio)
		radius = 54.0 + 28.0 * (1.0 - ratio)
	elif kind == "wall_hit":
		color = Color(1.0, 0.18, 0.12, 0.62 * ratio)
	if not bool(effect.get("suppress_ring", false)):
		canvas.draw_circle(position, radius, color)


static func _draw_explosion_area(canvas: CanvasItem, effect: Dictionary, position: Vector2, fallback_radius: float, ratio: float) -> void:
	var area_radius := float(effect.get("area_radius", fallback_radius))
	canvas.draw_arc(position, area_radius, 0.0, FULL_CIRCLE, 64, Color(1.0, 0.38, 0.10, 0.52 * ratio), 5.0, true)
	canvas.draw_circle(position, area_radius * 0.38, Color(1.0, 0.58, 0.12, 0.22 * ratio))


static func _draw_electro_pierce_effect(canvas: CanvasItem, effect: Dictionary, ratio: float) -> void:
	var start_position: Vector2 = effect.get("start_position", Vector2(549.0, 1235.0))
	var end_position: Vector2 = effect.get("end_position", effect.get("position", Vector2.ZERO))
	var area_radius := float(effect.get("area_radius", 92.0))
	var alpha := 0.22 + 0.62 * ratio
	var bend_a := Vector2(end_position.x - 18.0, lerpf(start_position.y, end_position.y, 0.34))
	var bend_b := Vector2(end_position.x + 22.0, lerpf(start_position.y, end_position.y, 0.66))
	canvas.draw_circle(end_position, area_radius, Color(0.10, 0.88, 1.0, 0.08 * ratio))
	canvas.draw_circle(end_position, area_radius, Color(0.16, 0.95, 1.0, 0.38 * ratio), false, 5.0, true)
	canvas.draw_circle(end_position, area_radius * 0.62, Color(0.86, 1.0, 1.0, 0.16 * ratio), false, 3.0, true)
	canvas.draw_line(start_position, bend_a, Color(0.16, 0.95, 1.0, alpha), 16.0, true)
	canvas.draw_line(bend_a, bend_b, Color(0.16, 0.95, 1.0, alpha), 16.0, true)
	canvas.draw_line(bend_b, end_position, Color(0.16, 0.95, 1.0, alpha), 16.0, true)
	canvas.draw_line(start_position, bend_a, Color(0.94, 1.0, 1.0, alpha), 5.0, true)
	canvas.draw_line(bend_a, bend_b, Color(0.94, 1.0, 1.0, alpha), 5.0, true)
	canvas.draw_line(bend_b, end_position, Color(0.94, 1.0, 1.0, alpha), 5.0, true)
	canvas.draw_circle(end_position, 34.0 + 18.0 * (1.0 - ratio), Color(0.16, 0.95, 1.0, 0.36 * ratio), false, 5.0, true)
	canvas.draw_circle(end_position, 12.0 + 8.0 * ratio, Color(0.94, 1.0, 1.0, 0.82 * ratio))
