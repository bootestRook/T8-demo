extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("ResultOverlayScreenshotRunner loaded without --screenshot-dir; dry-load only.")
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
		push_error("Failed to find Hud in %s" % MAIN_SCENE)
		get_tree().quit(4)
		return
	_prepare_hud_for_result(hud)
	_prepare_high_chain_snapshot()
	PrototypeState.phase = PrototypeState.Phase.LOST
	var lost_snapshot := PrototypeState.get_snapshot()
	hud.result_overlay.update(lost_snapshot, PrototypeState.Phase.LOST, PrototypeState.Phase.WON)
	await _wait_frames(12)
	_save_viewport("result-lost")
	hud.result_overlay.hide()
	PrototypeState.phase = PrototypeState.Phase.WON
	var won_snapshot := PrototypeState.get_snapshot()
	hud.result_overlay.update(won_snapshot, PrototypeState.Phase.LOST, PrototypeState.Phase.WON)
	await _wait_frames(12)
	_save_viewport("result-won")
	get_tree().quit(0)


func _prepare_hud_for_result(hud: Hud) -> void:
	hud.main_menu_overlay.visible = false
	hud.pause_overlay.visible = false
	hud.reward_overlay.hide()
	hud.pile_overlay_controller.hide()


func _prepare_high_chain_snapshot() -> void:
	PrototypeState.card_chain.reset()
	PrototypeState.card_chain.on_card_played(0)
	PrototypeState.card_chain.on_card_played(1)
	PrototypeState.card_chain.on_card_played(2)
	PrototypeState.card_chain.on_card_played(3)
	PrototypeState.level = 5
	PrototypeState.next_wave_index = PrototypeState.wave_configs.size()


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _save_viewport(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join("%s.png" % label)
	var error := image.save_png(path)
	if error != 0:
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
