extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"
const HUD_DEFAULTS := preload("res://src/ui/HudDefaults.gd")

var _output_dir := ""


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("PileOverlayScreenshotRunner loaded without --screenshot-dir; dry-load only.")
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
	if hud != null:
		hud.pile_overlay_controller.show_cards(_sample_cards(), "牌堆")
	await _wait_frames(20)
	_save_viewport("pile-overlay")
	if hud != null:
		hud.pile_overlay_controller.hide()
		hud.pile_overlay_controller.show_cards(_sample_cards(), "弃牌")
	await _wait_frames(20)
	_save_viewport("discard-overlay")
	get_tree().quit(0)


func _sample_cards() -> Array:
	var snapshot := PrototypeState.get_snapshot()
	var cards := _cards_from_snapshot(snapshot, "draw_pile_cards")
	if cards.is_empty():
		cards = _cards_from_snapshot(snapshot, "hand_cards")
	if cards.is_empty():
		cards = _cards_from_array(HUD_DEFAULTS.DEFAULT_CARDS)
	var source_size := cards.size()
	while source_size > 0 and cards.size() < 4:
		var source_index := cards.size() % source_size
		cards.append((cards[source_index] as Dictionary).duplicate(true))
	while cards.size() > 4:
		cards.remove_at(cards.size() - 1)
	return cards


func _cards_from_snapshot(snapshot: Dictionary, key: String) -> Array:
	var cards_variant: Variant = snapshot.get(key, [])
	if not (cards_variant is Array):
		return []
	return _cards_from_array(cards_variant as Array)


func _cards_from_array(source: Array) -> Array:
	var cards: Array = []
	for item in source:
		if item is Dictionary:
			cards.append((item as Dictionary).duplicate(true))
	return cards


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
