extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("RewardSchoolCountScreenshotRunner loaded without --screenshot-dir; dry-load only.")
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
		push_error("Hud not found for reward school count screenshot.")
		get_tree().quit(4)
		return
	_prepare_reward_state(hud, [])
	await _wait_frames(24)
	_save_viewport("reward-cost-school-count-x0")
	_prepare_reward_state(hud, ["starter_first_aid"])
	await _wait_frames(24)
	_save_viewport("reward-cost-school-count-x1")
	get_tree().quit(0)


func _prepare_reward_state(hud: Hud, hand_card_ids: Array[String]) -> void:
	PrototypeState.hand_card_ids = hand_card_ids.duplicate()
	PrototypeState.draw_pile.clear()
	PrototypeState.discard_pile.clear()
	PrototypeState.phase = PrototypeState.Phase.LEVEL_UP
	var upgrades := [
		{"id": "shot_electro_draw_supply", "kind": "new_card", "card_id": "electro_draw_supply", "weight": 1.0},
		{"id": "shot_dry_ice_draw_supply", "kind": "new_card", "card_id": "dry_ice_draw_supply", "weight": 1.0},
		{"id": "shot_general_draw_supply", "kind": "new_card", "card_id": "general_draw_supply", "weight": 1.0},
	]
	PrototypeState.level_rewards.begin_level_up(
		upgrades, PrototypeState.card_configs, PrototypeState.card_deck, PrototypeState.card_chain, PrototypeState.upgrade_rng, 3
	)
	var snapshot := PrototypeState.get_snapshot()
	snapshot["can_play_cards"] = false
	hud.set_battle_snapshot(snapshot)


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
