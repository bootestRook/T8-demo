extends RefCounted
class_name CardDeckState

const CARD_DRAW_RESOLVER := preload("res://src/game/CardDrawResolver.gd")

var hand_limit := 0
var refill_interval := 0.0
var refill_timer := 0.0
var discard_cooldown_remaining := 0.0
var draw_pile: Array = []
var discard_pile: Array = []
var hand_card_ids: Array = []


func reset(limit: int, interval: float) -> void:
	hand_limit = limit
	refill_interval = interval
	refill_timer = 0.0
	discard_cooldown_remaining = 0.0
	clear_piles()


func clear_piles() -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand_card_ids.clear()


func seed_draw_pile(card_ids: Array) -> void:
	draw_pile.clear()
	for card_id in card_ids:
		draw_pile.append(String(card_id))


func tick_cooldowns(delta: float) -> void:
	discard_cooldown_remaining = maxf(0.0, discard_cooldown_remaining - delta)


func can_reorder_hand_card(from_index: int, to_index: int) -> bool:
	return (
		from_index >= 0
		and from_index < hand_card_ids.size()
		and to_index >= 0
		and to_index < hand_card_ids.size()
		and from_index != to_index
	)


func reorder_hand_card(from_index: int, to_index: int) -> bool:
	if not can_reorder_hand_card(from_index, to_index):
		return false
	var card_id: Variant = hand_card_ids[from_index]
	hand_card_ids.remove_at(from_index)
	hand_card_ids.insert(clampi(to_index, 0, hand_card_ids.size()), card_id)
	return true


func discard_hand(cooldown: float) -> void:
	for card_id in hand_card_ids:
		discard_pile.append(card_id)
	hand_card_ids.clear()
	discard_cooldown_remaining = cooldown


func refill_hand_to_limit() -> void:
	while hand_card_ids.size() < hand_limit:
		if not draw_one_card():
			return


func update_refill(delta: float) -> void:
	if hand_card_ids.size() >= hand_limit:
		return
	refill_timer += delta
	while hand_card_ids.size() < hand_limit and refill_timer >= refill_interval:
		refill_timer -= refill_interval
		if not draw_one_card():
			return


func draw_one_card() -> bool:
	if draw_pile.is_empty():
		shuffle_discard_into_draw()
	if draw_pile.is_empty():
		return false
	var card_id := String(draw_pile[0])
	draw_pile.remove_at(0)
	hand_card_ids.append(card_id)
	return true


func shuffle_discard_into_draw() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = CARD_DRAW_RESOLVER.to_string_array(discard_pile)
	discard_pile.clear()


func move_hand_card_to_discard(card_id: String) -> void:
	for index in range(hand_card_ids.size()):
		if String(hand_card_ids[index]) == card_id:
			move_hand_index_to_discard(index)
			return


func move_hand_index_to_discard(index: int) -> void:
	var card_id := String(hand_card_ids[index])
	hand_card_ids.remove_at(index)
	discard_pile.append(card_id)


func remove_hand_index(index: int) -> void:
	hand_card_ids.remove_at(index)


func add_card_reward(card_id: String) -> Dictionary:
	if hand_card_ids.size() < hand_limit and not has_refill_source():
		var hand_index := hand_card_ids.size()
		hand_card_ids.append(card_id)
		return {
			"card_id": card_id,
			"destination": "hand",
			"hand_index": hand_index,
		}
	var draw_index := draw_pile.size()
	draw_pile.append(card_id)
	return {
		"card_id": card_id,
		"destination": "draw_pile",
		"draw_index": draw_index,
	}


func has_refill_source() -> bool:
	return not draw_pile.is_empty() or not discard_pile.is_empty()


func count_cards_by_school(card_configs: Dictionary, school: String) -> int:
	var target_school := school.strip_edges()
	if target_school.is_empty():
		return 0
	var count := 0
	for card_id in _all_owned_card_ids():
		var card: Dictionary = card_configs.get(String(card_id), {}) as Dictionary
		if card.is_empty():
			continue
		if String(card.get("school", card.get("core_skill", ""))).strip_edges() == target_school:
			count += 1
	return count


func count_cards_by_cost(card_configs: Dictionary, card_chain: CardChainState, target_cost: int, target_is_wildcard := false) -> int:
	var count := 0
	for card_id in _all_owned_card_ids():
		var card: Dictionary = card_configs.get(String(card_id), {}) as Dictionary
		if card.is_empty():
			continue
		var is_wildcard := card_chain != null and card_chain.is_chain_wildcard(card)
		if target_is_wildcard:
			if is_wildcard:
				count += 1
			continue
		if is_wildcard:
			continue
		var card_cost := int(card.get("cost", 0))
		if card_chain != null:
			card_cost = card_chain.get_energy_cost_for_card(card)
		if card_cost == target_cost:
			count += 1
	return count


func apply_card_draw_effect(card: Dictionary, card_configs: Dictionary) -> Dictionary:
	return CARD_DRAW_RESOLVER.apply_card_draw_effect(card, draw_pile, hand_card_ids, card_configs)


func _all_owned_card_ids() -> Array:
	var result: Array = []
	result.append_array(hand_card_ids)
	result.append_array(draw_pile)
	result.append_array(discard_pile)
	return result
