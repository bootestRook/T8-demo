extends RefCounted
class_name HudCardVisualInterpolator


static func apply(widget: Dictionary, panel: PanelContainer, target: Dictionary, delta: float) -> void:
	var weight_delta := 1.0 if delta <= 0.0 else clampf(delta * float(target["follow_speed"]), 0.0, 1.0)
	var current_position: Vector2 = widget.get("view_position", panel.position)
	var current_scale: Vector2 = widget.get("view_scale", panel.scale)
	var current_rotation := float(widget.get("view_rotation", panel.rotation))
	var target_position: Vector2 = target["position"]
	var target_scale: Vector2 = target["scale"]
	current_position += (target_position - current_position) * weight_delta
	current_scale += (target_scale - current_scale) * weight_delta
	current_rotation = lerpf(current_rotation, float(target["rotation"]), weight_delta)
	widget["view_position"] = current_position
	widget["view_scale"] = current_scale
	widget["view_rotation"] = current_rotation
	panel.position = current_position
	panel.scale = current_scale
	panel.rotation = current_rotation
	panel.z_index = int(target["z_index"])
