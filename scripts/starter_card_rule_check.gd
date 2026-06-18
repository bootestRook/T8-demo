extends SceneTree

const STARTER_CARDS := [
	"starter_steady_aim",
	"starter_infinite_fire",
	"starter_first_aid",
	"starter_tactical_reload",
	"starter_weakpoint_mark",
	"starter_temporary_shield",
	"starter_rest_and_ready",
	"starter_flash_grenade",
	"starter_growth_plan",
]

var _failures: Array = []
var _case_count := 0
var _state: Variant = null


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_state = get_root().get_node_or_null("/root/PrototypeState")
	if _state == null:
		_failures.append("PrototypeState test node could not be created")
		_finish()
		return
	_test_initial_random_hand_cards()
	_test_formal_text_has_no_requirement_notes()
	_test_starter_effects()
	_test_chain_scaled_starter_effects()
	_test_chain_scaled_runtime_text()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("STARTER_CARD_RULE_CHECK PASS: %d cases" % _case_count)
		call_deferred(&"quit", 0)
		return
	for failure in _failures:
		print("STARTER_CARD_RULE_CHECK FAIL: %s" % failure)
	call_deferred(&"quit", 1)


func _test_initial_random_hand_cards() -> void:
	_state.reset()
	var snapshot: Dictionary = _state.get_snapshot()
	var hand_cards: Array = snapshot.get("hand_cards", []) as Array
	_expect_eq("auto refill target is 4", int(_state.hand_limit), 4)
	_expect_eq("initial hand draws 3 random starter cards", hand_cards.size(), 3)
	_expect_eq("initial draw pile is empty after initial hand refill", int(snapshot.get("draw_count", -1)), 0)
	_expect_eq("initial discard pile is empty", int(snapshot.get("discard_count", -1)), 0)
	for card in hand_cards:
		var card_id := String((card as Dictionary).get("id", ""))
		_expect_true("%s belongs to starter card pool" % card_id, STARTER_CARDS.has(card_id))


func _test_formal_text_has_no_requirement_notes() -> void:
	for card_id in STARTER_CARDS:
		var card: Dictionary = _state.get_card_config(card_id)
		_expect_true("%s exists" % card_id, not card.is_empty())
		var text := String(card.get("text", ""))
		_expect_true("%s text has no requirement parenthesis" % card_id, text.find("（") == -1 and text.find("）") == -1)


func _test_starter_effects() -> void:
	_state.reset()
	_play_single_card("starter_temporary_shield", 9)
	var shield_amount := int(float(_state.wall_hp_max) * 0.15 + 0.5)
	_expect_eq("temporary shield grants 15 percent wall hp", int(_state.wall_shield), shield_amount)
	var discard_snapshot: Dictionary = _state.get_snapshot()
	var discard_cards: Array = discard_snapshot.get("discard_pile_cards", []) as Array
	_expect_eq("discard pile snapshot includes played card", discard_cards.size(), 1)
	_expect_eq(
		"discard pile snapshot keeps played card id", String((discard_cards[0] as Dictionary).get("id", "")), "starter_temporary_shield"
	)
	_state.apply_wall_damage(100)
	_expect_eq("shield absorbs wall damage first", int(_state.hp), int(_state.wall_hp_max))
	_expect_eq("shield remainder after absorb", int(_state.wall_shield), shield_amount - 100)

	_state.reset()
	var before_damage_hp := int(_state.hp)
	_state.apply_wall_damage(500)
	_play_single_card("starter_first_aid", 9)
	_expect_eq("first aid restores 5 percent missing wall hp", int(_state.hp), before_damage_hp - 500 + 25)

	_state.reset()
	_state.ammo = 0
	_state.is_reloading = true
	_play_single_card("starter_tactical_reload", 9)
	_expect_eq("tactical reload adds 50 percent magazine", int(_state.ammo), 15)
	_expect_true("tactical reload cancels reload when ammo is available", not bool(_state.is_reloading))

	_state.reset()
	_play_single_card("starter_growth_plan", 9)
	_expect_eq("growth plan adds one stack", int(_state.starter_growth_plays), 1)
	_expect_close("growth plan raises base damage", float(_state.gun_runtime.get("base_damage_growth_mul", 1.0)), 1.02)
	for _index in range(3):
		_play_single_card("starter_growth_plan", 9)
	_expect_true("growth plan does not enter same-name cooldown", not _state.special_cooldown_until.has("成长计划"))
	_expect_true("growth plan can still be played after three quick plays", _play_single_card("starter_growth_plan", 9))

	_state.reset()
	_play_single_card("starter_rest_and_ready", 9)
	_expect_true(
		"rest and ready starts special cooldown", float(_state.special_cooldown_until.get("养精蓄锐", 0.0)) >= float(_state.elapsed_time) + 19.9
	)


func _test_chain_scaled_starter_effects() -> void:
	_state.reset()
	_state.card_chain.on_card_played(1)
	_play_single_card("starter_temporary_shield", 9)
	_expect_eq("temporary shield amount scales at x2", int(_state.wall_shield), int(float(_state.wall_hp_max) * 0.30 + 0.5))
	_expect_close("temporary shield duration stays fixed", float(_state.wall_shield_remaining), 3.0)

	_state.reset()
	var before_damage_hp := int(_state.hp)
	_state.apply_wall_damage(500)
	_state.card_chain.on_card_played(0)
	_play_single_card("starter_first_aid", 9)
	_expect_eq("first aid missing hp ratio scales at x2", int(_state.hp), before_damage_hp - 500 + 50)

	_state.reset()
	_state.ammo = 0
	_state.is_reloading = true
	_state.card_chain.on_card_played(2)
	_play_single_card("starter_tactical_reload", 9)
	_expect_eq("tactical reload scales but caps at magazine", int(_state.ammo), 30)

	_state.reset()
	_state.card_chain.on_wildcard_played()
	_play_single_card("starter_steady_aim", 9)
	_expect_close("steady aim damage bonus scales at x2", float(_state.gun_runtime.get("temp_damage_mul", 1.0)), 1.4)
	_expect_close("steady aim duration stays fixed", float(_state.gun_runtime.get("temp_damage_remaining", 0.0)), 3.0)

	_state.reset()
	_state.card_chain.on_wildcard_played()
	_play_single_card("starter_growth_plan", 9)
	_expect_close("growth plan per-play damage scales at x2", float(_state.gun_runtime.get("base_damage_growth_mul", 1.0)), 1.04)


func _test_chain_scaled_runtime_text() -> void:
	_state.reset()
	_state.hand_card_ids = ["starter_weakpoint_mark", "starter_temporary_shield", "starter_rest_and_ready"]
	_state.card_chain.on_card_played(0)
	var snapshot: Dictionary = _state.get_snapshot()
	var cards: Array = snapshot.get("hand_cards", []) as Array
	_expect_eq("runtime text test has three cards", cards.size(), 3)
	if cards.size() < 3:
		return
	var weakpoint := cards[0] as Dictionary
	_expect_true("weakpoint preview target count uses x2", String(weakpoint.get("desc", "")).contains("6个"))
	_expect_true("weakpoint preview damage taken uses x2", String(weakpoint.get("desc", "")).contains("100%"))
	_expect_true("weakpoint preview duration uses x2", String(weakpoint.get("desc", "")).contains("4秒"))
	_expect_true(
		"weakpoint rich text highlights values",
		String(weakpoint.get("desc_rich_text", "")).contains("[b][color=#a66f00][font_size={chain_font_size}]6个")
	)

	var shield := cards[1] as Dictionary
	_expect_true("shield amount preview uses x1 after broken chain", String(shield.get("desc", "")).contains("15%"))
	_expect_true("shield duration remains plain fixed text", String(shield.get("desc", "")).contains("持续3秒"))

	var rest := cards[2] as Dictionary
	_expect_true(
		"rest damage bonus highlights configured value",
		String(rest.get("desc_rich_text", "")).contains("[b][color=#a66f00][font_size={chain_font_size}]+50%")
	)
	_expect_true("rest fire interval remains fixed", String(rest.get("desc", "")).contains("-20%"))
	_expect_true("rest duration remains fixed", String(rest.get("desc", "")).contains("持续6秒"))


func _play_single_card(card_id: String, energy: int) -> bool:
	_state.play_card_lock_remaining = 0.0
	_state.hand_card_ids = [card_id]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	_state.current_energy = float(energy)
	return bool(_state.try_play_hand_card(0, "test"))


func _expect_true(label: String, value: bool) -> void:
	_case_count += 1
	if not value:
		_failures.append(label)


func _expect_eq(label: String, actual: Variant, expected: Variant) -> void:
	_case_count += 1
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _expect_close(label: String, actual: float, expected: float, epsilon: float = 0.001) -> void:
	_case_count += 1
	if absf(actual - expected) > epsilon:
		_failures.append("%s expected=%.3f actual=%.3f" % [label, expected, actual])
