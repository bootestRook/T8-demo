extends CanvasLayer
class_name MenuPresenter

signal action_requested(action: StringName)

var panel: PanelContainer
var title_label: Label
var body_label: Label
var primary_button: Button
var secondary_button: Button
var _primary_action := &""
var _secondary_action := &""


func _ready() -> void:
	_build()
	hide()


func show_menu(
	title: String,
	body: String,
	primary_text: String = "开始",
	primary_action: StringName = &"start",
	secondary_text: String = "",
	secondary_action: StringName = &""
) -> void:
	_primary_action = primary_action
	_secondary_action = secondary_action
	title_label.text = title
	body_label.text = body
	primary_button.text = primary_text
	secondary_button.text = secondary_text
	secondary_button.visible = not secondary_text.is_empty()
	show()


func hide_menu() -> void:
	hide()


func _build() -> void:
	if panel != null:
		return
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 220.0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(body_label)

	primary_button = Button.new()
	primary_button.pressed.connect(_on_primary_pressed)
	layout.add_child(primary_button)

	secondary_button = Button.new()
	secondary_button.pressed.connect(_on_secondary_pressed)
	layout.add_child(secondary_button)


func _on_primary_pressed() -> void:
	_emit_action(_primary_action)


func _on_secondary_pressed() -> void:
	_emit_action(_secondary_action)


func _emit_action(action: StringName) -> void:
	if action == &"":
		return
	action_requested.emit(action)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.MENU_ACTION, {"action": action})
