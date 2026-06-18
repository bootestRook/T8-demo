extends RefCounted
class_name CardChainState

const CARD_CHAIN_RULES := preload("res://src/game/CardChainRules.gd")
const CHAIN_MULTIPLIER_LIMIT := 999
const WILDCARD_CHAIN_COST_MODE := "wildcard"

var chain_multiplier := 1
var highest_chain_multiplier := 0
var last_chain_cost := -1
var has_active_chain := false
var wildcard_bridge_active := false
var effect_specs_by_core_skill: Dictionary = {}


func reset() -> void:
	_clear_active_chain()
	highest_chain_multiplier = 0


func _clear_active_chain() -> void:
	chain_multiplier = 1
	last_chain_cost = -1
	has_active_chain = false
	wildcard_bridge_active = false
	effect_specs_by_core_skill.clear()


func is_chain_wildcard(card: Dictionary) -> bool:
	return bool(card.get("chain_wildcard", false)) or String(card.get("chain_cost_mode", "")) == WILDCARD_CHAIN_COST_MODE


func get_energy_cost_for_card(card: Dictionary) -> int:
	return maxi(0, int(card.get("cost", 0)))


func get_chain_cost_for_card(card: Dictionary) -> int:
	if is_chain_wildcard(card):
		return -1
	return maxi(0, int(card.get("chain_cost", card.get("cost", 0))))


func get_next_wildcard_chain_cost() -> int:
	return -1


func get_resolution_chain_multiplier_for_card(card: Dictionary) -> int:
	if is_chain_wildcard(card):
		return mini(chain_multiplier + 1, CHAIN_MULTIPLIER_LIMIT) if has_active_chain else 1
	if not has_active_chain:
		return 1
	var cost := get_chain_cost_for_card(card)
	if wildcard_bridge_active or cost == last_chain_cost + 1:
		return mini(chain_multiplier + 1, CHAIN_MULTIPLIER_LIMIT)
	return 1


func can_continue_chain(card: Dictionary) -> bool:
	if is_chain_wildcard(card):
		return has_active_chain
	if not has_active_chain:
		return false
	if wildcard_bridge_active:
		return true
	return last_chain_cost >= 0 and get_chain_cost_for_card(card) == last_chain_cost + 1


func on_card_played(cost: int) -> void:
	cost = maxi(0, cost)
	if not has_active_chain:
		chain_multiplier = 1
		effect_specs_by_core_skill.clear()
		last_chain_cost = cost
		has_active_chain = true
		wildcard_bridge_active = false
		_record_highest_chain()
		return
	if wildcard_bridge_active or cost == last_chain_cost + 1:
		chain_multiplier = mini(chain_multiplier + 1, CHAIN_MULTIPLIER_LIMIT)
	else:
		chain_multiplier = 1
		effect_specs_by_core_skill.clear()
	last_chain_cost = cost
	wildcard_bridge_active = false
	_record_highest_chain()


func on_card_played_for_card(card: Dictionary) -> void:
	if is_chain_wildcard(card):
		on_wildcard_played()
		return
	on_card_played(get_chain_cost_for_card(card))


func on_wildcard_played() -> void:
	if has_active_chain:
		chain_multiplier = mini(chain_multiplier + 1, CHAIN_MULTIPLIER_LIMIT)
	else:
		chain_multiplier = 1
		effect_specs_by_core_skill.clear()
		has_active_chain = true
	wildcard_bridge_active = true
	_record_highest_chain()


func break_chain() -> void:
	_clear_active_chain()


func _record_highest_chain() -> void:
	highest_chain_multiplier = maxi(highest_chain_multiplier, chain_multiplier)


func apply_base_multiplier(core_skill: String, payload: Dictionary) -> void:
	CARD_CHAIN_RULES.apply_base_multiplier(core_skill, payload, chain_multiplier)


func apply_inherited_effects(core_skill: String, payload: Dictionary) -> void:
	var effect_specs: Array = effect_specs_by_core_skill.get(core_skill, []) as Array
	for item in effect_specs:
		if item is Dictionary:
			CARD_CHAIN_RULES.apply_effect_spec(payload, item as Dictionary, chain_multiplier)


func apply_card_effect(card: Dictionary, payload: Dictionary) -> void:
	CARD_CHAIN_RULES.apply_effect_spec(payload, _get_card_effect_spec(card), chain_multiplier)
	payload["pierce_count"] = maxi(0, int(payload.get("pierce_count", 0)))
	payload["paralyze_duration"] = maxf(0.05, float(payload.get("paralyze_duration", 0.0)))


func record_card_effect(card: Dictionary) -> void:
	var core_skill := String(card.get("core_skill", ""))
	if core_skill.is_empty():
		return
	var effect_spec := _get_card_effect_spec(card)
	if effect_spec.is_empty():
		return
	var effect_specs: Array = effect_specs_by_core_skill.get(core_skill, []) as Array
	effect_specs.append(effect_spec)
	effect_specs_by_core_skill[core_skill] = effect_specs


func _get_card_effect_spec(card: Dictionary) -> Dictionary:
	var card_id := String(card.get("card_id", ""))
	return CARD_CHAIN_RULES.get_card_effect_spec(card_id)
