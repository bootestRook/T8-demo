extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"

var _output_dir := ""
var _frames_between_shots := 18


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	var scene_path := _arg_value("--scene", MAIN_SCENE)
	var frames_text := _arg_value("--frames-between-shots", str(_frames_between_shots))
	_frames_between_shots = max(1, frames_text.to_int())

	if _output_dir.is_empty():
		print("RuntimeScreenshotRunner loaded without --screenshot-dir; dry-load only.")
		get_tree().quit(0)
		return

	DirAccess.make_dir_recursive_absolute(_output_dir)
	var packed := load(scene_path)
	if not packed is PackedScene:
		push_error("Failed to load scene: %s" % scene_path)
		get_tree().quit(3)
		return

	var instance := (packed as PackedScene).instantiate()
	add_child(instance)
	call_deferred("_run_capture_sequence")


func _run_capture_sequence() -> void:
	await _wait_frames(_frames_between_shots)
	_save_viewport("ready")

	var viewport := get_viewport()
	viewport.push_input(_mouse_click_event(Vector2(400.0, 300.0), true))
	viewport.push_input(_mouse_click_event(Vector2(400.0, 300.0), false))
	await _wait_frames(_frames_between_shots)
	_save_viewport("running")

	for action in ["ui_right", "ui_left", "ui_accept"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		viewport.push_input(event)
		await _wait_frames(3)
		event = InputEventAction.new()
		event.action = action
		event.pressed = false
		viewport.push_input(event)
		await _wait_frames(3)

	await _wait_frames(_frames_between_shots)
	_save_viewport("input-after")
	get_tree().quit(0)


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _save_viewport(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join("%s.png" % label)
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save screenshot %s: %s" % [path, error])
	else:
		print("screenshot:%s:%s" % [label, path])


func _mouse_click_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = pressed
	return event


func _arg_value(name: String, default_value := "") -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].substr(name.length() + 1)
	return default_value
