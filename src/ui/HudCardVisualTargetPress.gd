extends RefCounted
class_name HudCardVisualTargetPress


static func apply(target: Dictionary, press_feedback: Dictionary, feel_config: Dictionary) -> void:
	var press_weight := float(press_feedback.get("weight", 0.0))
	if press_weight <= 0.0:
		return
	var press_normal: Vector2 = press_feedback.get("normal", Vector2.ZERO)
	var target_position: Vector2 = target["position"]
	var target_scale: Vector2 = target["scale"]
	var target_rotation := float(target["rotation"])
	var tilt_radians := _feel_value(feel_config, "hover_press_tilt_degrees") * 0.0174532925
	target_rotation += -press_normal.x * tilt_radians * press_weight
	target_position.x += -press_normal.x * _feel_value(feel_config, "hover_press_offset") * press_weight
	target_position.y += _feel_value(feel_config, "hover_press_down_offset") * press_weight
	target_position.y += maxf(0.0, press_normal.y) * _feel_value(feel_config, "hover_press_offset") * 0.45 * press_weight
	target_scale *= 1.0 + (_feel_value(feel_config, "hover_press_scale") - 1.0) * press_weight
	target["position"] = target_position
	target["scale"] = target_scale
	target["rotation"] = target_rotation


static func _feel_value(feel_config: Dictionary, key: String) -> float:
	return float(feel_config.get(key, 0.0))
