extends RefCounted
class_name HudRewardOverlay

signal choice_selected(index: int)

const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_REWARD_CHOICE_CONTENT := preload("res://src/ui/HudRewardChoiceContent.gd")
const HUD_REWARD_CHOICE_BUTTONS := preload("res://src/ui/HudRewardChoiceButtons.gd")
const HUD_REWARD_OVERLAY_VIEW := preload("res://src/ui/HudRewardOverlayView.gd")
const CHOICE_FEEDBACK_DELAY := 0.25
const CHOICE_SELECTED_SCALE := Vector2(1.08, 1.08)
const CHOICE_SETTLED_SCALE := Vector2(1.03, 1.03)
const CHOICE_GOLD_TINT := Color(1.0, 0.94, 0.50, 1.0)
const CHOICE_DIM_TINT := Color(0.42, 0.38, 0.30, 0.55)

var root: Control = null
var overlay: Control = null
var center: CenterContainer = null
var panel: PanelContainer = null
var button_box: HBoxContainer = null
var _choice_signature := ""
var _selection_locked := false
var _selected_index := -1
var _delay_tween: Tween = null


func setup(root_control: Control) -> void:
	root = root_control
	_ensure_overlay()


func is_visible() -> bool:
	return overlay != null and overlay.visible


func selected_choice_global_center() -> Vector2:
	if button_box == null or _selected_index < 0 or _selected_index >= button_box.get_child_count():
		return Vector2.ZERO
	var button := button_box.get_child(_selected_index) as Button
	if button == null:
		return Vector2.ZERO
	var rect := button.get_global_rect()
	return rect.position + rect.size * 0.5


func hide() -> void:
	_reset_selection_feedback()
	if overlay != null:
		overlay.visible = false
	_choice_signature = ""


func layout(viewport_size: Vector2, compact_width: float) -> void:
	if center == null or panel == null or button_box == null:
		return
	var compact := viewport_size.x <= compact_width
	var side_margin := clampf(viewport_size.x * 0.05, 8.0, 64.0)
	var vertical_lift := viewport_size.y * (0.07 if compact else 0.12)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = side_margin
	center.offset_right = -side_margin
	center.offset_top = -vertical_lift
	center.offset_bottom = -vertical_lift

	var panel_width := clampf(viewport_size.x * (0.96 if compact else 0.84), 360.0, 900.0)
	var panel_height := clampf(viewport_size.y * (0.48 if compact else 0.29), 430.0, 560.0)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)

	var gap := int(maxf(12.0, viewport_size.x * (0.018 if compact else 0.020)))
	button_box.add_theme_constant_override("separation", gap)
	var card_width := maxf(92.0, (panel_width - 48.0 - float(gap * 2)) / 3.0)
	var card_height := maxf(320.0, panel_height - 125.0)
	for child in button_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 20 if compact else 25)


func update(snapshot: Dictionary, gameplay_active: bool, main_menu_visible: bool, viewport_size: Vector2, compact_width: float) -> void:
	_ensure_overlay()
	var choices_variant: Variant = snapshot.get("upgrade_choices", [])
	var choices: Array = []
	if choices_variant is Array:
		choices = choices_variant as Array
	var is_level_up := int(snapshot.get("phase", 1)) == 2 and choices.size() > 0
	overlay.visible = is_level_up and gameplay_active and not main_menu_visible
	if overlay.visible:
		if _selection_locked:
			return
		var next_signature := _choices_signature(choices)
		if next_signature != _choice_signature:
			_choice_signature = next_signature
			_rebuild_buttons(choices, viewport_size, compact_width)
		else:
			layout(viewport_size, compact_width)
	else:
		_reset_selection_feedback()
		_choice_signature = ""


func handle_input(event: InputEvent) -> bool:
	if not is_visible() or not (event is InputEventMouseButton):
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
		return false
	var choice_index := _choice_index_at_point(mouse_button.global_position)
	if choice_index == -1:
		return false
	_begin_choice_feedback(choice_index)
	return true


func _ensure_overlay() -> void:
	if overlay != null or root == null:
		return
	var nodes := HUD_REWARD_OVERLAY_VIEW.build(root)
	overlay = nodes["overlay"] as Control
	center = nodes["center"] as CenterContainer
	panel = nodes["panel"] as PanelContainer
	button_box = nodes["button_box"] as HBoxContainer


func _rebuild_buttons(choices: Array, viewport_size: Vector2, compact_width: float) -> void:
	_reset_selection_feedback()
	HUD_REWARD_CHOICE_BUTTONS.rebuild(button_box, choices, Callable(self, "_on_choice_pressed"))
	layout(viewport_size, compact_width)


func _choice_index_at_point(point: Vector2) -> int:
	var choice_index := -1
	if button_box != null:
		for index in range(button_box.get_child_count()):
			var button := button_box.get_child(index) as Button
			if button != null and button.visible and button.get_global_rect().has_point(point):
				choice_index = index
				break
	return choice_index


func _on_choice_pressed(index: int) -> void:
	_begin_choice_feedback(index)


func _begin_choice_feedback(index: int) -> void:
	if _selection_locked or button_box == null:
		return
	if index < 0 or index >= button_box.get_child_count():
		return
	var selected_button := button_box.get_child(index) as Button
	if selected_button == null:
		return
	_selection_locked = true
	_selected_index = index
	_apply_choice_feedback_style(index)
	_play_choice_feedback(index)


func _apply_choice_feedback_style(index: int) -> void:
	for child_index in range(button_box.get_child_count()):
		var button := button_box.get_child(child_index) as Button
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pivot_offset = button.size * 0.5
		if child_index == index:
			button.add_theme_stylebox_override(
				"normal", HUD_THEME.panel_style(Color(0.20, 0.17, 0.09, 0.98), Color(1.0, 0.88, 0.36, 1.0), 5, 4)
			)
			button.add_theme_stylebox_override(
				"hover", HUD_THEME.panel_style(Color(0.20, 0.17, 0.09, 0.98), Color(1.0, 0.88, 0.36, 1.0), 5, 4)
			)
			button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.64))


func _play_choice_feedback(index: int) -> void:
	if overlay == null or button_box == null:
		return
	var visual_tween := overlay.create_tween()
	visual_tween.set_parallel(true)
	for child_index in range(button_box.get_child_count()):
		var button := button_box.get_child(child_index) as Button
		if button == null:
			continue
		if child_index == index:
			visual_tween.tween_property(button, "modulate", CHOICE_GOLD_TINT, 0.08)
			var scale_up_tween := overlay.create_tween()
			scale_up_tween.tween_property(button, "scale", CHOICE_SELECTED_SCALE, 0.08)
			scale_up_tween.tween_property(button, "scale", CHOICE_SETTLED_SCALE, 0.12)
		else:
			visual_tween.tween_property(button, "modulate", CHOICE_DIM_TINT, 0.12)
	if _delay_tween != null:
		_delay_tween.kill()
	_delay_tween = overlay.create_tween()
	_delay_tween.tween_interval(CHOICE_FEEDBACK_DELAY)
	_delay_tween.tween_callback(Callable(self, "_emit_selected_choice"))


func _emit_selected_choice() -> void:
	if _selected_index == -1:
		return
	choice_selected.emit(_selected_index)


func _reset_selection_feedback() -> void:
	if _delay_tween != null:
		_delay_tween.kill()
		_delay_tween = null
	_selection_locked = false
	_selected_index = -1
	if button_box == null:
		return
	for child in button_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.scale = Vector2.ONE
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _choices_signature(choices: Array) -> String:
	return HUD_REWARD_CHOICE_CONTENT.choices_signature(choices)
