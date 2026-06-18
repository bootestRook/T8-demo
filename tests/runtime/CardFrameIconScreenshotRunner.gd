extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("CardFrameIconScreenshotRunner loaded without --screenshot-dir; dry-load only.")
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
		push_error("Hud not found for card frame icon screenshot.")
		get_tree().quit(4)
		return
	hud.start_battle_ui()
	instance.set_process(false)
	hud.set_battle_snapshot(_sample_snapshot())
	await _wait_frames(24)
	_save_viewport("card-frame-icons")
	get_tree().quit(0)


func _sample_snapshot() -> Dictionary:
	var snapshot := PrototypeState.get_snapshot()
	snapshot["phase"] = PrototypeState.Phase.PLAYING
	snapshot["energy"] = 3
	snapshot["energy_max"] = 3
	snapshot["hand_cards"] = [
		{
			"card_id": "thermobaric_test_shot",
			"name": "试射温压弹",
			"school": "温压弹",
			"cost": 0,
			"effect": "本次连锁爆炸伤害+20%",
		},
		{
			"card_id": "electro_pierce_test",
			"name": "电磁穿刺",
			"school": "电磁穿刺",
			"cost": 1,
			"effect": "穿透直线目标",
		},
		{
			"card_id": "dry_ice_test",
			"name": "干冰弹",
			"school": "干冰弹",
			"cost": 1,
			"effect": "减速并冻结",
		},
		{
			"card_id": "gun_test",
			"name": "枪械训练",
			"school": "枪械",
			"cost": 1,
			"effect": "枪械伤害提升",
		},
	]
	snapshot["draw_pile_cards"] = []
	snapshot["discard_pile_cards"] = []
	return snapshot


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
