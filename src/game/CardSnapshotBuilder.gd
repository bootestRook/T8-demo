extends RefCounted
class_name CardSnapshotBuilder

const CARD_CHAIN_PARAM_RULES := preload("res://src/game/CardChainParamRules.gd")


static func get_card_display_name(card: Dictionary, fallback: String) -> String:
	return String(card.get("name", card.get("card_name", fallback)))


static func get_card_effect_text(card: Dictionary, card_chain: CardChainState = null, rich_text := false) -> String:
	var chain_scale := 1
	if card_chain != null:
		chain_scale = card_chain.get_resolution_chain_multiplier_for_card(card)
	return CARD_CHAIN_PARAM_RULES.format_effect_text(card, chain_scale, rich_text)


static func get_card_school_text(card: Dictionary) -> String:
	var school_text := String(card.get("school", card.get("core_skill", ""))).strip_edges()
	if school_text.is_empty():
		return "通用"
	return school_text


static func get_card_same_name_key(card: Dictionary, fallback: String, card_chain: CardChainState) -> String:
	if card_chain.is_chain_wildcard(card) and not String(card.get("core_skill", "")).is_empty():
		return get_card_school_text(card)
	return String(card.get("same_name_key", card.get("card_name", fallback)))


static func get_upgrade_choice_snapshot(
	upgrade: Dictionary, card: Dictionary, card_chain: CardChainState, cost_owned_count := -1, school_owned_count := -1
) -> Dictionary:
	var choice := upgrade.duplicate(true)
	if String(choice.get("entry_type", "")) != "card" and String(choice.get("kind", "")) != "new_card":
		return choice
	if card.is_empty():
		return choice
	var card_name := get_card_display_name(card, String(choice.get("card_id", "")))
	var energy_cost := card_chain.get_energy_cost_for_card(card)
	var is_wildcard := card_chain.is_chain_wildcard(card)
	choice["card_name"] = card_name
	choice["title"] = card_name
	choice["cost"] = energy_cost
	choice["energy_cost"] = energy_cost
	choice["cost_display"] = "X" if is_wildcard else str(energy_cost)
	choice["chain_wildcard"] = is_wildcard
	choice["school"] = get_card_school_text(card)
	choice["description"] = get_card_effect_text(card, card_chain)
	if cost_owned_count >= 0:
		choice["cost_owned_count"] = cost_owned_count
		choice["cost_owned_count_text"] = "X%d" % cost_owned_count
	if school_owned_count >= 0:
		choice["school_owned_count"] = school_owned_count
		choice["school_owned_count_text"] = "X%d" % school_owned_count
	return choice


static func get_hand_card_snapshots(
	hand_card_ids: Array, card_configs: Dictionary, card_chain: CardChainState, cooldown_until: Dictionary, elapsed_time: float
) -> Array:
	var cards: Array = []
	for index in range(hand_card_ids.size()):
		var card_id := String(hand_card_ids[index])
		var card_snapshot := get_card_snapshot(card_id, index, card_configs, card_chain, cooldown_until, elapsed_time)
		if card_snapshot.is_empty():
			continue
		cards.append(card_snapshot)
	return cards


static func get_pile_card_snapshots(
	card_ids: Array, card_configs: Dictionary, card_chain: CardChainState, cooldown_until: Dictionary, elapsed_time: float, prefix: String
) -> Array:
	var cards: Array = []
	for index in range(card_ids.size()):
		var card_id := String(card_ids[index])
		var card_snapshot := get_card_snapshot(card_id, index, card_configs, card_chain, cooldown_until, elapsed_time)
		if card_snapshot.is_empty():
			continue
		card_snapshot["instance_id"] = "%s:%s:%d" % [prefix, card_id, index]
		cards.append(card_snapshot)
	return cards


static func get_card_snapshot(
	card_id: String, index: int, card_configs: Dictionary, card_chain: CardChainState, cooldown_until: Dictionary, elapsed_time: float
) -> Dictionary:
	var card: Dictionary = card_configs.get(card_id, {}) as Dictionary
	if card.is_empty():
		return {}
	var same_name_key := get_card_same_name_key(card, card_id, card_chain)
	var effect_text := get_card_effect_text(card, card_chain)
	var effect_rich_text := get_card_effect_text(card, card_chain, true)
	var energy_cost := card_chain.get_energy_cost_for_card(card)
	var chain_cost_preview := card_chain.get_chain_cost_for_card(card)
	var is_wildcard := card_chain.is_chain_wildcard(card)
	var display_cost: Variant = "X" if is_wildcard else energy_cost
	return {
		"id": card_id,
		"instance_id": "%s:%d" % [card_id, index],
		"slot_index": index,
		"cost": energy_cost,
		"energy_cost": energy_cost,
		"display_cost": display_cost,
		"display_cost_text": "X" if is_wildcard else str(display_cost),
		"chain_cost_preview": chain_cost_preview,
		"chain_wildcard": is_wildcard,
		"can_continue_chain": card_chain.can_continue_chain(card),
		"name": get_card_display_name(card, card_id),
		"type": String(card.get("type", "")),
		"desc": effect_text,
		"desc_rich_text": effect_rich_text,
		"art": String(card.get("icon", "")),
		"art_slot": String(card.get("icon", "")),
		"effect": effect_text,
		"effect_rich_text": effect_rich_text,
		"school": get_card_school_text(card),
		"core_skill": String(card.get("core_skill", "")),
		"same_name_key": same_name_key,
		"cooldown_remaining": maxf(0.0, float(cooldown_until.get(same_name_key, 0.0)) - elapsed_time),
	}
