extends GdUnitTestSuite


func test_medium_module_scripts_exist() -> void:
	var paths := [
		"res://src/game/modules/InputProfile.gd",
		"res://src/game/modules/PlayerController2D.gd",
		"res://src/game/modules/EnemyAI2D.gd",
		"res://src/game/modules/Spawner.gd",
		"res://src/game/modules/Pickup.gd",
		"res://src/game/modules/ItemCatalog.gd",
		"res://src/game/modules/InventoryStore.gd",
		"res://src/game/modules/EquipmentStore.gd",
		"res://src/game/modules/LootTable.gd",
		"res://src/game/modules/WaveDirector.gd",
		"res://src/game/modules/QuestStore.gd",
		"res://src/game/modules/DialogueRunner.gd",
		"res://src/game/modules/SaveStore.gd",
		"res://src/game/modules/MenuPresenter.gd",
		"res://src/game/modules/SceneRouter.gd",
		"res://src/game/modules/TutorialHints.gd",
	]
	for path in paths:
		assert_bool(FileAccess.file_exists(path)).is_true()


func test_inventory_store_stacks_and_serializes_items() -> void:
	var inventory = load("res://src/game/modules/InventoryStore.gd").new()
	inventory.setup(2)
	var remaining: int = inventory.add_item(&"potion", 3, 10)
	assert_int(remaining).is_equal(0)
	assert_int(inventory.count_item(&"potion")).is_equal(3)

	var data: Dictionary = inventory.serialize()
	var restored = load("res://src/game/modules/InventoryStore.gd").new()
	restored.deserialize(data)
	assert_int(restored.count_item(&"potion")).is_equal(3)
	inventory.free()
	restored.free()


func test_equipment_store_limits_slots_and_sums_stats() -> void:
	var equipment = load("res://src/game/modules/EquipmentStore.gd").new()
	equipment.setup([&"weapon", &"armor"])
	var item := {"id": &"iron_sword", "equip_slots": [&"weapon"], "stats": {"attack": 3.0}}
	var previous: Dictionary = equipment.equip(&"weapon", item)
	assert_dict(previous).is_empty()
	assert_float(float(equipment.bonus_totals().get("attack", 0.0))).is_equal(3.0)
	assert_dict(equipment.equip(&"armor", item)).is_empty()
	equipment.free()


func test_equipment_store_rejects_items_without_slots_by_default() -> void:
	var equipment = load("res://src/game/modules/EquipmentStore.gd").new()
	equipment.setup([&"weapon"])
	assert_dict(equipment.equip(&"weapon", {"id": &"coin"})).is_empty()
	assert_dict(equipment.equipment[&"weapon"]).is_empty()

	var any_slot_item := {"id": &"debug_charm", "allow_any_slot": true}
	equipment.equip(&"weapon", any_slot_item)
	assert_str(String(equipment.equipment[&"weapon"].get("id", ""))).is_equal("debug_charm")
	equipment.free()


func test_item_catalog_and_loot_table_form_basic_item_flow() -> void:
	var catalog = load("res://src/game/modules/ItemCatalog.gd").new()
	catalog.register_item(&"coin", "金币", &"currency", 99)
	assert_bool(catalog.has_item(&"coin")).is_true()
	assert_int(catalog.max_stack(&"coin")).is_equal(99)

	var table = load("res://src/game/modules/LootTable.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	table.add_entry(&"coin", 1.0, 2, 2)
	var result: Dictionary = table.roll(rng)
	assert_str(String(result.get("id", ""))).is_equal("coin")
	assert_int(int(result.get("quantity", 0))).is_equal(2)
	catalog.free()
	table.free()


func test_player_controller_registers_default_actions() -> void:
	for action_name in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
	var controller = load("res://src/game/modules/PlayerController2D.gd").new()
	controller._ready()
	assert_bool(InputMap.has_action(&"move_left")).is_true()
	assert_bool(InputMap.has_action(&"move_right")).is_true()
	controller.free()


func test_wave_director_waits_for_delayed_spawns_without_duration() -> void:
	var wave_director = load("res://src/game/modules/WaveDirector.gd").new()
	var waves: Array[Dictionary] = [{"spawns": [{"time": 1.0, "spawn_id": "late"}]}]
	wave_director.configure(waves)
	assert_bool(wave_director.start()).is_true()
	wave_director.tick(0.5)
	assert_bool(wave_director.running).is_true()
	wave_director.tick(0.5)
	assert_bool(wave_director.running).is_false()
	wave_director.free()


func test_quest_and_dialogue_progress_are_data_only() -> void:
	var quests = load("res://src/game/modules/QuestStore.gd").new()
	quests.register_quest(&"first", "第一步", {&"talk": 1})
	assert_bool(quests.start_quest(&"first")).is_true()
	assert_bool(quests.add_progress(&"first", &"talk", 1)).is_true()
	assert_bool(bool(quests.serialize()[&"first"].get("completed", false))).is_true()

	var dialogue = load("res://src/game/modules/DialogueRunner.gd").new()
	var lines: Array[Dictionary] = [{"speaker": "NPC", "text": "你好"}]
	dialogue.start(lines)
	assert_str(String(dialogue.current_line().get("speaker", ""))).is_equal("NPC")
	assert_dict(dialogue.next_line()).is_empty()
	quests.free()
	dialogue.free()


func test_tutorial_hints_trigger_once_by_default() -> void:
	var hints = load("res://src/game/modules/TutorialHints.gd").new()
	hints.register_hint(&"move", "移动")
	assert_bool(hints.trigger(&"move")).is_true()
	assert_bool(hints.trigger(&"move")).is_false()
	hints.free()


func test_save_store_round_trips_registered_provider_data() -> void:
	var inventory = load("res://src/game/modules/InventoryStore.gd").new()
	inventory.setup(2)
	inventory.add_item(&"potion", 2, 10)

	var restored = load("res://src/game/modules/InventoryStore.gd").new()
	restored.setup(2)

	var save_store = load("res://src/game/modules/SaveStore.gd").new()
	save_store.save_path = "user://module_contract_save.json"
	save_store.register_provider(&"inventory", inventory.serialize, restored.deserialize)
	assert_bool(save_store.save_game()).is_true()

	inventory.remove_item(&"potion", 2)
	var loaded: Dictionary = save_store.load_game()
	assert_bool(loaded.has("providers")).is_true()
	assert_int(restored.count_item(&"potion")).is_equal(2)
	inventory.free()
	restored.free()
	save_store.free()


func test_enemy_ai_clears_freed_target() -> void:
	var enemy = load("res://src/game/modules/EnemyAI2D.gd").new()
	var target := Node2D.new()
	add_child(enemy)
	add_child(target)
	enemy.set_target(target)
	target.free()
	assert_vector(enemy._chase()).is_equal(Vector2.ZERO)
	assert_object(enemy.target).is_null()
	enemy.free()
