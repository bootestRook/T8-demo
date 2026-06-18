extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenuScreen.tscn"
const UNLOCK_HINT := "通过当前关卡解锁"

var _failures: Array[String] = []
var _case_count := 0
var _started_levels: Array[String] = []
var _content_units: Variant = null
var _progress_store: Variant = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_content_units = get_node_or_null("/root/ContentUnits")
	_progress_store = get_node_or_null("/root/ProgressStore")
	if _content_units == null or _progress_store == null:
		_failures.append("ContentUnits or ProgressStore autoload is missing")
		_finish()
		return
	_content_units.load_combat_configs(_content_units.DEFAULT_LEVEL_ID)
	_progress_store.level_statuses.clear()
	_progress_store.completed_units.clear()
	var menu := _create_menu()
	if menu == null:
		_finish()
		return
	_test_first_level_can_start(menu)
	_test_next_arrow_blocks_when_current_level_is_uncleared(menu)
	_test_cleared_level_unlocks_next_and_blocks_following(menu)
	_test_second_clear_unlocks_third(menu)
	menu.queue_free()
	_finish()


func _create_menu() -> MainMenuScreen:
	var packed := load(MAIN_MENU_SCENE)
	if not packed is PackedScene:
		_failures.append("MainMenuScreen scene could not be loaded")
		return null
	var menu := (packed as PackedScene).instantiate() as MainMenuScreen
	if menu == null:
		_failures.append("MainMenuScreen scene could not be instantiated")
		return null
	add_child(menu)
	menu.start_requested.connect(func(level_id: String) -> void: _started_levels.append(level_id))
	return menu


func _test_first_level_can_start(menu: MainMenuScreen) -> void:
	_case_count += 1
	_started_levels.clear()
	menu.show_menu()
	_expect_eq("fresh progress selects first level", menu.get_selected_level_id(), "1")
	menu._on_start_pressed()
	_expect_eq("fresh first level starts", _started_levels.size(), 1)
	_expect_eq("fresh first level id", _started_levels[0], "1")


func _test_next_arrow_blocks_when_current_level_is_uncleared(menu: MainMenuScreen) -> void:
	_case_count += 1
	_started_levels.clear()
	menu.show_menu()
	menu._on_next_pressed()
	_expect_eq("fresh progress stays on first level when next is locked", menu.get_selected_level_id(), "1")
	_expect_eq("fresh next arrow keeps level status", menu.status_label.text, _progress_store.get_level_status_label("1"))
	_expect_eq("fresh next arrow shows floating unlock hint text", menu.get_unlock_hint_text(), UNLOCK_HINT)
	_expect_eq("fresh next arrow shows floating unlock hint", menu.is_unlock_hint_visible(), true)
	menu._on_start_pressed()
	_expect_eq("current unlocked first level still starts", _started_levels.size(), 1)
	_expect_eq("current unlocked first level id", _started_levels[0], "1")


func _test_cleared_level_unlocks_next_and_blocks_following(menu: MainMenuScreen) -> void:
	_case_count += 1
	_progress_store.level_statuses["1"] = "cleared"
	_started_levels.clear()
	menu.show_menu()
	menu._on_next_pressed()
	_expect_eq("clearing first level allows moving to level 2", menu.get_selected_level_id(), "2")
	menu._on_start_pressed()
	_expect_eq("unlocked next level starts", _started_levels.size(), 1)
	_expect_eq("unlocked next level id", _started_levels[0], "2")
	menu.show_menu()
	menu._on_next_pressed()
	_expect_eq("uncleared level 2 blocks level 3 navigation", menu.get_selected_level_id(), "2")
	_expect_eq("uncleared level 2 keeps level status", menu.status_label.text, _progress_store.get_level_status_label("2"))
	_expect_eq("uncleared level 2 floating hint text", menu.get_unlock_hint_text(), UNLOCK_HINT)
	_expect_eq("uncleared level 2 floating hint is visible", menu.is_unlock_hint_visible(), true)
	_started_levels.clear()


func _test_second_clear_unlocks_third(menu: MainMenuScreen) -> void:
	_case_count += 1
	_progress_store.level_statuses["2"] = "cleared"
	_started_levels.clear()
	menu.show_menu()
	menu._on_next_pressed()
	_expect_eq("clearing level 2 unlocks level 3 navigation", menu.get_selected_level_id(), "3")
	menu._on_start_pressed()
	_expect_eq("unlocked level 3 starts", _started_levels.size(), 1)
	_expect_eq("unlocked level 3 id", _started_levels[0], "3")


func _finish() -> void:
	if _failures.is_empty():
		print("MAIN_MENU_UNLOCK_RULE_CHECK PASS: %d cases" % _case_count)
		get_tree().quit(0)
		return
	for failure in _failures:
		print("MAIN_MENU_UNLOCK_RULE_CHECK FAIL: %s" % failure)
	get_tree().quit(1)


func _expect_eq(name: String, actual: Variant, expected: Variant) -> void:
	_case_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [name, str(expected), str(actual)])
