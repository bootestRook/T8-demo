extends RefCounted
class_name CoreSkillPayloadBuilder


static func build_cast_event(
	card: Dictionary,
	effect_card: Dictionary,
	core_runtime: Dictionary,
	card_chain: CardChainState,
	pending_core_skill_bonuses: Dictionary,
	card_play_token: int
) -> Dictionary:
	var core_skill := String(effect_card.get("core_skill", ""))
	var payload := build_payload(effect_card, core_runtime, card_chain, pending_core_skill_bonuses, true)
	if payload.is_empty():
		return {"core_skill": core_skill, "payload": {}, "event": null}
	payload["card_id"] = String(card.get("card_id", ""))
	payload["effect_card_id"] = String(effect_card.get("card_id", ""))
	payload["copy_previous_card_effect"] = bool(card.get("copy_previous_card_effect", false))
	payload["effect_id_list"] = (effect_card.get("effect_id_list", []) as Array).duplicate(true)
	payload["chain_multiplier"] = card_chain.chain_multiplier
	payload["card_play_token"] = card_play_token
	return {
		"core_skill": core_skill,
		"payload": payload,
		"event": build_event(core_skill, payload),
	}


static func build_preview_payload(
	effect_card: Dictionary, core_runtime: Dictionary, card_chain: CardChainState, pending_core_skill_bonuses: Dictionary
) -> Dictionary:
	return build_payload(effect_card, core_runtime, card_chain, pending_core_skill_bonuses, true)


static func build_payload(
	effect_card: Dictionary,
	core_runtime: Dictionary,
	card_chain: CardChainState,
	pending_core_skill_bonuses: Dictionary,
	include_pending_bonuses: bool
) -> Dictionary:
	var core_skill := String(effect_card.get("core_skill", ""))
	var payload := get_default_payload(core_skill)
	if payload.is_empty():
		return {}
	for key in core_runtime.keys():
		payload[key] = core_runtime[key]
	card_chain.apply_base_multiplier(core_skill, payload)
	card_chain.apply_inherited_effects(core_skill, payload)
	card_chain.apply_card_effect(effect_card, payload)
	if include_pending_bonuses:
		apply_pending_core_skill_bonuses_preview(core_skill, payload, pending_core_skill_bonuses)
	apply_fixed_projectile_count(effect_card, payload, card_chain)
	finalize_payload(core_skill, payload)
	return payload


static func build_event(core_skill: String, payload: Dictionary) -> CombatEvent:
	match core_skill:
		"thermobaric":
			return ThermobaricSkill.build_cast_event(&"player", payload)
		"dry_ice":
			return DryIceSkill.build_cast_event(&"player", payload)
		"electro_pierce":
			return ElectroPierceSkill.build_cast_event(&"player", payload)
	return null


static func get_default_payload(core_skill: String) -> Dictionary:
	match core_skill:
		"thermobaric":
			return ThermobaricSkill.default_payload()
		"dry_ice":
			return DryIceSkill.default_payload()
		"electro_pierce":
			return ElectroPierceSkill.default_payload()
	return {}


static func apply_fixed_projectile_count(card: Dictionary, payload: Dictionary, card_chain: CardChainState) -> void:
	if card_chain.is_chain_wildcard(card):
		return
	if not card.has("fixed_projectile_count"):
		return
	payload["projectile_count"] = maxi(1, int(card.get("fixed_projectile_count", 1)))


static func finalize_payload(core_skill: String, payload: Dictionary) -> void:
	match core_skill:
		"thermobaric":
			payload["spark_damage"] = float(payload.get("explosion_damage", 100.0)) * 0.35
		"dry_ice":
			payload["small_ice_damage"] = float(payload.get("damage", 90.0)) * 0.5
			if bool(payload.get("frostbite_enabled", false)):
				payload["frostbite_tick_damage"] = float(payload.get("damage", 90.0)) * 0.03 * 0.5
		"electro_pierce":
			payload["particle_damage"] = float(payload.get("pierce_damage", 100.0)) * 0.35


static func apply_pending_core_skill_bonuses_preview(
	core_skill: String, payload: Dictionary, pending_core_skill_bonuses: Dictionary
) -> void:
	var bonuses: Array = pending_core_skill_bonuses.get(core_skill, [])
	if bonuses.is_empty():
		return
	for bonus in bonuses:
		if bonus is Dictionary:
			apply_payload_bonus(payload, bonus as Dictionary)


static func apply_payload_bonus(payload: Dictionary, bonus: Dictionary) -> void:
	var muls: Dictionary = bonus.get("mul", {}) as Dictionary
	for key in muls.keys():
		payload[key] = float(payload.get(key, 0.0)) * float(muls[key])
	var adds: Dictionary = bonus.get("add", {}) as Dictionary
	for key in adds.keys():
		payload[key] = float(payload.get(key, 0.0)) + float(adds[key])
	var sets: Dictionary = bonus.get("set", {}) as Dictionary
	for key in sets.keys():
		payload[key] = sets[key]
