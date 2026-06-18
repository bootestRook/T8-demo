extends SceneTree

const UPGRADE_POOL_LOADER := preload("res://src/game/UpgradePoolLoader.gd")
const CARD_CHAIN_RULES := preload("res://src/game/CardChainRules.gd")
const UPGRADE_TEXT_CSV_PATH := "res://assets/data/upgrades/upgrade_texts.csv"
const PHASE_LEVEL_UP := 2
const BASE_REFILL_INTERVAL := 1.5

var _failures: Array = []
var _case_count := 0
var _card_count := 0
var _upgrade_count := 0
var _state: Variant = null


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_state = get_root().get_node_or_null("/root/PrototypeState")
	if _state == null:
		_failures.append("PrototypeState test node could not be created")
		_finish()
		return
	_state.reset()
	_test_upgrade_pool_entries()
	_test_new_card_reward_enters_draw_pile_at_auto_refill_target()
	_test_new_card_reward_enters_hand_below_auto_refill_target_without_refill_source()
	_test_new_card_reward_enters_draw_pile_below_target_with_draw_source()
	_test_new_card_reward_enters_draw_pile_below_target_with_discard_source()
	_test_card_reward_cost_owned_count_snapshot()
	_test_card_effects()
	_test_common_wildcard_copy()
	_test_school_wildcards_inherit_chain_effects()
	_test_snapshot_records_highest_chain()
	_test_thermobaric_explosion_waits_for_projectile_hit()
	_test_active_draw_can_exceed_auto_refill_target()
	_test_draw_effect_no_discard_shuffle()
	_test_gun_bullet_starts_at_player_muzzle()
	_test_core_skill_extra_targeting()
	_test_card_can_play_when_targets_are_outside_release_radius()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_UPGRADE_FULL_CHECK PASS: %d cases, %d upgrades, %d cards" % [_case_count, _upgrade_count, _card_count])
		call_deferred(&"quit", 0)
		return
	for failure in _failures:
		print("CARD_UPGRADE_FULL_CHECK FAIL: %s" % failure)
	call_deferred(&"quit", 1)


func _test_upgrade_pool_entries() -> void:
	var upgrades := UPGRADE_POOL_LOADER.load_pool(UPGRADE_TEXT_CSV_PATH)
	_expect_true("upgrade pool loaded from CSV", not upgrades.is_empty())
	for item in upgrades:
		if not (item is Dictionary):
			_failures.append("upgrade row is not Dictionary: %s" % str(item))
			continue
		var upgrade: Dictionary = item
		_upgrade_count += 1
		_test_single_upgrade(upgrade)


func _test_single_upgrade(upgrade: Dictionary) -> void:
	_state.reset()
	var before: Dictionary = _state.get_snapshot()
	var upgrade_id := String(upgrade.get("id", ""))
	var kind := String(upgrade.get("kind", ""))
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade.duplicate(true)]
	var selected: bool = _state.choose_level_reward(0)
	_expect_true("%s can be selected through choose_level_reward" % upgrade_id, selected)
	var after: Dictionary = _state.get_snapshot()
	match kind:
		"new_card":
			var card_id := String(upgrade.get("card_id", ""))
			_expect_true(
				"%s stores new card in hand or draw pile" % upgrade_id, _state.hand_card_ids.has(card_id) or _state.draw_pile.has(card_id)
			)
		"gun_upgrade":
			_expect_gun_upgrade_effect(upgrade, before, after)
		"survival":
			_expect_survival_upgrade_effect(upgrade, before, after)
		"energy":
			_expect_energy_upgrade_effect(upgrade, before, after)
		"core_skill":
			_expect_core_skill_upgrade_effect(upgrade, before, after)
		_:
			_failures.append("%s has untested kind %s" % [upgrade_id, kind])


func _test_new_card_reward_enters_draw_pile_at_auto_refill_target() -> void:
	_case_count += 1
	_state.reset()
	var upgrade := _first_new_card_upgrade()
	if upgrade.is_empty():
		_failures.append("new card reward test could not find a new_card upgrade")
		return
	var card_id := String(upgrade.get("card_id", ""))
	_state.hand_card_ids = ["starter_steady_aim", "starter_infinite_fire", "starter_first_aid", "starter_tactical_reload"]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade.duplicate(true)]
	var selected: bool = _state.choose_level_reward(0)
	_expect_true("new card reward at auto refill target can be selected", selected)
	_expect_eq("new card reward keeps full hand at auto refill target", _state.hand_card_ids.size(), 4)
	_expect_eq("new card reward does not enter full hand", _state.hand_card_ids.has(card_id), false)
	_expect_true("new card reward enters draw pile at auto refill target", _state.draw_pile.has(card_id))
	_expect_eq("new card reward does not enter discard pile", _state.discard_pile.has(card_id), false)
	_expect_eq("new card draw pile acquire event serial", int(_state.last_card_acquire_event.get("serial", 0)), 1)
	_expect_eq("new card draw pile acquire event destination", String(_state.last_card_acquire_event.get("destination", "")), "draw_pile")
	_expect_eq("new card draw pile acquire event draw index", int(_state.last_card_acquire_event.get("draw_index", -1)), 0)
	_expect_eq("new card draw pile acquire event card id", String(_state.last_card_acquire_event.get("card_id", "")), card_id)
	var draw_event_card: Dictionary = _state.last_card_acquire_event.get("card", {}) as Dictionary
	_expect_eq("new card draw pile acquire event card snapshot id", String(draw_event_card.get("id", "")), card_id)


func _test_new_card_reward_enters_hand_below_auto_refill_target_without_refill_source() -> void:
	_case_count += 1
	_state.reset()
	var upgrade := _first_new_card_upgrade()
	if upgrade.is_empty():
		_failures.append("new card below target test could not find a new_card upgrade")
		return
	var card_id := String(upgrade.get("card_id", ""))
	_state.hand_card_ids = ["starter_steady_aim", "starter_infinite_fire", "starter_first_aid"]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade.duplicate(true)]
	var selected: bool = _state.choose_level_reward(0)
	_expect_true("new card reward below auto refill target can be selected", selected)
	_expect_eq("new card reward fills open hand slot", _state.hand_card_ids.size(), 4)
	_expect_true("new card reward enters hand below target without refill source", _state.hand_card_ids.has(card_id))
	_expect_eq("new card reward below target does not enter draw pile", _state.draw_pile.has(card_id), false)
	_expect_eq("new card reward below target does not enter discard pile", _state.discard_pile.has(card_id), false)
	_expect_eq("new card hand acquire event serial", int(_state.last_card_acquire_event.get("serial", 0)), 1)
	_expect_eq("new card hand acquire event destination", String(_state.last_card_acquire_event.get("destination", "")), "hand")
	_expect_eq("new card hand acquire event hand index", int(_state.last_card_acquire_event.get("hand_index", -1)), 3)
	_expect_eq("new card hand acquire event card id", String(_state.last_card_acquire_event.get("card_id", "")), card_id)
	var hand_event_card: Dictionary = _state.last_card_acquire_event.get("card", {}) as Dictionary
	_expect_eq("new card hand acquire event card snapshot id", String(hand_event_card.get("id", "")), card_id)


func _test_new_card_reward_enters_draw_pile_below_target_with_draw_source() -> void:
	_case_count += 1
	_state.reset()
	var upgrade := _first_new_card_upgrade()
	if upgrade.is_empty():
		_failures.append("new card below target with draw source test could not find a new_card upgrade")
		return
	var card_id := String(upgrade.get("card_id", ""))
	_state.hand_card_ids = ["starter_steady_aim", "starter_infinite_fire", "starter_first_aid"]
	_state.draw_pile = ["starter_tactical_reload"]
	_state.discard_pile.clear()
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade.duplicate(true)]
	var selected: bool = _state.choose_level_reward(0)
	_expect_true("new card reward below target with draw source can be selected", selected)
	_expect_eq("new card reward leaves open hand slot for refill source", _state.hand_card_ids.size(), 3)
	_expect_eq("new card reward with draw source does not enter hand", _state.hand_card_ids.has(card_id), false)
	_expect_true("new card reward with draw source enters draw pile", _state.draw_pile.has(card_id))
	_expect_eq("new card reward with draw source draw pile size", _state.draw_pile.size(), 2)
	_expect_eq("new card reward with draw source stays after existing draw cards", String(_state.draw_pile[1]), card_id)
	_expect_eq("new card draw-source acquire event destination", String(_state.last_card_acquire_event.get("destination", "")), "draw_pile")
	_expect_eq("new card draw-source acquire event draw index", int(_state.last_card_acquire_event.get("draw_index", -1)), 1)
	_expect_eq("new card draw-source acquire event card id", String(_state.last_card_acquire_event.get("card_id", "")), card_id)


func _test_new_card_reward_enters_draw_pile_below_target_with_discard_source() -> void:
	_case_count += 1
	_state.reset()
	var upgrade := _first_new_card_upgrade()
	if upgrade.is_empty():
		_failures.append("new card below target with discard source test could not find a new_card upgrade")
		return
	var card_id := String(upgrade.get("card_id", ""))
	_state.hand_card_ids = ["starter_steady_aim", "starter_infinite_fire", "starter_first_aid"]
	_state.draw_pile.clear()
	_state.discard_pile = ["starter_tactical_reload"]
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade.duplicate(true)]
	var selected: bool = _state.choose_level_reward(0)
	_expect_true("new card reward below target with discard source can be selected", selected)
	_expect_eq("new card reward leaves open hand slot for discard refill source", _state.hand_card_ids.size(), 3)
	_expect_eq("new card reward with discard source does not enter hand", _state.hand_card_ids.has(card_id), false)
	_expect_true("new card reward with discard source enters draw pile", _state.draw_pile.has(card_id))
	_expect_true("new card reward keeps discard source available", _state.discard_pile.has("starter_tactical_reload"))
	_expect_eq(
		"new card discard-source acquire event destination", String(_state.last_card_acquire_event.get("destination", "")), "draw_pile"
	)
	_expect_eq("new card discard-source acquire event draw index", int(_state.last_card_acquire_event.get("draw_index", -1)), 0)
	_expect_eq("new card discard-source acquire event card id", String(_state.last_card_acquire_event.get("card_id", "")), card_id)


func _test_card_reward_cost_owned_count_snapshot() -> void:
	_case_count += 1
	_state.reset()
	_state.hand_card_ids = ["starter_first_aid"]
	_state.draw_pile = ["magnetic_pole_calibration"]
	_state.discard_pile = ["electro_explosion"]
	var upgrade := {
		"id": "check_electro_cost_count",
		"kind": "new_card",
		"card_id": "electro_draw_supply",
		"weight": 1.0,
	}
	_state.level_rewards.begin_level_up([upgrade], _state.card_configs, _state.card_deck, _state.card_chain, _state.upgrade_rng, 1)
	_expect_eq("card reward cost count choice count", _state.upgrade_choices.size(), 1)
	if _state.upgrade_choices.is_empty():
		return
	var choice: Dictionary = _state.upgrade_choices[0] as Dictionary
	_expect_eq("card reward cost", int(choice.get("cost", -1)), 1)
	_expect_eq("card reward cost owned count", int(choice.get("cost_owned_count", -1)), 3)
	_expect_eq("card reward cost owned count text", String(choice.get("cost_owned_count_text", "")), "X3")
	_expect_eq("card reward school owned count", int(choice.get("school_owned_count", -1)), 2)
	_expect_eq("card reward school owned count text", String(choice.get("school_owned_count_text", "")), "X2")


func _first_new_card_upgrade() -> Dictionary:
	var upgrades := UPGRADE_POOL_LOADER.load_pool(UPGRADE_TEXT_CSV_PATH)
	for item in upgrades:
		if item is Dictionary:
			var upgrade: Dictionary = item
			if String(upgrade.get("kind", "")) == "new_card":
				return upgrade.duplicate(true)
	return {}


func _expect_gun_upgrade_effect(upgrade: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var upgrade_id := String(upgrade.get("id", ""))
	var field := String(upgrade.get("field", ""))
	var before_runtime: Dictionary = before.get("gun_runtime", {}) as Dictionary
	var after_runtime: Dictionary = after.get("gun_runtime", {}) as Dictionary
	if upgrade.has("add"):
		_expect_gt("%s increases %s" % [upgrade_id, field], float(after_runtime.get(field, 0.0)), float(before_runtime.get(field, 0.0)))
	if upgrade.has("mul"):
		var mul := float(upgrade.get("mul", 1.0))
		if mul < 1.0:
			_expect_lt("%s lowers %s" % [upgrade_id, field], float(after_runtime.get(field, 0.0)), float(before_runtime.get(field, 0.0)))
		elif mul > 1.0:
			_expect_gt("%s raises %s" % [upgrade_id, field], float(after_runtime.get(field, 0.0)), float(before_runtime.get(field, 0.0)))
	if upgrade.has("damage_mul"):
		_expect_lt(
			"%s applies bullet damage multiplier" % upgrade_id,
			float(after_runtime.get("bullet_damage_mul", 0.0)),
			float(before_runtime.get("bullet_damage_mul", 0.0))
		)


func _expect_survival_upgrade_effect(upgrade: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var upgrade_id := String(upgrade.get("id", ""))
	var field := String(upgrade.get("field", ""))
	if field == "wall_hp_max":
		_expect_gt("%s raises wall max hp" % upgrade_id, float(after.get("wall_hp_max", 0.0)), float(before.get("wall_hp_max", 0.0)))
		_expect_gt("%s raises current hp with max hp" % upgrade_id, float(after.get("wall_hp", 0.0)), float(before.get("wall_hp", 0.0)))
	elif field == "wall_repair_ratio":
		_state.reset()
		_state.apply_wall_damage(300)
		var damaged_hp: int = _state.hp
		_state.phase = PHASE_LEVEL_UP
		_state.upgrade_choices = [upgrade.duplicate(true)]
		_state.choose_level_reward(0)
		_expect_gt("%s repairs damaged wall hp" % upgrade_id, float(_state.hp), float(damaged_hp))
	else:
		_failures.append("%s survival field untested: %s" % [upgrade_id, field])


func _expect_energy_upgrade_effect(upgrade: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var upgrade_id := String(upgrade.get("id", ""))
	var field := String(upgrade.get("field", ""))
	if field == "energy_regen_per_sec":
		_expect_gt(
			"%s raises energy regen" % upgrade_id,
			float(after.get("energy_regen_per_sec", 0.0)),
			float(before.get("energy_regen_per_sec", 0.0))
		)
	elif field == "refill_interval":
		_expect_lt("%s lowers refill interval" % upgrade_id, float(_state.refill_interval), BASE_REFILL_INTERVAL)
	else:
		_failures.append("%s energy field untested: %s" % [upgrade_id, field])


func _expect_core_skill_upgrade_effect(upgrade: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var upgrade_id := String(upgrade.get("id", ""))
	var core_skill := String(upgrade.get("core_skill", ""))
	var field := String(upgrade.get("field", ""))
	var before_core: Dictionary = before.get("core_skill_runtime", {}) as Dictionary
	var after_core: Dictionary = after.get("core_skill_runtime", {}) as Dictionary
	var before_skill: Dictionary = before_core.get(core_skill, {}) as Dictionary
	var after_skill: Dictionary = after_core.get(core_skill, {}) as Dictionary
	_expect_eq(
		"%s increments %s.%s" % [upgrade_id, core_skill, field],
		int(after_skill.get(field, 0)),
		int(before_skill.get(field, 0)) + int(upgrade.get("add", 0))
	)


func _test_card_effects() -> void:
	var card_ids := _card_ids_from_upgrade_pool()
	_expect_true("upgrade pool has card entries", not card_ids.is_empty())
	for card_id in card_ids:
		_card_count += 1
		_test_single_card(card_id)


func _card_ids_from_upgrade_pool() -> Array:
	var result: Array = []
	var upgrades := UPGRADE_POOL_LOADER.load_pool(UPGRADE_TEXT_CSV_PATH)
	for item in upgrades:
		if not (item is Dictionary):
			continue
		var upgrade: Dictionary = item
		if String(upgrade.get("kind", "")) != "new_card":
			continue
		var card_id := String(upgrade.get("card_id", ""))
		if not card_id.is_empty():
			result.append(card_id)
	return result


func _test_single_card(card_id: String) -> void:
	_state.reset()
	var card: Dictionary = _state.get_card_config(card_id)
	_expect_true("%s exists in runtime card config" % card_id, not card.is_empty())
	if card.is_empty():
		return
	if _is_wildcard_card(card):
		_test_single_wildcard_card(card_id, card)
		return
	if _is_draw_only_card(card):
		_test_single_draw_only_card(card_id, card)
		return
	var effect_spec := CARD_CHAIN_RULES.get_card_effect_spec(card_id)
	_expect_true("%s has CardChainRules effect spec" % card_id, not effect_spec.is_empty())
	_expect_true("%s has a core skill" % card_id, not String(card.get("core_skill", "")).is_empty())
	_seed_targets()
	_state.current_energy = 99.0
	_state.hand_card_ids = [card_id]
	_prepare_draw_pile_for_card(card)
	_state.discard_pile.clear()
	var played: bool = _state.try_play_hand_card(0, "full_check")
	_expect_true("%s can be played through PrototypeState" % card_id, played)
	_expect_true("%s moved to discard pile after play" % card_id, _state.discard_pile.has(card_id))
	var record := _latest_pending_effect_record()
	_expect_true("%s records pending effect log" % card_id, not record.is_empty())
	_expect_eq("%s record resolved" % card_id, bool(record.get("resolved", false)), true)
	_expect_command_spawn_matches_payload(card_id, record)
	_expect_payload_matches_effect_spec(card_id, card, record, effect_spec)
	_expect_draw_result(card_id, card, record)
	_expect_followup_routes(card_id, record)


func _test_single_draw_only_card(card_id: String, card: Dictionary) -> void:
	_state.combat_runtime.active_monsters.clear()
	_state.current_energy = 99.0
	_state.hand_card_ids = [card_id]
	_state.draw_pile = ["thermobaric_probe", "dry_ice_probe", "capacitor_test", "wildcard_link"]
	_state.discard_pile = ["thermobaric_pressure_calibration"]
	var played: bool = _state.try_play_hand_card(0, "full_check_draw_only")
	_expect_true("%s draw-only card can play without targets" % card_id, played)
	_expect_true("%s draw-only card moved to discard pile" % card_id, _state.discard_pile.has(card_id))
	var record := _latest_pending_effect_record()
	_expect_true("%s draw-only card records pending effect log" % card_id, not record.is_empty())
	_expect_eq("%s draw-only card has no core cast event" % card_id, bool(record.get("resolved", true)), false)
	_expect_eq("%s draw-only card emits no combat commands" % card_id, (record.get("commands", []) as Array).size(), 0)
	_expect_draw_result(card_id, card, record)


func _test_single_wildcard_card(card_id: String, card: Dictionary) -> void:
	if bool(card.get("copy_previous_card_effect", false)):
		return
	_seed_targets()
	_state.current_energy = 0.0
	_state.hand_card_ids = [card_id]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	var preview_chain_cost: int = _state.card_chain.get_chain_cost_for_card(card)
	var played: bool = _state.try_play_hand_card(0, "full_check_wildcard")
	_expect_true("%s wildcard can be played without energy" % card_id, played)
	_expect_true("%s wildcard moved to discard pile after play" % card_id, _state.discard_pile.has(card_id))
	var record := _latest_pending_effect_record()
	_expect_true("%s wildcard records pending effect log" % card_id, not record.is_empty())
	_expect_eq("%s wildcard records own effect card" % card_id, String(record.get("effect_card_id", "")), card_id)
	_expect_eq("%s wildcard record resolved" % card_id, bool(record.get("resolved", false)), true)
	_expect_true("%s wildcard emits combat commands" % card_id, not (record.get("commands", []) as Array).is_empty())
	_expect_eq("%s wildcard records bridge chain cost marker" % card_id, int(record.get("chain_cost", 0)), preview_chain_cost)
	_expect_eq("%s wildcard keeps normal chain cost empty" % card_id, int(_state.card_chain.last_chain_cost), -1)
	_expect_eq("%s wildcard opens bridge" % card_id, bool(_state.card_chain.wildcard_bridge_active), true)
	_expect_eq("%s wildcard costs zero energy" % card_id, int(record.get("energy_cost", -1)), 0)
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	_expect_eq("%s wildcard releases exactly one projectile" % card_id, int(payload.get("projectile_count", 0)), 1)


func _test_common_wildcard_copy() -> void:
	_state.reset()
	_seed_targets()
	var card_id := "wildcard_link"
	var card: Dictionary = _state.get_card_config(card_id)
	_expect_true("common wildcard exists in runtime card config", not card.is_empty())
	if card.is_empty():
		return
	_expect_true("common wildcard is copy wildcard", bool(card.get("copy_previous_card_effect", false)))
	_state.current_energy = 99.0
	_state.hand_card_ids = ["thermobaric_probe", card_id]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	var first_played: bool = _state.try_play_hand_card(0, "copy_seed")
	_expect_true("copy seed thermobaric card can be played", first_played)
	_state.play_card_lock_remaining = 0.0
	var preview_chain_cost: int = _state.card_chain.get_chain_cost_for_card(card)
	var copied_played: bool = _state.try_play_hand_card(0, "copy_wildcard")
	_expect_true("common wildcard can copy previous card", copied_played)
	var record := _latest_pending_effect_record()
	_expect_eq("common wildcard records own card id", String(record.get("card_id", "")), card_id)
	_expect_eq("common wildcard records copied card id", String(record.get("effect_card_id", "")), "thermobaric_probe")
	_expect_eq("common wildcard resolves copied core skill", String(record.get("core_skill", "")), "thermobaric")
	_expect_eq("common wildcard records bridge chain cost marker", int(record.get("chain_cost", 0)), preview_chain_cost)
	_expect_eq("common wildcard continues to x2 before resolving copy", int(record.get("chain_multiplier", 0)), 2)
	_expect_eq("common wildcard costs zero energy", int(record.get("energy_cost", -1)), 0)
	_expect_eq("common wildcard record resolved", bool(record.get("resolved", false)), true)
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	_expect_eq("common wildcard copy eats x2 projectile count", int(payload.get("projectile_count", 0)), 2)
	_expect_close("common wildcard copy inherits and copies at x2", float(payload.get("explosion_damage", 0.0)), 392.0)


func _test_school_wildcards_inherit_chain_effects() -> void:
	_expect_school_wildcard_inherits(
		"wildcard_thermobaric",
		["thermobaric_probe", "rich_fuel_fill", "thermal_explosion", "thermobaric_barrage"],
		"thermobaric",
		"explosion_damage"
	)
	_expect_school_wildcard_inherits(
		"wildcard_dry_ice", ["dry_ice_probe", "condensation_calibration", "low_temperature_pierce", "dry_ice_barrage"], "dry_ice", "damage"
	)
	_expect_school_wildcard_inherits(
		"wildcard_electro_pierce",
		["capacitor_test", "magnetic_pole_calibration", "electro_explosion_damage", "electro_matrix"],
		"electro_pierce",
		"pierce_damage"
	)


func _expect_school_wildcard_inherits(wildcard_id: String, setup_cards: Array, expected_core_skill: String, damage_field: String) -> void:
	_state.reset()
	_seed_targets()
	_state.fire_timer = 9999.0
	_state.current_energy = 99.0
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	for card_id in setup_cards:
		_state.hand_card_ids = [String(card_id)]
		var played: bool = _state.try_play_hand_card(0, "school_wildcard_setup")
		_expect_true("%s setup card %s can play" % [wildcard_id, String(card_id)], played)
		_state.play_card_lock_remaining = 0.0
	var wildcard: Dictionary = _state.get_card_config(wildcard_id)
	var preview_chain_cost: int = _state.card_chain.get_chain_cost_for_card(wildcard)
	_state.current_energy = 0.0
	_state.hand_card_ids = [wildcard_id]
	var wildcard_played: bool = _state.try_play_hand_card(0, "school_wildcard_inherit")
	_expect_true("%s can play without energy after setup chain" % wildcard_id, wildcard_played)
	var record := _latest_pending_effect_record()
	_expect_eq("%s resolves own core skill" % wildcard_id, String(record.get("core_skill", "")), expected_core_skill)
	_expect_eq("%s records bridge chain cost marker" % wildcard_id, int(record.get("chain_cost", 0)), preview_chain_cost)
	_expect_eq("%s reaches x5 chain" % wildcard_id, int(record.get("chain_multiplier", 0)), 5)
	_expect_eq("%s costs zero energy" % wildcard_id, int(record.get("energy_cost", -1)), 0)
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	_expect_gt("%s keeps inherited projectile count" % wildcard_id, float(payload.get("projectile_count", 0)), 1.0)
	_expect_gt("%s keeps inherited damage payload" % wildcard_id, float(payload.get(damage_field, 0.0)), 100.0)


func _test_snapshot_records_highest_chain() -> void:
	_state.reset()
	_state.card_chain.on_card_played(0)
	_state.card_chain.on_card_played(1)
	var snapshot: Dictionary = _state.get_snapshot()
	_expect_eq("snapshot records highest chain x2", int(snapshot.get("highest_chain_multiplier", -1)), 2)
	_state.card_chain.break_chain()
	snapshot = _state.get_snapshot()
	_expect_eq("snapshot keeps highest chain after break", int(snapshot.get("highest_chain_multiplier", -1)), 2)
	_state.reset()
	snapshot = _state.get_snapshot()
	_expect_eq("snapshot clears highest chain on new battle", int(snapshot.get("highest_chain_multiplier", -1)), 0)


func _test_thermobaric_explosion_waits_for_projectile_hit() -> void:
	_state.reset()
	_seed_targets()
	_place_targets_for_thermobaric_timing()
	_state.fire_timer = 9999.0
	_state.current_energy = 99.0
	_state.hand_card_ids = ["thermal_burst"]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	var played: bool = _state.try_play_hand_card(0, "explosion_timing")
	_expect_true("thermal burst can play for explosion timing", played)
	_expect_eq("thermal burst does not create explosion before tick", _count_combat_effect_kind("explosion"), 0)
	_expect_eq("thermal burst does not create explosion area before tick", _count_combat_effect_kind("explosion_area"), 0)
	_state.tick(0.05)
	_expect_eq("thermal burst does not explode before projectile reaches target", _count_combat_effect_kind("explosion"), 0)
	_expect_eq("thermal burst has no explosion area before projectile reaches target", _count_combat_effect_kind("explosion_area"), 0)
	_state.tick(0.1)
	_expect_gt("thermal burst creates explosion damage after projectile hit", float(_count_combat_effect_kind("explosion")), 0.0)
	_expect_gt("thermal burst creates one hit-centered explosion area after hit", float(_count_combat_effect_kind("explosion_area")), 0.0)


func _place_targets_for_thermobaric_timing() -> void:
	for index in range(_state.combat_runtime.active_monsters.size()):
		var monster: Dictionary = _state.combat_runtime.active_monsters[index]
		monster["position"] = Vector2(549.0 + float(index) * 42.0, 1120.0)
		_state.combat_runtime.active_monsters[index] = monster


func _place_targets_for_delayed_projectile_count() -> void:
	for index in range(_state.combat_runtime.active_monsters.size()):
		var monster: Dictionary = _state.combat_runtime.active_monsters[index]
		monster["position"] = Vector2(420.0 + float(index) * 70.0, 620.0 + float(index % 2) * 45.0)
		_state.combat_runtime.active_monsters[index] = monster


func _count_combat_effect_kind(kind: String) -> int:
	var count := 0
	for item in _state.combat_runtime.combat_effects:
		if item is Dictionary and String((item as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _is_wildcard_card(card: Dictionary) -> bool:
	return bool(card.get("chain_wildcard", false)) or String(card.get("chain_cost_mode", "")) == "wildcard"


func _is_draw_only_card(card: Dictionary) -> bool:
	return int(card.get("draw_count", 0)) > 0 and String(card.get("core_skill", "")).is_empty()


func _prepare_draw_pile_for_card(card: Dictionary) -> void:
	_state.draw_pile.clear()
	var draw_school := String(card.get("draw_school", ""))
	if draw_school == "温压弹":
		_state.draw_pile = ["dry_ice_probe", "thermobaric_probe", "thermobaric_pressure_calibration", "capacitor_test"]
	elif draw_school == "干冰弹":
		_state.draw_pile = ["thermobaric_probe", "dry_ice_probe", "condensation_calibration", "capacitor_test"]
	elif draw_school == "电磁穿刺":
		_state.draw_pile = ["thermobaric_probe", "capacitor_test", "magnetic_pole_calibration", "dry_ice_probe"]


func _seed_targets() -> void:
	_state.combat_runtime.active_monsters.clear()
	for index in range(5):
		(
			_state
			. combat_runtime
			. active_monsters
			. append(
				{
					"id": "target_%d" % index,
					"monster_id": "grunt",
					"name": "测试怪%d" % index,
					"type": "normal",
					"hp": 9999.0,
					"hp_max": 9999.0,
					"position": Vector2(420.0 + float(index) * 70.0, 930.0 + float(index % 2) * 45.0),
					"speed": 0.0,
					"damage": 0,
					"attack_interval": 99.0,
					"attack_timer": 99.0,
					"exp": 0,
					"radius": 24.0,
					"statuses": {},
				}
			)
		)


func _test_gun_bullet_starts_at_player_muzzle() -> void:
	_state.reset()
	_seed_targets()
	_state.fire_timer = 0.0
	_state.tick(0.01)
	var bullet := {}
	for item in _state.get_snapshot().get("active_projectiles", []) as Array:
		if item is Dictionary and String((item as Dictionary).get("projectile_id", "")) == "gun_bullet":
			bullet = item as Dictionary
			break
	_expect_true("gun bullet spawned for muzzle origin check", not bullet.is_empty())
	var position: Vector2 = bullet.get("position", Vector2.ZERO)
	_expect_close("gun bullet muzzle origin x", position.x, 549.0)
	_expect_close("gun bullet muzzle origin y", position.y, 1235.0)


func _latest_pending_effect_record() -> Dictionary:
	if _state.pending_effect_log.is_empty():
		return {}
	var item: Variant = _state.pending_effect_log[_state.pending_effect_log.size() - 1]
	if item is Dictionary:
		return item as Dictionary
	return {}


func _expect_command_spawn_matches_payload(card_id: String, record: Dictionary) -> void:
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	var commands: Array = record.get("commands", []) as Array
	_expect_true("%s has route commands" % card_id, not commands.is_empty())
	var spawn_commands := _commands_of_type(commands, "spawn_projectile")
	_expect_true("%s has spawn projectile commands" % card_id, not spawn_commands.is_empty())
	var first_spawn: Dictionary = spawn_commands[0] as Dictionary
	_expect_eq(
		"%s spawn count matches projectile_count" % card_id, int(first_spawn.get("count", 0)), int(payload.get("projectile_count", 0))
	)
	_expect_eq("%s payload card_id is retained" % card_id, String(payload.get("card_id", "")), card_id)


func _expect_payload_matches_effect_spec(card_id: String, card: Dictionary, record: Dictionary, effect_spec: Dictionary) -> void:
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var actual: Dictionary = trigger_event.get("payload", {}) as Dictionary
	var core_skill := String(card.get("core_skill", ""))
	var expected := _default_payload_for_core_skill(core_skill)
	CARD_CHAIN_RULES.apply_effect_spec(expected, effect_spec, 1)
	_finalize_expected_payload(core_skill, expected)
	_compare_effect_fields(card_id, expected, actual, effect_spec)


func _expect_draw_result(card_id: String, card: Dictionary, record: Dictionary) -> void:
	var expected_count := int(card.get("draw_count", 0))
	if expected_count <= 0:
		_expect_true("%s has no draw result" % card_id, not record.has("draw_result"))
		return
	var draw_result: Dictionary = record.get("draw_result", {}) as Dictionary
	_expect_true("%s records draw result" % card_id, not draw_result.is_empty())
	_expect_eq("%s requested draw count" % card_id, int(draw_result.get("requested_count", 0)), expected_count)
	_expect_eq("%s draw school recorded" % card_id, String(draw_result.get("school", "")), String(card.get("draw_school", "")))
	var drawn_card_ids: Array = draw_result.get("drawn_card_ids", []) as Array
	_expect_eq("%s draws expected available cards" % card_id, drawn_card_ids.size(), expected_count)
	var draw_school := String(card.get("draw_school", ""))
	if draw_school.is_empty():
		return
	for drawn_id in drawn_card_ids:
		var drawn_card: Dictionary = _state.get_card_config(String(drawn_id))
		_expect_eq("%s draws matching school %s" % [card_id, String(drawn_id)], String(drawn_card.get("school", "")), draw_school)


func _compare_effect_fields(card_id: String, expected: Dictionary, actual: Dictionary, effect_spec: Dictionary) -> void:
	var checked_any := false
	var sets: Dictionary = effect_spec.get("set", {}) as Dictionary
	for key in sets.keys():
		checked_any = true
		_expect_eq("%s set %s" % [card_id, String(key)], actual.get(key, null), expected.get(key, null))
	var muls: Dictionary = effect_spec.get("mul", {}) as Dictionary
	for key in muls.keys():
		checked_any = true
		_expect_close("%s mul %s" % [card_id, String(key)], float(actual.get(key, 0.0)), float(expected.get(key, 0.0)))
	var adds: Dictionary = effect_spec.get("add", {}) as Dictionary
	for key in adds.keys():
		checked_any = true
		if actual.get(key, 0) is int or expected.get(key, 0) is int:
			_expect_eq("%s add %s" % [card_id, String(key)], int(actual.get(key, 0)), int(expected.get(key, 0)))
		else:
			_expect_close("%s add %s" % [card_id, String(key)], float(actual.get(key, 0.0)), float(expected.get(key, 0.0)))
	_expect_true("%s checked at least one effect field" % card_id, checked_any)


func _default_payload_for_core_skill(core_skill: String) -> Dictionary:
	match core_skill:
		"thermobaric":
			return ThermobaricSkill.default_payload()
		"dry_ice":
			return DryIceSkill.default_payload()
		"electro_pierce":
			return ElectroPierceSkill.default_payload()
	return {}


func _finalize_expected_payload(core_skill: String, payload: Dictionary) -> void:
	match core_skill:
		"thermobaric":
			payload["spark_damage"] = float(payload.get("explosion_damage", 100.0)) * 0.35
		"dry_ice":
			payload["small_ice_damage"] = float(payload.get("damage", 90.0)) * 0.5
			if bool(payload.get("frostbite_enabled", false)):
				payload["frostbite_tick_damage"] = float(payload.get("damage", 90.0)) * 0.03 * 0.5
		"electro_pierce":
			payload["particle_damage"] = float(payload.get("pierce_damage", 100.0)) * 0.35


func _expect_followup_routes(card_id: String, record: Dictionary) -> void:
	var trigger_event: Dictionary = record.get("trigger_event", {}) as Dictionary
	var payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	match card_id:
		"thermal_ignite":
			_expect_child_command(card_id, ThermobaricEvents.HIT, payload, "apply_status", "burn")
		"explosion_sparks":
			payload["hit_position"] = Vector2(520.0, 900.0)
			_expect_child_command(card_id, ThermobaricEvents.EXPLOSION_END, payload, "spawn_projectile", "thermobaric_spark")
		"scatter_small_ice":
			payload["is_first_hit"] = true
			payload["hit_position"] = Vector2(520.0, 900.0)
			_expect_child_command(card_id, DryIceEvents.FIRST_HIT, payload, "spawn_projectile", "small_ice")
		"flash_freeze_ice":
			_expect_child_command(card_id, DryIceEvents.HIT, payload, "apply_status", "freeze")
		"frostbite_invasion":
			_expect_child_command(card_id, DryIceEvents.HIT, payload, "apply_status", "frostbite")
		"electro_explosion", "electro_explosion_damage", "electro_explosion_expand":
			_expect_child_command(card_id, ElectroPierceEvents.HIT, payload, "emit_event", String(ElectroPierceEvents.EXPLOSION))
		"electro_matrix":
			payload["hit_position"] = Vector2(520.0, 900.0)
			_expect_child_command(card_id, ElectroPierceEvents.EXPLOSION_END, payload, "spawn_area", "electro_matrix")
		"electro_fission":
			payload["hit_position"] = Vector2(520.0, 900.0)
			_expect_child_command(card_id, ElectroPierceEvents.HIT, payload, "spawn_projectile", "electro_particle")


func _expect_child_command(card_id: String, event_id: StringName, payload: Dictionary, command_type: String, marker: String) -> void:
	var event := CombatEvent.create(CombatEvent.TYPE_HIT, event_id, &"test", &"player", payload.duplicate(true))
	if event_id == ThermobaricEvents.EXPLOSION_END or event_id == DryIceEvents.FIRST_HIT or event_id == ElectroPierceEvents.EXPLOSION_END:
		event.event_type = CombatEvent.TYPE_RESOLVED
	var commands: Array = _state.combat_runtime.route_event(event, _state.combat_router)
	var found := false
	for item in commands:
		if not (item is Dictionary):
			continue
		var command: Dictionary = item
		if String(command.get("command", "")) != command_type:
			continue
		if _command_has_marker(command, marker):
			found = true
			break
	_expect_true("%s follow-up route emits %s/%s" % [card_id, command_type, marker], found)


func _command_has_marker(command: Dictionary, marker: String) -> bool:
	for key in ["status_id", "projectile_id", "area_id", "next_event_id"]:
		if String(command.get(key, "")) == marker:
			return true
	return false


func _commands_of_type(commands: Array, command_type: String) -> Array:
	var result: Array = []
	for item in commands:
		if item is Dictionary and String((item as Dictionary).get("command", "")) == command_type:
			result.append(item)
	return result


func _test_active_draw_can_exceed_auto_refill_target() -> void:
	_state.reset()
	_seed_targets()
	var card_id := "thermobaric_draw_supply"
	var card: Dictionary = _state.get_card_config(card_id)
	_expect_true("active draw card exists", not card.is_empty())
	if card.is_empty():
		return
	_state.current_energy = 99.0
	_state.hand_card_ids = [card_id, "starter_steady_aim", "starter_first_aid", "starter_tactical_reload"]
	_state.draw_pile = ["thermobaric_probe", "thermobaric_pressure_calibration"]
	_state.discard_pile.clear()
	var played: bool = _state.try_play_hand_card(0, "draw_exceeds_auto_target")
	_expect_true("active draw card can play at auto refill target", played)
	var record := _latest_pending_effect_record()
	var draw_result: Dictionary = record.get("draw_result", {}) as Dictionary
	var drawn_card_ids: Array = draw_result.get("drawn_card_ids", []) as Array
	_expect_eq("active draw pulls requested cards from deck", drawn_card_ids.size(), 2)
	_expect_eq("active draw can exceed auto refill target", _state.hand_card_ids.size(), 5)
	_expect_true("active draw keeps first drawn card in hand", _state.hand_card_ids.has("thermobaric_probe"))
	_expect_true("active draw keeps second drawn card in hand", _state.hand_card_ids.has("thermobaric_pressure_calibration"))


func _test_draw_effect_no_discard_shuffle() -> void:
	_state.reset()
	_seed_targets()
	var card_id := "thermobaric_draw_supply"
	var card: Dictionary = _state.get_card_config(card_id)
	_expect_true("draw no-shuffle card exists", not card.is_empty())
	if card.is_empty():
		return
	_state.current_energy = 99.0
	_state.hand_card_ids = [card_id]
	_state.draw_pile = ["dry_ice_probe", "thermobaric_probe"]
	_state.discard_pile = ["thermobaric_pressure_calibration"]
	var played: bool = _state.try_play_hand_card(0, "draw_no_shuffle")
	_expect_true("draw effect can play for no-shuffle check", played)
	var record := _latest_pending_effect_record()
	var draw_result: Dictionary = record.get("draw_result", {}) as Dictionary
	var drawn_card_ids: Array = draw_result.get("drawn_card_ids", []) as Array
	_expect_eq("draw effect does not shuffle discard into deck", drawn_card_ids.size(), 1)
	_expect_eq("draw effect keeps discard candidate in discard pile", _state.discard_pile.has("thermobaric_pressure_calibration"), true)


func _test_core_skill_extra_targeting() -> void:
	_state.reset()
	_seed_targets()
	_place_targets_for_delayed_projectile_count()
	var upgrade := {
		"id": "check_core_thermobaric_count",
		"kind": "core_skill",
		"core_skill": "thermobaric",
		"field": "projectile_count",
		"add": 2,
	}
	_state.phase = PHASE_LEVEL_UP
	_state.upgrade_choices = [upgrade]
	_state.choose_level_reward(0)
	_state.fire_timer = 9999.0
	_state.current_energy = 99.0
	_state.hand_card_ids = ["thermobaric_probe"]
	var played: bool = _state.try_play_hand_card(0, "extra_targeting")
	_expect_true("core count upgraded card can play", played)
	var record := _latest_pending_effect_record()
	var commands: Array = record.get("commands", []) as Array
	var spawn_commands := _commands_of_type(commands, "spawn_projectile")
	_expect_eq("core count creates 3 spawn commands", spawn_commands.size(), 3)
	_expect_true(
		"extra projectiles are delayed after first command",
		bool((spawn_commands[1] as Dictionary).get("queued", false)) and bool((spawn_commands[2] as Dictionary).get("queued", false))
	)
	_state.tick(0.5)
	var snapshot: Dictionary = _state.get_snapshot()
	var thermobaric_count := 0
	for item in snapshot.get("active_projectiles", []) as Array:
		if item is Dictionary and String((item as Dictionary).get("projectile_id", "")) == "thermobaric":
			thermobaric_count += 1
	_expect_eq("delayed extra projectiles spawn into runtime", thermobaric_count, 3)


func _test_card_can_play_when_targets_are_outside_release_radius() -> void:
	_state.reset()
	_state.combat_runtime.active_monsters.clear()
	(
		_state
		. combat_runtime
		. active_monsters
		. append(
			{
				"id": "far_target",
				"monster_id": "grunt",
				"name": "Far Target",
				"type": "normal",
				"hp": 9999.0,
				"hp_max": 9999.0,
				"position": Vector2(100000.0, 100000.0),
				"speed": 0.0,
				"damage": 0,
				"attack_interval": 99.0,
				"attack_timer": 99.0,
				"exp": 0,
				"radius": 24.0,
				"statuses": {},
			}
		)
	)
	_expect_eq("far target is outside old cast range", _state.combat_runtime.has_target_in_cast_range(1100.0), false)
	_state.fire_timer = 9999.0
	_state.current_energy = 99.0
	_state.hand_card_ids = ["thermobaric_probe"]
	_state.draw_pile.clear()
	_state.discard_pile.clear()
	var played: bool = _state.try_play_hand_card(0, "far_target_no_cast_range_limit")
	_expect_true("card can play when target is outside old cast range", played)
	_expect_eq("far target play has no failure reason", String(_state.last_card_play_failure), "")


func _expect_true(name: String, actual: bool) -> void:
	_case_count += 1
	if not actual:
		_failures.append("%s: expected true" % name)


func _expect_eq(name: String, actual: Variant, expected: Variant) -> void:
	_case_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [name, str(expected), str(actual)])


func _expect_close(name: String, actual: float, expected: float) -> void:
	_case_count += 1
	if absf(actual - expected) > 0.001:
		_failures.append("%s: expected %.3f, got %.3f" % [name, expected, actual])


func _expect_gt(name: String, actual: float, baseline: float) -> void:
	_case_count += 1
	if actual <= baseline:
		_failures.append("%s: expected > %.3f, got %.3f" % [name, baseline, actual])


func _expect_lt(name: String, actual: float, baseline: float) -> void:
	_case_count += 1
	if actual >= baseline:
		_failures.append("%s: expected < %.3f, got %.3f" % [name, baseline, actual])
