extends RefCounted
class_name StarterCardEffectResolver

const CARD_CHAIN_PARAM_RULES := preload("res://src/game/CardChainParamRules.gd")


static func apply(
	card: Dictionary,
	gun_state: GunRuntimeState,
	combat_runtime: CombatRuntime,
	wall_hp_max: int,
	hp: int,
	wall_shield: int,
	wall_shield_remaining: float,
	starter_growth_plays: int,
	starter_growth_damage_bonus: float,
	chain_multiplier: int
) -> Dictionary:
	var result := {
		"hp": hp,
		"wall_shield": wall_shield,
		"wall_shield_remaining": wall_shield_remaining,
		"starter_growth_plays": starter_growth_plays,
		"starter_growth_damage_bonus": starter_growth_damage_bonus,
		"exhaust_card": false,
	}
	var effect := String(card.get("starter_effect", ""))
	match effect:
		"gun_damage_timed":
			gun_state.apply_timed_buff(_scaled_float(card, "damage_mul", chain_multiplier, 1.0), 1.0, float(card.get("duration", 0.0)))
		"infinite_ammo":
			gun_state.extend_infinite_ammo(_scaled_float(card, "duration", chain_multiplier, 0.0))
		"heal_missing_wall":
			var missing_hp := maxi(0, wall_hp_max - hp)
			result["hp"] = mini(
				wall_hp_max, hp + int(float(missing_hp) * _scaled_float(card, "missing_hp_ratio", chain_multiplier, 0.0) + 0.5)
			)
		"reload_ammo_ratio":
			gun_state.reload_ammo_ratio(_scaled_float(card, "ammo_ratio", chain_multiplier, 0.0))
		"weakpoint_mark":
			_apply_weakpoint_mark(card, combat_runtime, chain_multiplier)
		"wall_shield":
			result["wall_shield"] = maxi(
				wall_shield, int(float(wall_hp_max) * _scaled_float(card, "wall_hp_ratio", chain_multiplier, 0.0) + 0.5)
			)
			result["wall_shield_remaining"] = maxf(wall_shield_remaining, float(card.get("duration", 0.0)))
		"rest_then_buff":
			gun_state.queue_focus_buff(
				float(card.get("rest_duration", 0.0)),
				_scaled_float(card, "damage_mul", chain_multiplier, 1.0),
				float(card.get("fire_interval_mul", 1.0)),
				float(card.get("duration", 0.0))
			)
		"flash_stun":
			_apply_flash_stun(card, combat_runtime, chain_multiplier)
		"growth_plan":
			_apply_growth_plan(card, gun_state, result, chain_multiplier)
	return result


static func requires_combat_target(card: Dictionary) -> bool:
	var starter_effect := String(card.get("starter_effect", ""))
	return starter_effect == "weakpoint_mark" or starter_effect == "flash_stun"


static func _apply_weakpoint_mark(card: Dictionary, combat_runtime: CombatRuntime, chain_multiplier: int) -> void:
	if combat_runtime == null:
		return
	combat_runtime.apply_status_to_nearest_wall(
		_scaled_int(card, "target_count", chain_multiplier, 1),
		"weakpoint",
		_scaled_float(card, "duration", chain_multiplier, 0.0),
		{"damage_taken_mul": _scaled_float(card, "damage_taken_mul", chain_multiplier, 1.0), "vfx_kind": "weakpoint"}
	)


static func _apply_flash_stun(card: Dictionary, combat_runtime: CombatRuntime, chain_multiplier: int) -> void:
	if combat_runtime == null:
		return
	combat_runtime.apply_status_to_all_living("stun", _scaled_float(card, "duration", chain_multiplier, 0.0), {"vfx_kind": "flash"})


static func _apply_growth_plan(card: Dictionary, gun_state: GunRuntimeState, result: Dictionary, chain_multiplier: int) -> void:
	var max_plays := maxi(1, int(card.get("max_plays", 30)))
	var growth_plays := int(result.get("starter_growth_plays", 0))
	var growth_damage_bonus := float(result.get("starter_growth_damage_bonus", 0.0))
	if growth_plays < max_plays:
		growth_plays += 1
		growth_damage_bonus += _scaled_float(card, "damage_add_mul", chain_multiplier, 0.0)
	result["starter_growth_plays"] = growth_plays
	result["starter_growth_damage_bonus"] = growth_damage_bonus
	gun_state.set_base_damage_growth_mul(1.0 + growth_damage_bonus)
	result["exhaust_card"] = bool(card.get("exhaust_at_max", false)) and growth_plays >= max_plays


static func _scaled_float(card: Dictionary, field: String, chain_multiplier: int, fallback: float) -> float:
	return float(CARD_CHAIN_PARAM_RULES.scaled_runtime_value(card, field, chain_multiplier, card.get(field, fallback)))


static func _scaled_int(card: Dictionary, field: String, chain_multiplier: int, fallback: int) -> int:
	return int(CARD_CHAIN_PARAM_RULES.scaled_runtime_value(card, field, chain_multiplier, card.get(field, fallback)))
