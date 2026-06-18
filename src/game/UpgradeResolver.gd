extends RefCounted
class_name UpgradeResolver


static func build_upgrade_choices(
	upgrade_pool: Array,
	card_configs: Dictionary,
	card_deck: CardDeckState,
	upgrade_pick_counts: Dictionary,
	card_chain: CardChainState,
	rng: RandomNumberGenerator,
	choice_count: int
) -> Array:
	var choices: Array = []
	var available: Array = []
	for item in upgrade_pool:
		if item is Dictionary and _is_upgrade_allowed(item as Dictionary, card_configs, upgrade_pick_counts):
			available.append((item as Dictionary).duplicate(true))
	while choices.size() < choice_count and not available.is_empty():
		var selected_index := _weighted_upgrade_index(available, rng)
		var selected_upgrade: Dictionary = available[selected_index] as Dictionary
		var card: Dictionary = card_configs.get(String(selected_upgrade.get("card_id", "")), {}) as Dictionary
		var cost_owned_count := _get_cost_owned_count(card, card_configs, card_deck, card_chain)
		var school_owned_count := _get_school_owned_count(card, card_configs, card_deck)
		choices.append(
			CardSnapshotBuilder.get_upgrade_choice_snapshot(selected_upgrade, card, card_chain, cost_owned_count, school_owned_count)
		)
		available.remove_at(selected_index)
	return choices


static func record_upgrade_pick(upgrade: Dictionary, upgrade_pick_counts: Dictionary) -> void:
	var upgrade_id := String(upgrade.get("id", ""))
	if upgrade_id.is_empty():
		return
	upgrade_pick_counts[upgrade_id] = int(upgrade_pick_counts.get(upgrade_id, 0)) + 1


static func _get_cost_owned_count(card: Dictionary, card_configs: Dictionary, card_deck: CardDeckState, card_chain: CardChainState) -> int:
	if card.is_empty() or card_deck == null:
		return 0
	if card_chain == null:
		return card_deck.count_cards_by_cost(card_configs, null, int(card.get("cost", 0)), false)
	return card_deck.count_cards_by_cost(
		card_configs, card_chain, card_chain.get_energy_cost_for_card(card), card_chain.is_chain_wildcard(card)
	)


static func _get_school_owned_count(card: Dictionary, card_configs: Dictionary, card_deck: CardDeckState) -> int:
	if card.is_empty() or card_deck == null:
		return 0
	return card_deck.count_cards_by_school(card_configs, CardSnapshotBuilder.get_card_school_text(card))


static func apply_upgrade(
	upgrade: Dictionary,
	card_configs: Dictionary,
	card_deck: CardDeckState,
	gun_runtime: Dictionary,
	wall_hp_max: int,
	hp: int,
	energy_regen_per_sec: float,
	refill_interval: float
) -> Dictionary:
	var result := {
		"wall_hp_max": wall_hp_max,
		"hp": hp,
		"energy_regen_per_sec": energy_regen_per_sec,
		"refill_interval": refill_interval,
		"card_acquire_event": {},
	}
	var kind := String(upgrade.get("kind", ""))
	match kind:
		"new_card":
			var card_id := String(upgrade.get("card_id", ""))
			if card_configs.has(card_id):
				result["card_acquire_event"] = card_deck.add_card_reward(card_id)
		"gun_upgrade":
			_apply_gun_upgrade(upgrade, gun_runtime)
		"survival":
			_apply_survival_upgrade(upgrade, result)
		"energy":
			_apply_energy_upgrade(upgrade, result)
		"core_skill":
			_apply_core_skill_upgrade(upgrade, gun_runtime)
	return result


static func _is_upgrade_allowed(upgrade: Dictionary, card_configs: Dictionary, upgrade_pick_counts: Dictionary) -> bool:
	var upgrade_id := String(upgrade.get("id", ""))
	var max_pick_count := int(upgrade.get("max_pick_count", 1))
	if max_pick_count > 0 and int(upgrade_pick_counts.get(upgrade_id, 0)) >= max_pick_count:
		return false
	if not _upgrade_prerequisites_met(upgrade, upgrade_pick_counts):
		return false
	if _upgrade_mutex_blocked(upgrade, upgrade_pick_counts):
		return false
	if String(upgrade.get("field", "")) == "energy_cap":
		return false
	if String(upgrade.get("kind", "")) == "new_card":
		return card_configs.has(String(upgrade.get("card_id", "")))
	return true


static func _upgrade_prerequisites_met(upgrade: Dictionary, upgrade_pick_counts: Dictionary) -> bool:
	var prerequisites: Array = upgrade.get("prerequisites", []) as Array
	for prereq in prerequisites:
		if int(upgrade_pick_counts.get(String(prereq), 0)) <= 0:
			return false
	return true


static func _upgrade_mutex_blocked(upgrade: Dictionary, upgrade_pick_counts: Dictionary) -> bool:
	var mutexes: Array = upgrade.get("mutexes", []) as Array
	for mutex in mutexes:
		if int(upgrade_pick_counts.get(String(mutex), 0)) > 0:
			return true
	return false


static func _weighted_upgrade_index(upgrades: Array, rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	for item in upgrades:
		if item is Dictionary:
			total_weight += maxf(0.0, float((item as Dictionary).get("weight", 1.0)))
	if total_weight <= 0.0:
		return 0
	var roll := rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for index in range(upgrades.size()):
		var upgrade: Dictionary = upgrades[index] as Dictionary
		cursor += maxf(0.0, float(upgrade.get("weight", 1.0)))
		if roll <= cursor:
			return index
	return maxi(0, upgrades.size() - 1)


static func _apply_gun_upgrade(upgrade: Dictionary, gun_runtime: Dictionary) -> void:
	var field := String(upgrade.get("field", ""))
	if field.is_empty():
		return
	if upgrade.has("add"):
		var current_value: Variant = gun_runtime.get(field, 0)
		if current_value is float or upgrade.get("add", 0) is float:
			gun_runtime[field] = float(current_value) + float(upgrade.get("add", 0))
		else:
			gun_runtime[field] = int(current_value) + int(upgrade.get("add", 0))
	if upgrade.has("mul"):
		gun_runtime[field] = float(gun_runtime.get(field, 1.0)) * float(upgrade.get("mul", 1.0))
	if upgrade.has("damage_mul"):
		gun_runtime["bullet_damage_mul"] = float(gun_runtime.get("bullet_damage_mul", 1.0)) * float(upgrade.get("damage_mul", 1.0))


static func _apply_survival_upgrade(upgrade: Dictionary, result: Dictionary) -> void:
	var field := String(upgrade.get("field", ""))
	if field == "wall_hp_max":
		var old_max := int(result.get("wall_hp_max", 1))
		var new_max := maxi(1, int(float(old_max) * float(upgrade.get("mul", 1.0))))
		result["wall_hp_max"] = new_max
		result["hp"] = int(result.get("hp", 0)) + new_max - old_max
	elif field == "wall_repair_ratio":
		var wall_hp_max := int(result.get("wall_hp_max", 1))
		result["hp"] = mini(wall_hp_max, int(result.get("hp", 0)) + int(float(wall_hp_max) * float(upgrade.get("value", 0.0))))


static func _apply_energy_upgrade(upgrade: Dictionary, result: Dictionary) -> void:
	var field := String(upgrade.get("field", ""))
	if field == "energy_regen_per_sec":
		result["energy_regen_per_sec"] = float(result.get("energy_regen_per_sec", 1.0)) * float(upgrade.get("mul", 1.0))
	elif field == "refill_interval":
		result["refill_interval"] = maxf(0.25, float(result.get("refill_interval", 1.0)) * float(upgrade.get("mul", 1.0)))


static func _apply_core_skill_upgrade(upgrade: Dictionary, gun_runtime: Dictionary) -> void:
	var core_skill := String(upgrade.get("core_skill", ""))
	var field := String(upgrade.get("field", ""))
	var core_runtime := _get_core_skill_runtime(gun_runtime, core_skill)
	if core_runtime.is_empty() or field.is_empty():
		return
	core_runtime[field] = int(core_runtime.get(field, 0)) + int(upgrade.get("add", 0))
	var core_skills: Dictionary = gun_runtime.get("core_skills", {})
	core_skills[core_skill] = core_runtime
	gun_runtime["core_skills"] = core_skills


static func _get_core_skill_runtime(gun_runtime: Dictionary, core_skill: String) -> Dictionary:
	var core_skills: Dictionary = gun_runtime.get("core_skills", {})
	return (core_skills.get(core_skill, {}) as Dictionary).duplicate(true)
