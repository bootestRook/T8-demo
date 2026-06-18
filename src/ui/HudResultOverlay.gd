extends RefCounted
class_name HudResultOverlay

var overlay: Control = null
var panel: Control = null
var title_label: Label = null
var summary_label: Label = null
var stats_label: Label = null
var reward_spacer: Control = null
var return_button: Button = null
var retry_button: Button = null

const TITLE_Y_RATIO := 0.172
const SUMMARY_Y_RATIO := 0.232
const STATS_Y_RATIO := 0.438
const BUTTON_Y_RATIO := 0.630

const FAILURE_TITLE_COLOR := Color(1.0, 0.98, 0.94, 1.0)
const FAILURE_SUMMARY_COLOR := Color(1.0, 0.96, 0.88, 1.0)
const SUCCESS_TITLE_COLOR := Color(1.0, 0.78, 0.10, 1.0)
const SUCCESS_SUMMARY_COLOR := Color(1.0, 0.74, 0.08, 1.0)
const RESULT_STATS_COLOR := Color(0.06, 0.055, 0.045, 1.0)


func setup(
	overlay_node: Control,
	panel_node: Control,
	title_node: Label,
	summary_node: Label,
	stats_node: Label,
	spacer_node: Control,
	button_node: Button,
	retry_node: Button,
	return_pressed: Callable,
	retry_pressed: Callable
) -> void:
	overlay = overlay_node
	panel = panel_node
	title_label = title_node
	summary_label = summary_node
	stats_label = stats_node
	reward_spacer = spacer_node
	return_button = button_node
	retry_button = retry_node
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if not return_button.pressed.is_connected(return_pressed):
		return_button.pressed.connect(return_pressed)
	if not retry_button.pressed.is_connected(retry_pressed):
		retry_button.pressed.connect(retry_pressed)


func style(theme: Variant) -> void:
	_apply_result_label_style(false)
	title_label.add_theme_font_size_override("font_size", 50)
	summary_label.add_theme_font_size_override("font_size", 32)
	stats_label.add_theme_font_size_override("font_size", 44)
	_style_result_button(return_button)
	_style_result_button(retry_button)


func layout(viewport_size: Vector2) -> void:
	panel.custom_minimum_size = Vector2.ZERO
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_spacer.visible = false
	_place_full_width_label(title_label, viewport_size.y * TITLE_Y_RATIO, viewport_size, 72.0)
	_place_full_width_label(summary_label, viewport_size.y * SUMMARY_Y_RATIO, viewport_size, 48.0)
	_place_full_width_label(stats_label, viewport_size.y * STATS_Y_RATIO, viewport_size, 72.0)
	var button_height := clampf(viewport_size.y * 0.041, 58.0, 78.0)
	var button_width := clampf(viewport_size.x * 0.296, 148.0, 320.0)
	var button_gap := clampf(viewport_size.x * 0.083, 30.0, 96.0)
	var button_size := Vector2(button_width, button_height)
	var total_width := button_width * 2.0 + button_gap
	var button_y := viewport_size.y * BUTTON_Y_RATIO
	return_button.custom_minimum_size = button_size
	return_button.size = button_size
	return_button.position = Vector2((viewport_size.x - total_width) * 0.5, button_y)
	retry_button.custom_minimum_size = button_size
	retry_button.size = button_size
	retry_button.position = return_button.position + Vector2(button_width + button_gap, 0.0)


func update(snapshot: Dictionary, lost_phase: int, won_phase: int) -> bool:
	var phase := int(snapshot.get("phase", -1))
	var should_show := phase == lost_phase or phase == won_phase
	if not should_show:
		hide()
		return false
	var won := phase == won_phase
	title_label.text = "挑战成功" if phase == won_phase else "挑战失败"
	summary_label.text = "已获得奖励" if phase == won_phase else "本轮已结束"
	stats_label.text = _stats_text(snapshot)
	stats_label.visible = true
	_apply_result_label_style(won)
	if is_visible():
		return false
	overlay.visible = true
	return_button.grab_focus()
	return true


func hide() -> void:
	if overlay != null:
		overlay.visible = false


func is_visible() -> bool:
	return overlay != null and overlay.visible


func _stats_text(snapshot: Dictionary) -> String:
	var highest_chain := int(snapshot.get("highest_chain_multiplier", 0))
	return "最高连锁 X%d" % highest_chain


func _place_full_width_label(label: Label, y: float, viewport_size: Vector2, height: float) -> void:
	label.position = Vector2(0.0, y)
	label.size = Vector2(viewport_size.x, height)


func _apply_label_shadow(label: Label, font_color: Color, shadow_color: Color, offset: int) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", shadow_color)
	label.add_theme_constant_override("shadow_offset_x", offset)
	label.add_theme_constant_override("shadow_offset_y", offset)


func _apply_result_label_style(won: bool) -> void:
	if won:
		_apply_label_shadow(title_label, SUCCESS_TITLE_COLOR, Color(0.0, 0.0, 0.0, 0.86), 2)
		_apply_label_shadow(summary_label, SUCCESS_SUMMARY_COLOR, Color(0.0, 0.0, 0.0, 0.82), 2)
	else:
		_apply_label_shadow(title_label, FAILURE_TITLE_COLOR, Color(0.0, 0.0, 0.0, 0.94), 3)
		_apply_label_shadow(summary_label, FAILURE_SUMMARY_COLOR, Color(0.25, 0.10, 0.02, 0.94), 2)
	_apply_label_shadow(stats_label, RESULT_STATS_COLOR, Color(1.0, 1.0, 1.0, 0.30), 1)


func _style_result_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.88, 0.03, 1.0)
	normal.border_color = Color(1.0, 0.84, 0.0, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	normal.shadow_size = 4
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.93, 0.12, 1.0)
	hover.border_color = Color(1.0, 0.88, 0.04, 1.0)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.92, 0.76, 0.02, 1.0)
	pressed.border_color = Color(0.92, 0.70, 0.0, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	var text_color := Color(0.10, 0.07, 0.01, 1.0)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", 28)
