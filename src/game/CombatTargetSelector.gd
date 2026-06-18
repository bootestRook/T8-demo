extends RefCounted
class_name CombatTargetSelector


static func select_target(
	monsters: Array, rule: String, excluded: Array, offset: int, context: Dictionary, default_center: Vector2, range_scale: float
) -> Dictionary:
	var candidates := targets_matching_context_range(
		alive_monsters_sorted_by_wall(monsters), excluded, context, default_center, range_scale
	)
	if rule == "nearest_to_player" or rule == "nearest_to_player_different_first":
		var source_position: Vector2 = context.get("source_position", default_center)
		candidates.sort_custom(func(a, b) -> bool: return sort_by_distance_to_point(a, b, source_position))
	if rule == "random_in_range":
		return select_random_offset_candidate(candidates, offset, context)
	if rule == "elite_boss_or_near_wall":
		for item in candidates:
			var priority_monster: Dictionary = item
			var monster_id := String(priority_monster.get("monster_id", ""))
			var monster_type := String(priority_monster.get("type", ""))
			if monster_id == "elite" or monster_id == "boss" or monster_type == "elite" or monster_type == "boss":
				return priority_monster
	if rule == "nearest_to_wall_different_first" or rule == "nearest_to_player_different_first":
		return select_offset_candidate(candidates, offset)
	if not candidates.is_empty():
		return candidates[0] as Dictionary
	return {}


static func select_offset_candidate(candidates: Array, offset: int) -> Dictionary:
	if candidates.is_empty():
		return {}
	var target_index := maxi(0, offset)
	if target_index >= candidates.size():
		target_index = target_index % candidates.size()
	return candidates[target_index] as Dictionary


static func select_random_offset_candidate(candidates: Array, offset: int, context: Dictionary) -> Dictionary:
	if candidates.is_empty():
		return {}
	var start_index := int(context.get("card_play_token", randi()))
	var target_index := (start_index + maxi(0, offset)) % candidates.size()
	return candidates[target_index] as Dictionary


static func targets_matching_context_range(
	candidates: Array, excluded: Array, context: Dictionary, default_center: Vector2, range_scale: float
) -> Array:
	var result: Array = []
	for item in candidates:
		var monster: Dictionary = item
		if excluded.has(String(monster.get("id", ""))):
			continue
		if is_monster_in_context_range(monster, context, default_center, range_scale):
			result.append(monster)
	return result


static func is_monster_in_context_range(monster: Dictionary, context: Dictionary, default_center: Vector2, range_scale: float) -> bool:
	var radius := float(context.get("target_radius", 0.0)) * range_scale
	if radius <= 0.0:
		return true
	var center: Vector2 = context.get("target_center", default_center)
	var position: Vector2 = monster.get("position", Vector2.ZERO)
	return position.distance_to(center) <= radius + float(monster.get("radius", 24.0))


static func alive_monsters_sorted_by_wall(monsters: Array) -> Array:
	var result: Array = []
	for item in monsters:
		if item is Dictionary and float((item as Dictionary).get("hp", 0.0)) > 0.0:
			result.append((item as Dictionary).duplicate(true))
	result.sort_custom(func(a, b) -> bool: return sort_by_wall(a, b))
	return result


static func sort_by_wall(a: Dictionary, b: Dictionary) -> bool:
	var a_position: Vector2 = a.get("position", Vector2.ZERO)
	var b_position: Vector2 = b.get("position", Vector2.ZERO)
	return a_position.y > b_position.y


static func sort_by_distance_to_point(a: Dictionary, b: Dictionary, point: Vector2) -> bool:
	var a_position: Vector2 = a.get("position", Vector2.ZERO)
	var b_position: Vector2 = b.get("position", Vector2.ZERO)
	var a_offset := a_position - point
	var b_offset := b_position - point
	var a_distance := a_offset.x * a_offset.x + a_offset.y * a_offset.y
	var b_distance := b_offset.x * b_offset.x + b_offset.y * b_offset.y
	return a_distance < b_distance


static func targets_in_radius(monsters: Array, center: Vector2, radius: float) -> Array:
	var result: Array = []
	for item in monsters:
		if not (item is Dictionary):
			continue
		var monster: Dictionary = item
		if float(monster.get("hp", 0.0)) <= 0.0:
			continue
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		if position.distance_to(center) <= radius + float(monster.get("radius", 24.0)):
			result.append(String(monster.get("id", "")))
	return result


static func first_monster_on_segment(monsters: Array, start: Vector2, end: Vector2, excluded: Array, width: float) -> Dictionary:
	var best := {}
	var best_distance := 999999.0
	var segment := end - start
	var segment_length_squared := segment.x * segment.x + segment.y * segment.y
	if segment_length_squared <= 0.0:
		return best
	for item in monsters:
		if not (item is Dictionary):
			continue
		var monster: Dictionary = item
		if float(monster.get("hp", 0.0)) <= 0.0:
			continue
		if excluded.has(String(monster.get("id", ""))):
			continue
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		var t := clampf(((position.x - start.x) * segment.x + (position.y - start.y) * segment.y) / segment_length_squared, 0.0, 1.0)
		var closest := start + segment * t
		var distance := closest.distance_to(position)
		var hit_radius := float(monster.get("radius", 24.0)) + width * 0.5
		if distance <= hit_radius and t < best_distance:
			best = monster
			best_distance = t
	return best
