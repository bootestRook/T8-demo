extends RefCounted
class_name GameSnapshotSections

const CARD_SNAPSHOT_BUILDER := preload("res://src/game/CardSnapshotBuilder.gd")


static func core(state, monster_attack_range_y: float) -> Dictionary:
	var wave_total: int = state.wave_configs.size()
	var wave_current := 0
	if wave_total > 0:
		wave_current = maxi(1, mini(state.next_wave_index, wave_total))
	return {
		"concept_id": state.concept_id,
		"phase": state.phase,
		"status_text": state.status_text,
		"elapsed_time": state.elapsed_time,
		"score": state.score,
		"hp": state.hp,
		"objective": state._get_level_objective(),
		"hint": "点击或拖拽手牌释放技能",
		"stage_name": state._get_stage_name(),
		"wave_current": wave_current,
		"wave_total": wave_total,
		"monster_attack_range_y": monster_attack_range_y,
		"hero_name": "艾琳",
	}


static func progression(state) -> Dictionary:
	return {
		"level": state.level,
		"exp": state.exp,
		"exp_max": state.exp_max,
		"wall_hp": state.hp,
		"wall_hp_max": state.wall_hp_max,
		"wall_shield": state.wall_shield,
		"wall_shield_remaining": state.wall_shield_remaining,
		"starter_growth_stacks": state.starter_growth_plays,
		"starter_growth_max": 30,
	}


static func combat_resources(state, initial_ammo: int) -> Dictionary:
	return {
		"energy": int(state.current_energy),
		"energy_float": state.current_energy,
		"energy_max": state.get_energy_cap_by_level(state.level),
		"energy_regen_per_sec": state.energy_regen_per_sec,
		"ultimate_energy": state.current_energy,
		"ammo": state.ammo,
		"ammo_max": int(state.gun_runtime.get("max_ammo", initial_ammo)),
		"is_reloading": state.is_reloading,
		"reload_timer": state.reload_timer,
		"gun_runtime": state.gun_runtime.duplicate(true),
		"core_skill_runtime": state._get_core_skill_snapshot(),
	}


static func card_piles(state) -> Dictionary:
	return {
		"draw_count": state.draw_pile.size(),
		"discard_count": state.discard_pile.size(),
		"discard_cooldown": state.discard_cooldown_remaining,
		"hand_cards":
		CARD_SNAPSHOT_BUILDER.get_hand_card_snapshots(
			state.hand_card_ids, state.card_configs, state.card_chain, state.special_cooldown_until, state.elapsed_time
		),
		"draw_pile_cards":
		CARD_SNAPSHOT_BUILDER.get_pile_card_snapshots(
			state.draw_pile, state.card_configs, state.card_chain, {}, state.elapsed_time, "draw"
		),
		"discard_pile_cards":
		CARD_SNAPSHOT_BUILDER.get_pile_card_snapshots(
			state.discard_pile, state.card_configs, state.card_chain, {}, state.elapsed_time, "discard"
		),
		"card_acquire_event": state.last_card_acquire_event.duplicate(true),
	}


static func card_play(state, is_playing: bool) -> Dictionary:
	return {
		"can_play_cards": is_playing and state.play_card_lock_remaining <= 0.0,
		"card_play_locked": state.play_card_lock_remaining > 0.0,
		"card_play_lock_remaining": state.play_card_lock_remaining,
		"last_card_play_failure": state.last_card_play_failure,
	}


static func chain(state) -> Dictionary:
	return {
		"chain_multiplier": state.card_chain.chain_multiplier,
		"highest_chain_multiplier": state.card_chain.highest_chain_multiplier,
		"chain_active": state.card_chain.has_active_chain,
		"wildcard_bridge_active": state.card_chain.wildcard_bridge_active,
		"last_positive_cost": state.card_chain.last_chain_cost,
		"last_chain_cost": state.card_chain.last_chain_cost,
		"next_wildcard_chain_cost": state.card_chain.get_next_wildcard_chain_cost(),
		"same_name_cooldowns": {},
		"special_card_cooldowns": state.special_cooldown_until.duplicate(true),
	}


static func runtime_logs(state) -> Dictionary:
	return {
		"upgrade_choices": state.upgrade_choices.duplicate(true),
		"active_spawn_log": state.active_spawn_log.duplicate(true),
		"boss_spawned": state.boss_spawned,
		"boss_defeated": state.boss_defeated,
		"pending_effect_log": state.pending_effect_log.duplicate(true),
	}


static func merge_combat_snapshot(snapshot: Dictionary, state) -> void:
	if state.combat_runtime == null:
		return
	var combat_snapshot: Dictionary = state.combat_runtime.get_snapshot()
	for key in combat_snapshot.keys():
		snapshot[key] = combat_snapshot[key]
