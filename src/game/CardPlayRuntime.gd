extends RefCounted
class_name CardPlayRuntime

const CORE_SKILL_PAYLOAD_BUILDER := preload("res://src/game/CoreSkillPayloadBuilder.gd")
const EFFECT_LOG_LIMIT := 16

var special_cooldown_until := {}
var pending_effect_log: Array = []
var pending_core_skill_bonuses: Dictionary = {}
var awarded_card_hit_bonuses: Dictionary = {}
var last_effect_card_for_copy: Dictionary = {}
var play_card_lock_remaining := 0.0
var last_card_play_failure := ""
var next_card_play_token := 1


func reset() -> void:
	special_cooldown_until.clear()
	pending_effect_log.clear()
	pending_core_skill_bonuses.clear()
	awarded_card_hit_bonuses.clear()
	last_effect_card_for_copy.clear()
	play_card_lock_remaining = 0.0
	last_card_play_failure = ""
	next_card_play_token = 1


func tick_cooldowns(delta: float, elapsed_time: float) -> void:
	play_card_lock_remaining = maxf(0.0, play_card_lock_remaining - delta)
	var expired_keys: Array = []
	for key in special_cooldown_until.keys():
		if float(special_cooldown_until[key]) <= elapsed_time:
			expired_keys.append(key)
	for key in expired_keys:
		special_cooldown_until.erase(key)


func is_copy_wildcard(card: Dictionary) -> bool:
	return bool(card.get("copy_previous_card_effect", false))


func resolve_effect_card_for_play(card: Dictionary) -> Dictionary:
	if is_copy_wildcard(card):
		return last_effect_card_for_copy.duplicate(true)
	return card.duplicate(true)


func remember_effect_card_for_copy(effect_card: Dictionary) -> void:
	if String(effect_card.get("core_skill", "")).is_empty():
		return
	last_effect_card_for_copy = effect_card.duplicate(true)


func apply_special_card_cooldown(card: Dictionary, cooldown_key: String, elapsed_time: float) -> void:
	var duration := float(card.get("special_cooldown", 0.0))
	if duration <= 0.0:
		return
	special_cooldown_until[cooldown_key] = maxf(float(special_cooldown_until.get(cooldown_key, 0.0)), elapsed_time + duration)


func is_special_card_on_cooldown(card: Dictionary, cooldown_key: String, elapsed_time: float) -> bool:
	if float(card.get("special_cooldown", 0.0)) <= 0.0:
		return false
	return float(special_cooldown_until.get(cooldown_key, 0.0)) > elapsed_time


func get_play_rejection(context: Dictionary) -> Dictionary:
	var index := int(context.get("index", -1))
	var hand_size := int(context.get("hand_size", 0))
	var is_playing := bool(context.get("is_playing", false))
	var card: Dictionary = context.get("card", {})
	var cooldown_key := String(context.get("cooldown_key", ""))
	var energy_cost := int(context.get("energy_cost", 0))
	var current_energy := float(context.get("current_energy", 0.0))
	var requires_combat_target := bool(context.get("requires_combat_target", false))
	var has_living_targets := bool(context.get("has_living_targets", false))
	var elapsed_time := float(context.get("elapsed_time", 0.0))
	var rejection := {}
	if not is_playing:
		rejection = {"reason": "not_player_turn", "message": "cannot play while battle is paused"}
	elif play_card_lock_remaining > 0.0:
		rejection = {"reason": "play_locked", "message": "card play resolving"}
	elif index < 0 or index >= hand_size:
		rejection = {"reason": "card_not_in_hand", "message": "card not in hand"}
	elif card.is_empty():
		rejection = {"reason": "missing_card_config", "message": "missing card config"}
	elif is_copy_wildcard(card) and last_effect_card_for_copy.is_empty():
		rejection = {"reason": "no_copy_source", "message": "no previous card to copy"}
	elif is_special_card_on_cooldown(card, cooldown_key, elapsed_time):
		rejection = {"reason": "card_cooldown", "message": "%s cooling down" % cooldown_key}
	elif current_energy < float(energy_cost):
		rejection = {"reason": "not_enough_energy", "message": "not enough energy"}
	elif requires_combat_target and not has_living_targets:
		rejection = {"reason": "no_target", "message": "没有可攻击目标"}
	return rejection


func record_card_baseline_execution(
	card: Dictionary,
	effect_card: Dictionary,
	play_source: String,
	energy_cost: int,
	chain_cost: int,
	core_runtime: Dictionary,
	card_chain: CardChainState,
	combat_runtime: CombatRuntime,
	combat_router: TriggerRouter,
	elapsed_time: float
) -> void:
	var build_result := CORE_SKILL_PAYLOAD_BUILDER.build_cast_event(
		card, effect_card, core_runtime, card_chain, pending_core_skill_bonuses, next_card_play_token
	)
	var core_skill := String(build_result.get("core_skill", ""))
	var cast_event: CombatEvent = build_result.get("event", null) as CombatEvent
	if not core_skill.is_empty():
		pending_core_skill_bonuses.erase(core_skill)
	next_card_play_token += 1
	var commands: Array = combat_runtime.route_event(cast_event, combat_router) if combat_runtime != null and cast_event != null else []
	var record := {
		"time": elapsed_time,
		"card_id": String(card.get("card_id", "")),
		"effect_card_id": String(effect_card.get("card_id", "")),
		"copy_previous_card_effect": is_copy_wildcard(card),
		"core_skill": core_skill,
		"cost": energy_cost,
		"energy_cost": energy_cost,
		"chain_cost": chain_cost,
		"chain_wildcard": card_chain.is_chain_wildcard(card),
		"chain_multiplier": card_chain.chain_multiplier,
		"baseline": core_runtime,
		"effect_id_list": (effect_card.get("effect_id_list", []) as Array).duplicate(true),
		"resolved": cast_event != null,
		"trigger_event": cast_event.to_dictionary() if cast_event != null else {},
		"commands": commands,
		"play_source": play_source,
		"reason": "event id trigger framework resolved baseline cast commands.",
	}
	pending_effect_log.append(record)
	while pending_effect_log.size() > EFFECT_LOG_LIMIT:
		pending_effect_log.remove_at(0)


func build_core_skill_target_preview_payload(effect_card: Dictionary, core_runtime: Dictionary, card_chain: CardChainState) -> Dictionary:
	return CORE_SKILL_PAYLOAD_BUILDER.build_preview_payload(effect_card, core_runtime, card_chain, pending_core_skill_bonuses)


func record_card_draw_result(draw_result: Dictionary) -> void:
	if draw_result.is_empty() or pending_effect_log.is_empty():
		return
	var index := pending_effect_log.size() - 1
	var record: Dictionary = pending_effect_log[index] as Dictionary
	record["draw_result"] = draw_result
	pending_effect_log[index] = record


func on_combat_projectile_hit_resolved(payload: Dictionary) -> void:
	var bonus: Dictionary = payload.get("on_hit_next_bonus", {}) as Dictionary
	if bonus.is_empty():
		return
	var token := int(payload.get("card_play_token", 0))
	if token > 0 and awarded_card_hit_bonuses.has(token):
		return
	var min_explosion_targets := int(payload.get("on_hit_bonus_min_explosion_targets", 0))
	if min_explosion_targets > 0:
		var explosion_targets: Array = payload.get("explosion_targets", []) as Array
		if explosion_targets.size() < min_explosion_targets:
			return
	var core_skill := String(bonus.get("core_skill", payload.get("skill_id", "")))
	_queue_next_core_skill_bonus(core_skill, bonus)
	if token > 0:
		awarded_card_hit_bonuses[token] = true


func _queue_next_core_skill_bonus(core_skill: String, bonus: Dictionary) -> void:
	var bonuses: Array = pending_core_skill_bonuses.get(core_skill, [])
	bonuses.append(bonus.duplicate(true))
	pending_core_skill_bonuses[core_skill] = bonuses
