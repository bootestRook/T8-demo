extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenuScreen.tscn"

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("MainMenuLockedPreviewScreenshotRunner loaded without --screenshot-dir; dry-load only.")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	call_deferred("_run_capture_sequence")


func _run_capture_sequence() -> void:
	var content_units: Variant = get_node_or_null("/root/ContentUnits")
	var progress_store: Variant = get_node_or_null("/root/ProgressStore")
	if content_units == null or progress_store == null:
		push_error("ContentUnits or ProgressStore autoload is missing")
		get_tree().quit(3)
		return
	content_units.load_combat_configs(content_units.DEFAULT_LEVEL_ID)
	progress_store.level_statuses.clear()
	progress_store.completed_units.clear()
	progress_store.level_statuses["1"] = "cleared"
	var packed := load(MAIN_MENU_SCENE)
	if not packed is PackedScene:
		push_error("Failed to load scene: %s" % MAIN_MENU_SCENE)
		get_tree().quit(4)
		return
	var menu := (packed as PackedScene).instantiate() as MainMenuScreen
	if menu == null:
		push_error("Failed to instantiate MainMenuScreen.")
		get_tree().quit(5)
		return
	add_child(menu)
	await _wait_frames(8)
	menu._on_next_pressed()
	await _wait_frames(2)
	menu._on_next_pressed()
	await _wait_frames(8)
	_save_viewport("locked-next-level")
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


func _arg_value(name: String, default_value := "") -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].substr(name.length() + 1)
	return default_value
