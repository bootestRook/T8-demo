extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"
const HAND_CARD_IDS := ["starter_first_aid", "starter_temporary_shield", "starter_weakpoint_mark", "starter_infinite_fire"]

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("ChainCostHintScreenshotRunner loaded without --screenshot-dir; dry-load only.")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var packed := load(MAIN_SCENE)
	if not packed is PackedScene:
		push_error("Failed to load scene: %s" % MAIN_SCENE)
		get_tree().quit(3)
		return
	var instance := (packed as PackedScene).instantiate()
	add_child(instance)
	call_deferred("_run_capture_sequence", instance)


func _run_capture_sequence(instance: Node) -> void:
	await _wait_frames(20)
	if instance.has_method("_on_main_menu_start_requested"):
		instance.call("_on_main_menu_start_requested", ContentUnits.DEFAULT_LEVEL_ID)
	await _wait_frames(20)
	var hud := instance.get_node_or_null("Hud") as Hud
	if hud == null:
		push_error("Hud not found for chain cost hint screenshot.")
		get_tree().quit(4)
		return
	PrototypeState.hand_card_ids = HAND_CARD_IDS.duplicate()
	PrototypeState.current_energy = 3.0
	PrototypeState.card_chain.reset()
	PrototypeState.card_chain.on_card_played(0)
	PrototypeState.phase = PrototypeState.Phase.PLAYING
	var snapshot := PrototypeState.get_snapshot()
	snapshot["can_play_cards"] = true
	hud.set_battle_snapshot(snapshot)
	await _wait_frames(36)
	_save_viewport("chain-cost-hint")
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
