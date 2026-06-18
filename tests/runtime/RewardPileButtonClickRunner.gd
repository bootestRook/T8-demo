extends Node

const MAIN_SCENE := "res://scenes/Game.tscn"


func _ready() -> void:
	var packed := load(MAIN_SCENE)
	if not packed is PackedScene:
		push_error("Failed to load scene: %s" % MAIN_SCENE)
		get_tree().quit(3)
		return
	var instance := (packed as PackedScene).instantiate()
	add_child(instance)
	call_deferred("_run_sequence", instance)


func _run_sequence(instance: Node) -> void:
	await _wait_frames(20)
	if instance.has_method("_on_main_menu_start_requested"):
		instance.call("_on_main_menu_start_requested", ContentUnits.DEFAULT_LEVEL_ID)
	await _wait_frames(20)
	var hud := instance.get_node_or_null("Hud") as Hud
	if hud == null:
		push_error("Hud not found.")
		get_tree().quit(4)
		return
	_prepare_reward_state(hud)
	await _wait_frames(8)
	if not hud.reward_overlay.is_visible():
		push_error("Reward overlay did not become visible.")
		get_tree().quit(5)
		return
	if not await _click_and_expect_pile(hud.draw_pile_button, hud, "draw pile"):
		return
	if not await _click_and_expect_pile_close(hud, "draw pile"):
		return
	await _wait_frames(4)
	if not await _click_and_expect_pile(hud.discard_pile_button, hud, "discard pile"):
		return
	if not await _click_and_expect_pile_close(hud, "discard pile"):
		return
	await _wait_frames(4)
	if not await _click_and_expect_reward_choice(hud):
		return
	get_tree().quit(0)


func _prepare_reward_state(hud: Hud) -> void:
	PrototypeState.hand_card_ids = ["starter_focus_fire", "starter_first_aid"]
	PrototypeState.draw_pile = ["starter_growth_plan", "starter_stable_aim"]
	PrototypeState.discard_pile = ["starter_emergency_reply"]
	PrototypeState.phase = PrototypeState.Phase.LEVEL_UP
	var upgrades := [
		{"id": "shot_electro_draw_supply", "kind": "new_card", "card_id": "electro_draw_supply", "weight": 1.0},
		{"id": "shot_dry_ice_draw_supply", "kind": "new_card", "card_id": "dry_ice_draw_supply", "weight": 1.0},
		{"id": "shot_general_draw_supply", "kind": "new_card", "card_id": "general_draw_supply", "weight": 1.0},
	]
	PrototypeState.level_rewards.begin_level_up(
		upgrades, PrototypeState.card_configs, PrototypeState.card_deck, PrototypeState.card_chain, PrototypeState.upgrade_rng, 3
	)
	hud.set_battle_snapshot(PrototypeState.get_snapshot())


func _click_and_expect_pile(button: Button, hud: Hud, label: String) -> bool:
	var rect := button.get_global_rect()
	var center := rect.position + rect.size * 0.5
	_push_click(center, true)
	_push_click(center, false)
	await _wait_frames(6)
	if not hud.pile_overlay_controller.is_visible():
		push_error(
			"Clicking %s did not open pile overlay. button_z=%d reward_visible=%s reward_z=%d button_disabled=%s button_visible=%s"
			% [
				label,
				button.z_index,
				str(hud.reward_overlay.is_visible()),
				hud.reward_overlay.overlay.z_index,
				str(button.disabled),
				str(button.visible),
			]
		)
		get_tree().quit(6)
		return false
	return true


func _click_and_expect_pile_close(hud: Hud, label: String) -> bool:
	var close_button := hud.pile_overlay_controller.pile_overlay.close_button
	if close_button == null:
		push_error("Pile overlay close button is missing.")
		get_tree().quit(10)
		return false
	var rect := close_button.get_global_rect()
	var center := rect.position + rect.size * 0.5
	_push_click(center, true)
	_push_click(center, false)
	await _wait_frames(6)
	if hud.pile_overlay_controller.is_visible():
		push_error("Clicking %s close button did not close pile overlay." % label)
		get_tree().quit(11)
		return false
	return true


func _click_and_expect_reward_choice(hud: Hud) -> bool:
	if hud.reward_overlay.button_box == null or hud.reward_overlay.button_box.get_child_count() <= 0:
		push_error("Reward choice buttons were not built.")
		get_tree().quit(7)
		return false
	var button := hud.reward_overlay.button_box.get_child(0) as Button
	if button == null:
		push_error("First reward choice is not a Button.")
		get_tree().quit(8)
		return false
	var rect := button.get_global_rect()
	var center := rect.position + rect.size * 0.5
	_push_click(center, true)
	_push_click(center, false)
	await _wait_frames(6)
	if not bool(hud.reward_overlay.get("_selection_locked")) or int(hud.reward_overlay.get("_selected_index")) != 0:
		push_error("Clicking reward choice did not select the first reward button.")
		get_tree().quit(9)
		return false
	return true


func _push_click(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
