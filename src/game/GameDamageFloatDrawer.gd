extends RefCounted

class_name GameDamageFloatDrawer


static func draw_damage_floats(canvas: CanvasItem, snapshot: Dictionary, damage_font: Font) -> void:
	var effects: Array = snapshot.get("combat_effects", [])
	for item in effects:
		if not (item is Dictionary):
			continue
		var effect: Dictionary = item
		var remaining := float(effect.get("remaining", 0.0))
		var duration := maxf(0.01, float(effect.get("duration", 0.34)))
		var ratio := clampf(remaining / duration, 0.0, 1.0)
		_draw_damage_float(canvas, damage_font, effect, ratio)


static func _draw_damage_float(canvas: CanvasItem, damage_font: Font, effect: Dictionary, ratio: float) -> void:
	if damage_font == null or not _is_damage_float_effect(effect):
		return
	var amount := float(effect.get("amount", 0.0))
	var critical := bool(effect.get("critical", false))
	var element := String(effect.get("element", "physical"))
	var position: Vector2 = effect.get("position", Vector2.ZERO)
	var rise := (1.0 - ratio) * (62.0 if critical else 42.0)
	var lane := float((int(amount) + String(effect.get("id", "")).length()) % 5) - 2.0
	var draw_position := position + Vector2(lane * 9.0 - 56.0, -24.0 - rise)
	var font_size := 30 if critical else 22
	var width := 118.0 if critical else 104.0
	var text := _damage_float_label(amount, critical)
	var color := _damage_float_color(element, ratio, critical)
	var shadow := Color(0.02, 0.015, 0.01, 0.82 * ratio)
	canvas.draw_string(damage_font, draw_position + Vector2(2.0, 3.0), text, 1, width, font_size, shadow)
	if critical:
		var glow := Color(1.0, 0.96, 0.62, 0.78 * ratio)
		var line_rect := Rect2(draw_position + Vector2(8.0, -font_size + 3.0), Vector2(width - 18.0, 4.0))
		canvas.draw_rect(line_rect, Color(color.r, color.g, color.b, 0.42 * ratio), true)
		canvas.draw_string(damage_font, draw_position + Vector2(-2.0, -2.0), text, 1, width, font_size + 2, glow)
	canvas.draw_string(damage_font, draw_position, text, 1, width, font_size, color)


static func _is_damage_float_effect(effect: Dictionary) -> bool:
	return bool(effect.get("is_player_damage", false)) and float(effect.get("amount", 0.0)) > 0.0


static func _damage_float_label(amount: float, critical: bool) -> String:
	var value := int(amount + 0.5)
	if critical:
		return "괬샌 %d!" % value
	return str(value)


static func _damage_float_color(element: String, ratio: float, critical: bool) -> Color:
	var alpha := clampf(0.18 + 0.90 * ratio, 0.0, 1.0)
	if critical:
		alpha = clampf(0.35 + 0.95 * ratio, 0.0, 1.0)
	if element == "fire":
		return Color(1.0, 0.42, 0.10, alpha)
	if element == "ice":
		return Color(0.36, 0.90, 1.0, alpha)
	if element == "electric":
		return Color(0.96, 0.92, 0.25, alpha)
	return Color(0.92, 0.92, 0.86, alpha)
