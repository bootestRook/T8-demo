extends GdUnitTestSuite


func test_project_name_is_configured() -> void:
	assert_str(ProjectSettings.get_setting("application/config/name")).is_equal("Godot V1 Plus")


func test_main_scene_is_configured() -> void:
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal("res://scenes/Game.tscn")


func test_common_game_modules_are_configured() -> void:
	assert_str(ProjectSettings.get_setting("autoload/GameEvents")).contains("src/game/GameEvents.gd")
	assert_str(ProjectSettings.get_setting("autoload/AchievementStore")).contains("src/game/AchievementStore.gd")
	assert_str(ProjectSettings.get_setting("autoload/FeedbackDirector")).contains("src/game/FeedbackDirector.gd")
	assert_str(ProjectSettings.get_setting("autoload/AudioDirector")).contains("src/game/AudioDirector.gd")
	assert_str(ProjectSettings.get_setting("autoload/AssetRegistry")).contains("src/game/AssetRegistry.gd")


func test_common_game_module_scripts_exist() -> void:
	assert_bool(FileAccess.file_exists("res://src/game/GameEvents.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://src/game/AchievementStore.gd")).is_true()


func test_starter_shell_has_no_content_units() -> void:
	assert_int(ContentUnits.count()).is_equal(0)
	assert_dict(ContentUnits.get_unit(0)).is_empty()


func test_starter_state_is_neutral() -> void:
	assert_str(PrototypeState.concept_id).is_equal("starter-template")
	assert_str(PrototypeState.status_text).contains("init")


func test_no_builtin_demo_assets_are_registered() -> void:
	assert_bool(AssetRegistry.ids(&"sprite").is_empty()).is_true()
	assert_bool(AssetRegistry.ids(&"ui").is_empty()).is_true()


func test_game_events_prunes_invalid_callbacks() -> void:
	var listener := Node.new()
	add_child(listener)
	GameEvents.subscribe(&"contract_test", Callable(listener, "queue_free"))
	assert_int(GameEvents._listeners.get(&"contract_test", []).size()).is_equal(1)
	listener.free()
	GameEvents.emit_event(&"contract_test")
	assert_bool(GameEvents._listeners.has(&"contract_test")).is_false()


func test_asset_registry_missing_resource_load_returns_null() -> void:
	AssetRegistry.register_sprite(&"missing_contract_asset", "res://assets/sprites/missing_contract_asset.png")
	assert_object(AssetRegistry.load_texture(&"sprite", &"missing_contract_asset")).is_null()
	AssetRegistry.sprites.erase(&"missing_contract_asset")
	AssetRegistry.clear_cache()
