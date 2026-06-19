extends RefCounted
class_name HudHandQueries


static func current_hand_count(snapshot: Dictionary, default_cards: Array) -> int:
	if snapshot.is_empty():
		return default_cards.size()
	var cards_variant: Variant = snapshot.get("hand_cards", default_cards)
	if cards_variant is Array:
		return (cards_variant as Array).size()
	return default_cards.size()


static func card_index_at_point(card_widgets: Array, hand_count: int, point: Vector2) -> int:
	for offset in range(hand_count):
		var index := hand_count - 1 - offset
		if index < 0 or index >= card_widgets.size():
			continue
		var panel: PanelContainer = card_widgets[index]["panel"] as PanelContainer
		if panel.visible and panel.get_global_rect().has_point(point):
			return index
	return -1


static func card_index_for_panel(card_widgets: Array, panel: PanelContainer) -> int:
	for index in range(card_widgets.size()):
		if card_widgets[index].get("panel", null) == panel:
			return index
	return -1


static func card_reorder_index_at_point(
	card_widgets: Array, hand_layer: Control, hand_card_size: Vector2, hand_count: int, point: Vector2, dragged_index: int
) -> int:
	if hand_count <= 0 or dragged_index < 0 or dragged_index >= hand_count:
		return -1
	var hand_origin := hand_layer.get_global_rect().position
	var local_x := point.x - hand_origin.x
	var best_index := dragged_index
	var best_distance := 999999.0
	for index in range(hand_count):
		var widget: Dictionary = card_widgets[index]
		var slot_position: Vector2 = widget.get("base_position", Vector2.ZERO)
		var slot_center_x := slot_position.x + hand_card_size.x * 0.5
		var distance := absf(local_x - slot_center_x)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


static func card_name_for_index(snapshot: Dictionary, default_cards: Array, index: int) -> String:
	var cards_variant: Variant = snapshot.get("hand_cards", default_cards)
	if not (cards_variant is Array):
		return "卡牌"
	var cards: Array = cards_variant as Array
	if index < 0 or index >= cards.size() or not (cards[index] is Dictionary):
		return "卡牌"
	var card: Dictionary = cards[index]
	return String(card.get("name", "卡牌"))


static func is_valid_hand_index(index: int, hand_count: int) -> bool:
	return index >= 0 and index < hand_count


static func card_cooldown_remaining(card_widgets: Array, index: int) -> float:
	if index < 0 or index >= card_widgets.size():
		return 0.0
	var widget: Dictionary = card_widgets[index]
	return maxf(0.0, float(widget.get("cooldown_remaining", 0.0)))


static func card_cooldown_message(card_widgets: Array, index: int) -> String:
	return "冷却%d秒" % ceili(card_cooldown_remaining(card_widgets, index))


static func card_play_failure_message(snapshot: Dictionary, messages: Dictionary) -> String:
	var reason := String(snapshot.get("last_card_play_failure", ""))
	return String(messages.get(reason, "当前不能出牌"))
