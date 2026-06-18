extends RefCounted
class_name HudLayoutControlStyleApplier

const HUD_THEME := preload("res://src/ui/HudTheme.gd")


static func apply(hud: Node) -> void:
	HUD_THEME.style_button(_button(hud, "pause_button"), "pause")
	HUD_THEME.style_button(_button(hud, "discard_hand_button"), "menu")
	HUD_THEME.style_button(_button(hud, "discard_pile_button"), "pile")
	HUD_THEME.style_button(_button(hud, "draw_pile_button"), "pile")
	HUD_THEME.style_button(_button(hud, "start_game_button"), "primary_menu")
	HUD_THEME.style_button(_button(hud, "continue_button"), "primary_menu")
	HUD_THEME.style_button(_button(hud, "exit_button"), "primary_menu")
	(_prop(hud, "result_overlay") as HudResultOverlay).style(HUD_THEME)
	_apply_runtime_icons(hud)
	_apply_runtime_bars(hud)


static func _apply_runtime_icons(hud: Node) -> void:
	HUD_THEME.style_icon_button(_button(hud, "pause_button"), AssetRegistry.load_texture(&"ui", &"pause_icon_v1"), true)
	_restore_discard_hand_text_button(_button(hud, "discard_hand_button"))
	HUD_THEME.style_icon_button(_button(hud, "discard_pile_button"), AssetRegistry.load_texture(&"ui", &"discard_pile_icon_v1"))
	HUD_THEME.style_icon_button(_button(hud, "draw_pile_button"), AssetRegistry.load_texture(&"ui", &"draw_pile_icon_v1"))
	(_prop(hud, "ultimate_cost_badge") as PanelContainer).add_theme_stylebox_override(
		"panel", HUD_THEME.panel_style(Color(0.12, 0.10, 0.18, 0.96), Color(0.70, 0.24, 0.92, 0.95), 30, 2)
	)


static func _apply_runtime_bars(hud: Node) -> void:
	HUD_THEME.style_progress(_prop(hud, "exp_bar") as ProgressBar, Color(0.20, 0.55, 0.95), Color(0.05, 0.08, 0.12))
	HUD_THEME.style_progress(_prop(hud, "wall_hp_bar") as ProgressBar, Color(0.08, 0.78, 0.16), Color(0.08, 0.13, 0.08))
	HUD_THEME.style_progress(_prop(hud, "ultimate_bar") as ProgressBar, Color(0.95, 0.12, 0.82), Color(0.08, 0.10, 0.25))


static func _prop(hud: Node, property_name: String) -> Variant:
	return hud.get(property_name)


static func _button(hud: Node, property_name: String) -> Button:
	return hud.get(property_name) as Button


static func _restore_discard_hand_text_button(button: Button) -> void:
	if button == null:
		return
	button.icon = null
	button.expand_icon = false
	button.text = "弃牌"
	button.add_theme_stylebox_override(
		"disabled", HUD_THEME.panel_style(Color(0.10, 0.09, 0.075, 0.84), Color(0.34, 0.28, 0.18, 0.68), 7, 1)
	)
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.74, 0.64, 1.0))
