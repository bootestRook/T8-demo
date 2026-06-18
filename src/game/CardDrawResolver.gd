extends RefCounted
class_name CardDrawResolver


static func apply_card_draw_effect(card: Dictionary, draw_pile: Array, hand_card_ids: Array, card_configs: Dictionary) -> Dictionary:
	var draw_count := maxi(0, int(card.get("draw_count", 0)))
	if draw_count <= 0:
		return {}
	var draw_school := String(card.get("draw_school", ""))
	var drawn_card_ids := _draw_cards_from_current_deck(draw_pile, hand_card_ids, card_configs, draw_count, draw_school)
	return {
		"requested_count": draw_count,
		"school": draw_school,
		"drawn_card_ids": drawn_card_ids,
	}


static func _draw_cards_from_current_deck(
	draw_pile: Array, hand_card_ids: Array, card_configs: Dictionary, count: int, school_filter: String = ""
) -> Array:
	var drawn_card_ids: Array = []
	var remaining := maxi(0, count)
	var index := 0
	while remaining > 0 and index < draw_pile.size():
		var card_id := String(draw_pile[index])
		if school_filter.is_empty() or _card_matches_school(card_configs, card_id, school_filter):
			draw_pile.remove_at(index)
			hand_card_ids.append(card_id)
			drawn_card_ids.append(card_id)
			remaining -= 1
		else:
			index += 1
	return drawn_card_ids


static func pick_random_card_ids(source: Array, count: int, rng: Variant) -> Array:
	var pool := to_string_array(source)
	var result: Array = []
	while result.size() < count and not pool.is_empty():
		var selected_index := int(rng.randf_range(0.0, float(pool.size())))
		selected_index = mini(pool.size() - 1, maxi(0, selected_index))
		result.append(String(pool[selected_index]))
		pool.remove_at(selected_index)
	return result


static func to_string_array(source: Array) -> Array:
	var result: Array = []
	for item in source:
		result.append(String(item))
	return result


static func _card_matches_school(card_configs: Dictionary, card_id: String, school_filter: String) -> bool:
	var card: Dictionary = card_configs.get(card_id, {}) as Dictionary
	return String(card.get("school", "")) == school_filter
