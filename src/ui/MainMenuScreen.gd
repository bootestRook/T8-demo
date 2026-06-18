extends CanvasLayer
class_name MainMenuScreen

signal start_requested(level_id: String)

const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const UNLOCK_HINT_TEXT := "通过当前关卡解锁"
const UNLOCK_HINT_FLOAT_SECONDS := 0.85
const UNLOCK_HINT_FLOAT_DISTANCE := 56.0
const UNLOCK_HINT_SIZE := Vector2(280.0, 42.0)

@onready var root_control: Control = $Root
@onready var status_label: Label = %StatusLabel
@onready var level_label: Label = %LevelLabel
@onready var rule_chain_label: Label = %RuleChainLabel
@onready var rule_inherit_label: Label = %RuleInheritLabel
@onready var previous_button: Button = %PreviousLevelButton
@onready var next_button: Button = %NextLevelButton
@onready var start_button: Button = %StartGameButton

var _level_ids: Array[String] = []
var _all_level_ids: Array[String] = []
var _selected_index := 0
var _unlock_hint_label: Label = null


func _ready() -> void:
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_apply_styles()
	_refresh_levels()
	show_menu()


func show_menu() -> void:
	_refresh_levels()
	_hide_unlock_hint()
	visible = true
	start_button.grab_focus()


func get_selected_level_id() -> String:
	if _level_ids.is_empty():
		return ContentUnits.DEFAULT_LEVEL_ID
	return _level_ids[_selected_index]


func is_unlock_hint_visible() -> bool:
	return _unlock_hint_label != null and not _unlock_hint_label.is_queued_for_deletion() and _unlock_hint_label.visible


func get_unlock_hint_text() -> String:
	if _unlock_hint_label == null or _unlock_hint_label.is_queued_for_deletion():
		return ""
	return _unlock_hint_label.text


func _refresh_levels() -> void:
	if ContentUnits.level_configs.is_empty():
		ContentUnits.load_combat_configs(ContentUnits.active_level_id)
	_all_level_ids.clear()
	var keys := ContentUnits.level_configs.keys()
	for key in keys:
		_all_level_ids.append(String(key))
	_all_level_ids.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	if _all_level_ids.is_empty():
		_all_level_ids.append(ContentUnits.DEFAULT_LEVEL_ID)
	_level_ids = ProgressStore.get_visible_level_ids(_all_level_ids)
	if _level_ids.is_empty():
		_level_ids.append(ContentUnits.DEFAULT_LEVEL_ID)
	_selected_index = clampi(_selected_index, 0, _level_ids.size() - 1)
	_update_labels()


func _update_labels() -> void:
	var level_id := get_selected_level_id()
	var level_config := ContentUnits.get_level_config(level_id)
	var stage_name := String(level_config.get("stage_name", "关卡.%s" % level_id))
	status_label.text = ProgressStore.get_level_status_label(level_id)
	level_label.text = stage_name
	var has_previous := _selected_index > 0
	var has_visible_next := _selected_index < _level_ids.size() - 1
	var has_locked_next := _has_locked_next_level()
	previous_button.disabled = not has_previous
	next_button.disabled = not (has_visible_next or has_locked_next)
	previous_button.text = "<" if has_previous else ""
	next_button.text = ">" if has_visible_next or has_locked_next else ""
	start_button.text = "开始游戏"


func _on_previous_pressed() -> void:
	if _selected_index <= 0:
		return
	_selected_index -= 1
	_hide_unlock_hint()
	_update_labels()


func _on_next_pressed() -> void:
	if _selected_index < _level_ids.size() - 1:
		_selected_index += 1
		_hide_unlock_hint()
		_update_labels()
		return
	if _has_locked_next_level():
		_spawn_unlock_hint(next_button)


func _on_start_pressed() -> void:
	if not _is_selected_level_playable():
		_spawn_unlock_hint(start_button)
		start_button.grab_focus()
		return
	_hide_unlock_hint()
	visible = false
	start_requested.emit(get_selected_level_id())


func _is_selected_level_playable() -> bool:
	return ProgressStore.is_level_playable(get_selected_level_id(), _all_level_ids)


func _has_locked_next_level() -> bool:
	var level_id := get_selected_level_id()
	var all_index := _all_level_ids.find(level_id)
	return all_index >= 0 and all_index < _all_level_ids.size() - 1


func _spawn_unlock_hint(source: Control) -> void:
	_hide_unlock_hint()
	var label := Label.new()
	label.name = "UnlockHintFloatLabel"
	label.text = UNLOCK_HINT_TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = UNLOCK_HINT_SIZE
	label.position = _unlock_hint_start_position(source)
	label.z_index = 20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.07, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.97, 0.97, 0.95, 0.70))
	label.add_theme_constant_override("outline_size", 2)
	root_control.add_child(label)
	_unlock_hint_label = label

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - UNLOCK_HINT_FLOAT_DISTANCE, UNLOCK_HINT_FLOAT_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, UNLOCK_HINT_FLOAT_SECONDS)
	_finish_unlock_hint_after_tween(label, tween)


func _hide_unlock_hint() -> void:
	if _unlock_hint_label != null and not _unlock_hint_label.is_queued_for_deletion():
		_unlock_hint_label.queue_free()
	_unlock_hint_label = null


func _unlock_hint_start_position(source: Control) -> Vector2:
	var source_rect := source.get_global_rect()
	var root_rect := root_control.get_global_rect()
	var source_center := source_rect.position + source_rect.size * 0.5 - root_rect.position
	return source_center - Vector2(UNLOCK_HINT_SIZE.x * 0.5, source_rect.size.y + 8.0)


func _finish_unlock_hint_after_tween(label: Label, tween: Tween) -> void:
	await tween.finished
	if label != null and not label.is_queued_for_deletion():
		label.queue_free()
	if _unlock_hint_label == label:
		_unlock_hint_label = null


func _apply_styles() -> void:
	for rule_label in [rule_chain_label, rule_inherit_label]:
		rule_label.add_theme_font_size_override("font_size", 36)
		rule_label.add_theme_color_override("font_color", Color(0.95, 0.02, 0.02, 1.0))
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.07, 1.0))
	level_label.add_theme_font_size_override("font_size", 31)
	level_label.add_theme_color_override("font_color", Color(0.06, 0.06, 0.05, 1.0))
	for button in [previous_button, next_button]:
		button.add_theme_font_size_override("font_size", 36)
		button.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
		button.add_theme_stylebox_override("normal", _flat_button_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
		button.add_theme_stylebox_override("hover", _flat_button_style(Color(0.92, 0.92, 0.88, 0.70), Color(0.25, 0.25, 0.22, 0.25)))
		button.add_theme_stylebox_override("pressed", _flat_button_style(Color(0.84, 0.84, 0.78, 0.80), Color(0.20, 0.20, 0.18, 0.35)))
		button.add_theme_stylebox_override("disabled", _flat_button_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
		button.add_theme_color_override("font_disabled_color", Color(0.0, 0.0, 0.0, 0.0))
	HUD_THEME.style_button(start_button, "primary_menu")
	start_button.add_theme_font_size_override("font_size", 26)


func _flat_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style
