extends SceneTree

const CARD_CHAIN_STATE := preload("res://src/game/CardChainState.gd")

var _failures: Array = []
var _case_count := 0


func _init() -> void:
	_test_chain_progression()
	_test_highest_chain_tracking()
	_test_wildcard_chain_progression()
	_test_same_school_inheritance()
	_test_cross_school_isolation()
	_test_negative_values_do_not_scale()
	_test_positive_adds_scale()
	_test_reset_clears_inherited_effects()
	_test_break_clears_inherited_effects()
	_test_electro_calibration_effects()
	if _failures.is_empty():
		print("CARD_CHAIN_CHECK PASS: %d cases" % _case_count)
		call_deferred(&"quit", 0)
		return
	for failure in _failures:
		print("CARD_CHAIN_CHECK FAIL: %s" % failure)
	call_deferred(&"quit", 1)


func _test_chain_progression() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	_expect_eq("1 cost card can continue after 0", chain.can_continue_chain(_cost_card(1)), true)
	_expect_eq("2 cost card cannot continue after 0", chain.can_continue_chain(_cost_card(2)), false)
	_expect_eq("0 cost can start chain at x1", chain.chain_multiplier, 1)
	_expect_eq("0 cost start stores last cost", chain.last_chain_cost, 0)
	chain.on_card_played(1)
	_expect_eq("0 -> 1 continues to x2", chain.chain_multiplier, 2)
	chain.on_card_played(2)
	_expect_eq("0 -> 1 -> 2 continues to x3", chain.chain_multiplier, 3)
	chain.on_card_played(4)
	_expect_eq("jump cost resets to x1", chain.chain_multiplier, 1)
	_expect_eq("jump cost stores new cost", chain.last_chain_cost, 4)
	chain.on_card_played(4)
	_expect_eq("same cost resets and stays x1", chain.chain_multiplier, 1)
	chain.on_card_played(5)
	_expect_eq("same reset can continue from new cost", chain.chain_multiplier, 2)
	chain.break_chain()
	_expect_eq("break resets multiplier", chain.chain_multiplier, 1)
	_expect_eq("break clears last cost", chain.last_chain_cost, -1)
	chain.on_card_played(3)
	_expect_eq("any cost can restart at x1", chain.chain_multiplier, 1)
	chain.on_card_played(4)
	_expect_eq("3 -> 4 continues to x2", chain.chain_multiplier, 2)


func _test_highest_chain_tracking() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	_expect_eq("new battle starts with no highest chain", chain.highest_chain_multiplier, 0)
	chain.on_card_played(0)
	chain.on_card_played(1)
	chain.on_card_played(2)
	_expect_eq("highest chain records x3", chain.highest_chain_multiplier, 3)
	chain.break_chain()
	_expect_eq("break clears active multiplier", chain.chain_multiplier, 1)
	_expect_eq("break keeps battle highest chain", chain.highest_chain_multiplier, 3)
	chain.on_card_played(4)
	_expect_eq("new shorter chain does not lower highest", chain.highest_chain_multiplier, 3)
	chain.on_card_played(5)
	chain.on_card_played(6)
	chain.on_card_played(7)
	_expect_eq("later longer chain raises highest", chain.highest_chain_multiplier, 4)
	chain.reset()
	_expect_eq("new battle clears highest chain", chain.highest_chain_multiplier, 0)


func _test_wildcard_chain_progression() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	var wildcard := _wildcard_card("wildcard_link")
	_expect_eq("wildcard has no numeric chain cost", chain.get_chain_cost_for_card(wildcard), -1)
	_expect_eq("wildcard actual energy cost stays 0", chain.get_energy_cost_for_card(wildcard), 0)
	chain.on_card_played_for_card(wildcard)
	_expect_eq("wildcard first starts at x1", chain.chain_multiplier, 1)
	_expect_eq("wildcard first keeps last normal cost empty", chain.last_chain_cost, -1)
	_expect_eq("wildcard opens bridge", chain.wildcard_bridge_active, true)
	chain.on_card_played(3)
	_expect_eq("wildcard bridges into any first normal cost", chain.chain_multiplier, 2)
	_expect_eq("bridged normal cost becomes new baseline", chain.last_chain_cost, 3)
	chain.on_card_played_for_card(wildcard)
	_expect_eq("wildcard after normal keeps chain", chain.chain_multiplier, 3)
	_expect_eq("wildcard after normal keeps previous baseline", chain.last_chain_cost, 3)
	chain.on_card_played(3)
	_expect_eq("wildcard bridges into repeated cost", chain.chain_multiplier, 4)

	chain.reset()
	chain.on_card_played(0)
	chain.on_card_played(1)
	chain.on_card_played_for_card(wildcard)
	chain.on_card_played(0)
	chain.on_card_played_for_card(wildcard)
	chain.on_card_played(3)
	chain.on_card_played(4)
	chain.on_card_played_for_card(wildcard)
	chain.on_card_played(4)
	_expect_eq("0 -> 1 -> wildcard -> 0 -> wildcard -> 3 -> 4 -> wildcard -> 4 reaches x9", chain.chain_multiplier, 9)

	chain.reset()
	chain.on_card_played(0)
	chain.on_card_played_for_card(wildcard)
	chain.on_card_played_for_card(wildcard)
	chain.on_card_played(3)
	_expect_eq("0 -> wildcard -> wildcard -> 3 reaches x4", chain.chain_multiplier, 4)


func _test_same_school_inheritance() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.record_card_effect(_card("thermobaric_probe", "thermobaric"))
	chain.on_card_played(1)
	var payload := _thermobaric_payload()
	chain.apply_base_multiplier("thermobaric", payload)
	chain.apply_inherited_effects("thermobaric", payload)
	chain.apply_card_effect(_card("rich_fuel_fill", "thermobaric"), payload)
	_expect_close("same school inherited explosion damage scales at x2", float(payload["explosion_damage"]), 392.0)
	_expect_close("current same school positive impact scales at x2", float(payload["impact_damage"]), 280.0)


func _test_cross_school_isolation() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.record_card_effect(_card("dry_ice_probe", "dry_ice"))
	chain.on_card_played(1)
	var payload := _thermobaric_payload()
	chain.apply_base_multiplier("thermobaric", payload)
	chain.apply_inherited_effects("thermobaric", payload)
	chain.apply_card_effect(_card("rich_fuel_fill", "thermobaric"), payload)
	_expect_close("other school inherited effect is ignored", float(payload["explosion_damage"]), 280.0)


func _test_negative_values_do_not_scale() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.on_card_played(1)
	chain.on_card_played(2)
	var payload := _thermobaric_payload()
	chain.apply_base_multiplier("thermobaric", payload)
	chain.apply_card_effect(_card("thermobaric_barrage", "thermobaric"), payload)
	_expect_eq("positive projectile add scales at x3", int(payload["projectile_count"]), 6)
	_expect_close("negative damage multiplier does not scale at x3", float(payload["explosion_damage"]), 240.0)
	_expect_close("negative impact multiplier does not scale at x3", float(payload["impact_damage"]), 240.0)


func _test_positive_adds_scale() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.on_card_played(1)
	chain.on_card_played(2)
	var payload := _dry_ice_payload()
	chain.apply_base_multiplier("dry_ice", payload)
	chain.apply_card_effect(_card("condensation_calibration", "dry_ice"), payload)
	_expect_eq("positive pierce add scales at x3", int(payload["pierce_count"]), 6)
	_expect_close("base dry ice damage scales at x3", float(payload["damage"]), 270.0)


func _test_reset_clears_inherited_effects() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.record_card_effect(_card("thermobaric_probe", "thermobaric"))
	chain.on_card_played(2)
	var payload := _thermobaric_payload()
	chain.apply_base_multiplier("thermobaric", payload)
	chain.apply_inherited_effects("thermobaric", payload)
	chain.apply_card_effect(_card("thermal_explosion", "thermobaric"), payload)
	_expect_close("jump reset clears inherited same school effects", float(payload["explosion_damage"]), 180.0)
	chain.record_card_effect(_card("thermobaric_probe", "thermobaric"))
	chain.on_card_played(2)
	payload = _thermobaric_payload()
	chain.apply_inherited_effects("thermobaric", payload)
	chain.apply_card_effect(_card("thermal_explosion", "thermobaric"), payload)
	_expect_close("same cost reset clears inherited same school effects", float(payload["explosion_damage"]), 180.0)


func _test_break_clears_inherited_effects() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.record_card_effect(_card("thermobaric_probe", "thermobaric"))
	chain.break_chain()
	chain.on_card_played(1)
	var payload := _thermobaric_payload()
	chain.apply_inherited_effects("thermobaric", payload)
	chain.apply_card_effect(_card("thermal_explosion", "thermobaric"), payload)
	_expect_close("break clears inherited effects", float(payload["explosion_damage"]), 180.0)


func _test_electro_calibration_effects() -> void:
	var chain: CardChainState = CARD_CHAIN_STATE.new()
	chain.on_card_played(0)
	chain.on_card_played(1)
	var payload := _electro_payload()
	chain.apply_base_multiplier("electro_pierce", payload)
	chain.apply_card_effect(_card("magnetic_pole_calibration", "electro_pierce"), payload)
	_expect_close("magnetic calibration scales only positive radius at x2", float(payload["explosion_radius"]), 22.4)
	_expect_close("magnetic calibration keeps base pierce damage only", float(payload["pierce_damage"]), 200.0)
	_expect_eq("magnetic calibration has no target rule side effect", payload.has("target_rule"), false)
	payload = _electro_payload()
	chain.apply_base_multiplier("electro_pierce", payload)
	chain.apply_card_effect(_card("capacitor_test", "electro_pierce"), payload)
	_expect_close("capacitor test scales pierce damage at x2", float(payload["pierce_damage"]), 280.0)


func _card(card_id: String, core_skill: String) -> Dictionary:
	return {"card_id": card_id, "core_skill": core_skill}


func _wildcard_card(card_id: String) -> Dictionary:
	return {"card_id": card_id, "core_skill": "", "cost": 0, "chain_wildcard": true, "chain_cost_mode": "wildcard"}


func _cost_card(cost: int) -> Dictionary:
	return {"card_id": "cost_%d" % cost, "cost": cost}


func _thermobaric_payload() -> Dictionary:
	return {
		"projectile_count": 1,
		"impact_damage": 100.0,
		"explosion_damage": 100.0,
		"explosion_radius": 10.0,
		"knockback_distance": 1.0,
		"burn_duration": 2.0,
		"burn_total_damage": 20.0,
		"spark_count": 1,
	}


func _dry_ice_payload() -> Dictionary:
	return {
		"projectile_count": 1,
		"damage": 90.0,
		"pierce_count": 1,
		"knockback_distance": 1.0,
		"freeze_duration": 2.0,
		"frostbite_duration": 10.0,
		"frostbite_max_stack": 5,
		"small_ice_count": 3,
		"small_ice_pierce_count": 1,
	}


func _electro_payload() -> Dictionary:
	return {
		"projectile_count": 1,
		"pierce_damage": 100.0,
		"paralyze_duration": 1.0,
		"explosion_damage": 80.0,
		"explosion_radius": 8.0,
		"matrix_duration": 1.0,
		"matrix_tick_damage": 10.0,
		"matrix_slow_duration": 1.0,
		"particle_count": 2,
		"particle_pierce_count": 5,
	}


func _expect_eq(name: String, actual: Variant, expected: Variant) -> void:
	_case_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [name, str(expected), str(actual)])


func _expect_close(name: String, actual: float, expected: float) -> void:
	_case_count += 1
	if absf(actual - expected) > 0.001:
		_failures.append("%s: expected %.3f, got %.3f" % [name, expected, actual])
