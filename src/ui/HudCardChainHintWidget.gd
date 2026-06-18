extends RefCounted
class_name HudCardChainHintWidget

const HUD_CARD_CHAIN_HINT_NODES := preload("res://src/ui/HudCardChainHintNodes.gd")


static func ensure_widget(widget: Dictionary) -> void:
	var nodes := HUD_CARD_CHAIN_HINT_NODES.ensure(widget)
	widget["chain_cost_glow"] = nodes["glow"]
	widget["chain_cost_sparkles"] = nodes["sparkles"]


static func update_widget(widget: Dictionary, active: bool, time: float) -> void:
	ensure_widget(widget)
	var glow_panel: Control = widget["chain_cost_glow"] as Control
	var sparkles: Array = widget["chain_cost_sparkles"] as Array
	glow_panel.visible = active
	if not active:
		var inactive_cost_label: Label = widget["cost"] as Label
		inactive_cost_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.96))
		for sparkle in sparkles:
			(sparkle as Label).visible = false
		return
	var cost_label: Label = widget["cost"] as Label
	cost_label.add_theme_color_override("font_outline_color", Color(0.58, 0.32, 0.02, 1.0))
	var pulse := 0.5 + 0.5 * sin(time * 4.3)
	glow_panel.modulate = Color(1.0, 0.88, 0.18, 0.70 + 0.22 * pulse)
	var glow_scale := 1.04 + 0.10 * pulse
	glow_panel.scale = Vector2(glow_scale, glow_scale)
	for index in range(sparkles.size()):
		var sparkle: Label = sparkles[index] as Label
		var bases: Array = widget.get("chain_sparkle_base_positions", []) as Array
		var base_position := sparkle.position
		if index < bases.size() and bases[index] is Vector2:
			base_position = bases[index] as Vector2
		var phase := time * (4.8 + float(index) * 0.55) + float(index) * 1.83
		var alpha := 0.45 + 0.55 * (0.5 + 0.5 * sin(phase))
		sparkle.visible = true
		sparkle.position = base_position + Vector2(sin(phase + 1.57) * 2.1, sin(phase) * 1.8)
		sparkle.modulate = Color(1.0, 0.96, 0.72, alpha)
		var sparkle_scale := 0.94 + 0.34 * alpha
		sparkle.scale = Vector2(sparkle_scale, sparkle_scale)
