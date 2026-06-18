extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("CardCostHoverScreenshotRunner loaded without --screenshot-dir; dry-load only.")
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
		push_error("Hud not found for card cost hover screenshot.")
		get_tree().quit(4)
		return
	hud.start_battle_ui()
	instance.set_process(false)
	hud.set_battle_snapshot(_sample_snapshot())
	await _wait_frames(8)
	var first_card := hud.get_node_or_null("Root/SafeMargin/MainLayout/HandArea/HandAreaRoot/HandLayer/Card2") as Control
	if first_card != null:
		_hover_card_center(first_card)
		await _wait_frames(10)
		_hover_card_center(first_card)
	await _wait_frames(36)
	_save_viewport("card-cost-hover")
	get_tree().quit(0)


func _hover_card_center(card: Control) -> void:
	var center := card.get_global_rect().get_center()
	get_viewport().warp_mouse(center)
	get_viewport().push_input(_mouse_motion_event(center))


func _sample_snapshot() -> Dictionary:
	var snapshot := PrototypeState.get_snapshot()
	snapshot["phase"] = PrototypeState.Phase.PLAYING
	snapshot["energy"] = 3
	snapshot["energy_max"] = 3
	snapshot["hand_cards"] = [
		{"card_id": "starter_sharp_reload", "name": "养精蓄锐", "school": "温压弹", "cost": 0, "effect": "停止射击3秒，然后射击间隔-20%，枪械伤害+50%，持续6秒"},
		{"card_id": "starter_infinite_fire", "name": "无限火力", "school": "温压弹", "cost": 2, "effect": "射击不消耗弹药，持续3秒"},
		{"card_id": "starter_tactical_reload", "name": "战术换弹", "school": "枪械", "cost": 3, "effect": "补充50%弹夹上限的弹药"},
		{"card_id": "thermal_explosion", "name": "热能爆发", "school": "温压弹", "cost": 3, "effect": "热能爆发的爆炸范围+80%"},
	]
	snapshot["draw_pile_cards"] = []
	snapshot["discard_pile_cards"] = []
	return snapshot


func _mouse_motion_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


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
