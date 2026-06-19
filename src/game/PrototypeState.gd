extends Node

enum Phase { READY, PLAYING, LEVEL_UP, WON, LOST }

const CONCEPT_ID := "starter-template"
const STARTER_CONCEPT_ID := CONCEPT_ID
const DEFAULT_WALL_HP := 3000
const MONSTER_ATTACK_RANGE_Y := 1040.0
const MAX_LEVEL := 20
const INITIAL_HAND_COUNT := 3
const HAND_LIMIT := 4
const REFILL_INTERVAL := 1.5
const DISCARD_COOLDOWN := 20.0
const CARD_PLAY_LOCK_TIME := 0.18
const LEVEL_REWARD_CHOICE_COUNT := 3
const INITIAL_ENERGY := 0.0
const INITIAL_ENERGY_REGEN := 1.0
const INITIAL_AMMO := 30
const INITIAL_FIRE_INTERVAL := 0.5
const INITIAL_RELOAD_TIME := 2.0
const CARD_CONFIG_JSON_PATH := "res://assets/data/cards/card_configs.json"
const CARD_TEXT_CSV_PATH := "res://assets/data/cards/card_texts.csv"
const UPGRADE_TEXT_CSV_PATH := "res://assets/data/upgrades/upgrade_texts.csv"
const CARD_TEXT_JSON_PATH := "res://assets/data/cards/card_texts.json"
const UPGRADE_TEXT_JSON_PATH := "res://assets/data/upgrades/upgrade_texts.json"
const DEFAULT_UPGRADE_POOL_JSON_PATH := "res://assets/data/upgrades/default_upgrade_pool.json"
const CARD_CHAIN_PARAMS_CSV_PATH := "res://assets/data/cards/card_chain_params.csv"
const CARD_CHAIN_PARAMS_JSON_PATH := "res://assets/data/cards/card_chain_params.json"
const INITIAL_GENERIC_CARD_POOL := [
	"starter_steady_aim",
	"starter_infinite_fire",
	"starter_first_aid",
	"starter_tactical_reload",
	"starter_weakpoint_mark",
	"starter_temporary_shield",
	"starter_rest_and_ready",
	"starter_flash_grenade",
	"starter_growth_plan",
]
const UPGRADE_POOL_LOADER := preload("res://src/game/UpgradePoolLoader.gd")
const CARD_TEXT_LOADER := preload("res://src/game/CardTextLoader.gd")
const CARD_CONFIG_LOADER := preload("res://src/game/CardConfigLoader.gd")
const CARD_CHAIN_PARAM_RULES := preload("res://src/game/CardChainParamRules.gd")
const CARD_DECK_STATE := preload("res://src/game/CardDeckState.gd")
const CARD_PLAY_RUNTIME := preload("res://src/game/CardPlayRuntime.gd")
const CARD_CHAIN_STATE := preload("res://src/game/CardChainState.gd")
const CARD_DRAW_RESOLVER := preload("res://src/game/CardDrawResolver.gd")
const CARD_SNAPSHOT_BUILDER := preload("res://src/game/CardSnapshotBuilder.gd")
const GAME_SNAPSHOT_BUILDER := preload("res://src/game/GameSnapshotBuilder.gd")
const GUN_RUNTIME_STATE := preload("res://src/game/GunRuntimeState.gd")
const LEVEL_REWARD_RUNTIME := preload("res://src/game/LevelRewardRuntime.gd")
const STARTER_CARD_EFFECT_RESOLVER := preload("res://src/game/StarterCardEffectResolver.gd")
const PROGRESS_RULES := preload("res://src/game/ProgressRules.gd")
const WAVE_RUNTIME_STATE := preload("res://src/game/WaveRuntimeState.gd")

signal phase_changed(new_phase: Phase)
signal status_changed(new_status: String)
signal score_changed(new_score: int)
signal hp_changed(new_hp: int)
signal time_changed(new_time: float)
signal state_changed(snapshot: Dictionary)
signal feedback_requested(kind: String, payload: Dictionary)

var phase: Phase = Phase.READY
var concept_id := CONCEPT_ID
var status_text := "init battle rules ready"
var elapsed_time := 0.0
var score := 0
var hp := DEFAULT_WALL_HP
var wall_hp_max := DEFAULT_WALL_HP
var level := 1
var exp := 0
var exp_max := 60
var current_energy := INITIAL_ENERGY
var energy_regen_per_sec := INITIAL_ENERGY_REGEN
var card_deck: CardDeckState = CARD_DECK_STATE.new()
var hand_limit: int:
	get:
		return card_deck.hand_limit
	set(value):
		card_deck.hand_limit = value
var refill_interval: float:
	get:
		return card_deck.refill_interval
	set(value):
		card_deck.refill_interval = value
var refill_timer: float:
	get:
		return card_deck.refill_timer
	set(value):
		card_deck.refill_timer = value
var discard_cooldown_remaining: float:
	get:
		return card_deck.discard_cooldown_remaining
	set(value):
		card_deck.discard_cooldown_remaining = value
var draw_pile: Array:
	get:
		return card_deck.draw_pile
	set(value):
		card_deck.draw_pile = value
var discard_pile: Array:
	get:
		return card_deck.discard_pile
	set(value):
		card_deck.discard_pile = value
var hand_card_ids: Array:
	get:
		return card_deck.hand_card_ids
	set(value):
		card_deck.hand_card_ids = value
var card_configs: Dictionary = {}
var wave_state: WaveRuntimeState = WAVE_RUNTIME_STATE.new()
var wave_configs: Array:
	get:
		return wave_state.wave_configs
	set(value):
		wave_state.wave_configs = value
var next_wave_index: int:
	get:
		return wave_state.next_wave_index
	set(value):
		wave_state.next_wave_index = value
var active_spawn_log: Array:
	get:
		return wave_state.active_spawn_log
	set(value):
		wave_state.active_spawn_log = value
var boss_spawned: bool:
	get:
		return wave_state.boss_spawned
	set(value):
		wave_state.boss_spawned = value
var boss_defeated: bool:
	get:
		return wave_state.boss_defeated
	set(value):
		wave_state.boss_defeated = value
var gun_state: GunRuntimeState = GUN_RUNTIME_STATE.new()
var gun_runtime: Dictionary:
	get:
		return gun_state.runtime
	set(value):
		gun_state.runtime = value
var ammo: int:
	get:
		return gun_state.ammo
	set(value):
		gun_state.ammo = value
var is_reloading: bool:
	get:
		return gun_state.is_reloading
	set(value):
		gun_state.is_reloading = value
var reload_timer: float:
	get:
		return gun_state.reload_timer
	set(value):
		gun_state.reload_timer = value
var fire_timer: float:
	get:
		return gun_state.fire_timer
	set(value):
		gun_state.fire_timer = value
var card_chain: CardChainState = CARD_CHAIN_STATE.new()
var card_play_runtime: CardPlayRuntime = CARD_PLAY_RUNTIME.new()
var special_cooldown_until: Dictionary:
	get:
		return card_play_runtime.special_cooldown_until
	set(value):
		card_play_runtime.special_cooldown_until = value
var level_rewards: LevelRewardRuntime = LEVEL_REWARD_RUNTIME.new()
var upgrade_choices: Array:
	get:
		return level_rewards.upgrade_choices
	set(value):
		level_rewards.upgrade_choices = value
var upgrade_pick_counts: Dictionary:
	get:
		return level_rewards.upgrade_pick_counts
	set(value):
		level_rewards.upgrade_pick_counts = value
var pending_effect_log: Array:
	get:
		return card_play_runtime.pending_effect_log
	set(value):
		card_play_runtime.pending_effect_log = value
var pending_core_skill_bonuses: Dictionary:
	get:
		return card_play_runtime.pending_core_skill_bonuses
	set(value):
		card_play_runtime.pending_core_skill_bonuses = value
var awarded_card_hit_bonuses: Dictionary:
	get:
		return card_play_runtime.awarded_card_hit_bonuses
	set(value):
		card_play_runtime.awarded_card_hit_bonuses = value
var last_effect_card_for_copy: Dictionary:
	get:
		return card_play_runtime.last_effect_card_for_copy
	set(value):
		card_play_runtime.last_effect_card_for_copy = value
var combat_router: TriggerRouter = null
var combat_runtime: CombatRuntime = null
var play_card_lock_remaining: float:
	get:
		return card_play_runtime.play_card_lock_remaining
	set(value):
		card_play_runtime.play_card_lock_remaining = value
var last_card_play_failure: String:
	get:
		return card_play_runtime.last_card_play_failure
	set(value):
		card_play_runtime.last_card_play_failure = value
var next_card_play_token: int:
	get:
		return card_play_runtime.next_card_play_token
	set(value):
		card_play_runtime.next_card_play_token = value
var upgrade_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var wall_shield := 0
var wall_shield_remaining := 0.0
var starter_growth_plays := 0
var starter_growth_damage_bonus := 0.0
var next_card_acquire_event_serial: int:
	get:
		return level_rewards.next_card_acquire_event_serial
	set(value):
		level_rewards.next_card_acquire_event_serial = value
var last_card_acquire_event: Dictionary:
	get:
		return level_rewards.last_card_acquire_event
	set(value):
		level_rewards.last_card_acquire_event = value


func reset() -> void:
	upgrade_rng.randomize()
	phase = Phase.PLAYING
	elapsed_time = 0.0
	score = 0
	wall_hp_max = DEFAULT_WALL_HP
	hp = wall_hp_max
	level = 1
	exp = 0
	exp_max = 1
	current_energy = INITIAL_ENERGY
	energy_regen_per_sec = INITIAL_ENERGY_REGEN
	card_deck.reset(HAND_LIMIT, REFILL_INTERVAL)
	wave_state.reset()
	card_chain.reset()
	card_play_runtime.reset()
	level_rewards.reset()
	wall_shield = 0
	wall_shield_remaining = 0.0
	starter_growth_plays = 0
	starter_growth_damage_bonus = 0.0
	_init_cards()
	_init_waves()
	exp_max = PROGRESS_RULES.get_exp_required_for_level(wave_configs, level)
	_init_gun_runtime()
	_init_combat_router()
	_init_combat_runtime()
	_update_waves()
	card_deck.refill_hand_to_limit()
	status_text = "init battle rules ready"
	_emit_all()


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if phase == Phase.LEVEL_UP or phase == Phase.WON or phase == Phase.LOST:
		_tick_cooldowns(delta)
		_emit_all()
		return
	elapsed_time += delta
	_tick_cooldowns(delta)
	_tick_starter_card_effects(delta)
	_update_energy(delta)
	_update_refill(delta)
	_update_waves()
	if combat_runtime != null:
		combat_runtime.tick(delta, combat_router)
	_gun_tick(delta)
	_check_battle_end()
	_emit_all()


func try_play_hand_card(index: int, play_source: String = "hand_slot") -> bool:
	return _try_play_hand_index(index, play_source)


func reorder_hand_card(from_index: int, to_index: int) -> bool:
	if phase != Phase.PLAYING or play_card_lock_remaining > 0.0:
		return false
	if not card_deck.reorder_hand_card(from_index, to_index):
		return false
	_emit_all()
	return true


func _try_play_hand_index(index: int, play_source: String) -> bool:
	var rejection := _card_play_rejection_for_hand_index(index)
	if not rejection.is_empty():
		return _reject_card_play(String(rejection.get("reason", "")), String(rejection.get("message", "")))
	var card_id := String(hand_card_ids[index])
	var card := get_card_config(card_id)
	var special_cooldown_key := CARD_SNAPSHOT_BUILDER.get_card_same_name_key(card, card_id, card_chain)
	var energy_cost := card_chain.get_energy_cost_for_card(card)
	var chain_cost := card_chain.get_chain_cost_for_card(card)
	var effect_card := _resolve_effect_card_for_play(card)
	current_energy -= float(energy_cost)
	card_chain.on_card_played_for_card(card)
	_record_card_baseline_execution(card, effect_card, play_source, energy_cost, chain_cost)
	_record_card_draw_result(_apply_card_draw_effect(card))
	var exhaust_card := _apply_starter_card_effect(card)
	card_chain.record_card_effect(effect_card)
	_remember_effect_card_for_copy(effect_card)
	_apply_special_card_cooldown(card, special_cooldown_key)
	if exhaust_card:
		card_deck.remove_hand_index(index)
	else:
		card_deck.move_hand_index_to_discard(index)
	card_deck.refill_timer = 0.0
	play_card_lock_remaining = CARD_PLAY_LOCK_TIME
	last_card_play_failure = ""
	status_text = "played %s" % String(card.get("card_name", card_id))
	_emit_all()
	return true


func _card_play_rejection_for_hand_index(index: int) -> Dictionary:
	var card_id := ""
	var card := {}
	var special_cooldown_key := ""
	var energy_cost := 0
	var requires_combat_target := false
	var has_living_targets := false
	if index >= 0 and index < hand_card_ids.size():
		card_id = String(hand_card_ids[index])
		card = get_card_config(card_id)
		special_cooldown_key = CARD_SNAPSHOT_BUILDER.get_card_same_name_key(card, card_id, card_chain)
		energy_cost = card_chain.get_energy_cost_for_card(card)
		requires_combat_target = _card_requires_combat_target(card)
		has_living_targets = combat_runtime != null and combat_runtime.has_living_targets()
	return (
		card_play_runtime
		. get_play_rejection(
			{
				"index": index,
				"is_playing": phase == Phase.PLAYING,
				"hand_size": hand_card_ids.size(),
				"card": card,
				"cooldown_key": special_cooldown_key,
				"energy_cost": energy_cost,
				"current_energy": current_energy,
				"requires_combat_target": requires_combat_target,
				"has_living_targets": has_living_targets,
				"elapsed_time": elapsed_time,
			}
		)
	)


func play_hand_card(index: int) -> bool:
	return try_play_hand_card(index, "hand_slot")


func discard_hand() -> bool:
	if phase != Phase.PLAYING:
		return false
	if play_card_lock_remaining > 0.0:
		status_text = "card play resolving"
		_emit_all()
		return false
	if card_deck.discard_cooldown_remaining > 0.0:
		status_text = "discard cooling down"
		_emit_all()
		return false
	card_deck.discard_hand(DISCARD_COOLDOWN)
	card_chain.break_chain()
	card_deck.refill_hand_to_limit()
	status_text = "discarded hand"
	_emit_all()
	return true


func grant_exp(amount: int) -> void:
	if amount <= 0 or phase == Phase.WON or phase == Phase.LOST:
		return
	exp += amount
	score += amount
	_resolve_level_progress()
	_emit_all()


func grant_kill_progress(score_amount: int) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	exp += 1
	score += maxi(0, score_amount)
	_resolve_level_progress()
	_emit_all()


func choose_level_reward(index: int) -> bool:
	if phase != Phase.LEVEL_UP:
		return false
	var reward_result := level_rewards.choose(index, _get_reward_context())
	if not bool(reward_result.get("accepted", false)):
		return false
	wall_hp_max = int(reward_result.get("wall_hp_max", wall_hp_max))
	hp = int(reward_result.get("hp", hp))
	energy_regen_per_sec = float(reward_result.get("energy_regen_per_sec", energy_regen_per_sec))
	phase = Phase.PLAYING
	status_text = "upgrade selected"
	_resolve_level_progress()
	_emit_all()
	return true


func apply_wall_damage(amount: int) -> void:
	if amount <= 0 or phase == Phase.WON or phase == Phase.LOST:
		return
	var remaining := amount
	if wall_shield > 0:
		var absorbed := mini(wall_shield, remaining)
		wall_shield -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hp = maxi(0, hp - remaining)
	_check_battle_end()
	_emit_all()


func mark_boss_defeated() -> void:
	if not wave_state.mark_boss_defeated():
		return
	_check_battle_end()
	_emit_all()


func get_card_config(card_id: String) -> Dictionary:
	return (card_configs.get(card_id, {}) as Dictionary).duplicate(true)


func get_energy_cap_by_level(target_level: int) -> int:
	if target_level >= 20:
		return 11
	if target_level >= 15:
		return 9
	if target_level >= 10:
		return 7
	if target_level >= 5:
		return 5
	return 3


func get_snapshot() -> Dictionary:
	return GAME_SNAPSHOT_BUILDER.build(self, MONSTER_ATTACK_RANGE_Y, INITIAL_AMMO, phase == Phase.PLAYING)


func _init_cards() -> void:
	card_configs.clear()
	var source_cards: Array = CARD_CONFIG_LOADER.load_configs(CARD_CONFIG_JSON_PATH)
	if ContentUnits.card_configs.size() > 0:
		source_cards = _to_dictionary_array(ContentUnits.card_configs)
	source_cards = CARD_TEXT_LOADER.apply_overrides(source_cards, CARD_TEXT_CSV_PATH, CARD_TEXT_JSON_PATH)
	source_cards = CARD_CHAIN_PARAM_RULES.apply_overrides(source_cards, CARD_CHAIN_PARAMS_CSV_PATH, CARD_CHAIN_PARAMS_JSON_PATH)
	for card in source_cards:
		if not (card is Dictionary):
			continue
		var card_data := (card as Dictionary).duplicate(true)
		card_configs[String(card_data.get("card_id", ""))] = card_data
	var starter_pool := []
	for card_id in INITIAL_GENERIC_CARD_POOL:
		if card_configs.has(card_id):
			starter_pool.append(card_id)
	card_deck.seed_draw_pile(CARD_DRAW_RESOLVER.pick_random_card_ids(starter_pool, INITIAL_HAND_COUNT, upgrade_rng))


func _load_upgrade_pool() -> Array:
	var csv_pool := UPGRADE_POOL_LOADER.load_pool(UPGRADE_TEXT_CSV_PATH, UPGRADE_TEXT_JSON_PATH)
	if not csv_pool.is_empty():
		return csv_pool
	return UPGRADE_POOL_LOADER.load_pool("", DEFAULT_UPGRADE_POOL_JSON_PATH)


func _init_waves() -> void:
	wave_state.load_waves(ContentUnits.get_default_wave_configs(), ContentUnits.wave_configs)


func _init_gun_runtime() -> void:
	gun_state.reset(INITIAL_AMMO, INITIAL_FIRE_INTERVAL, INITIAL_RELOAD_TIME)


func _init_combat_router() -> void:
	combat_router = CombatSkillRegistry.build_default_router()


func _init_combat_runtime() -> void:
	combat_runtime = CombatRuntime.new()
	combat_runtime.setup(self)


func _to_dictionary_array(source: Array) -> Array:
	var result: Array = []
	for item in source:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _tick_cooldowns(delta: float) -> void:
	card_deck.tick_cooldowns(delta)
	card_play_runtime.tick_cooldowns(delta, elapsed_time)


func _tick_starter_card_effects(delta: float) -> void:
	wall_shield_remaining = maxf(0.0, wall_shield_remaining - delta)
	if wall_shield_remaining <= 0.0:
		wall_shield = 0
	gun_state.tick_buffs(delta)


func _update_energy(delta: float) -> void:
	var energy_cap := float(get_energy_cap_by_level(level))
	current_energy = minf(energy_cap, current_energy + energy_regen_per_sec * delta)


func _update_refill(delta: float) -> void:
	card_deck.update_refill(delta)


func _update_waves() -> void:
	var wave_status := wave_state.update(elapsed_time, combat_runtime)
	if not wave_status.is_empty():
		status_text = wave_status


func _gun_tick(delta: float) -> void:
	var tick_result := gun_state.tick_fire(delta, combat_runtime, combat_router, elapsed_time)
	if tick_result.has("status_text"):
		status_text = String(tick_result.get("status_text", status_text))


func _get_stage_name() -> String:
	var level_config := ContentUnits.get_active_level_config()
	return String(level_config.get("stage_name", "1-1 教堂广场"))


func _get_level_objective() -> String:
	var level_config := ContentUnits.get_active_level_config()
	return String(level_config.get("objective", "目标：守住城墙，清完20波怪物"))


func _apply_special_card_cooldown(card: Dictionary, cooldown_key: String) -> void:
	card_play_runtime.apply_special_card_cooldown(card, cooldown_key, elapsed_time)


func _is_special_card_on_cooldown(card: Dictionary, cooldown_key: String) -> bool:
	return card_play_runtime.is_special_card_on_cooldown(card, cooldown_key, elapsed_time)


func _record_card_baseline_execution(
	card: Dictionary, effect_card: Dictionary, play_source: String, energy_cost: int, chain_cost: int
) -> void:
	var core_skill := String(effect_card.get("core_skill", ""))
	var core_runtime := _get_core_skill_runtime(core_skill)
	card_play_runtime.record_card_baseline_execution(
		card, effect_card, play_source, energy_cost, chain_cost, core_runtime, card_chain, combat_runtime, combat_router, elapsed_time
	)


func _apply_card_draw_effect(card: Dictionary) -> Dictionary:
	return card_deck.apply_card_draw_effect(card, card_configs)


func _apply_starter_card_effect(card: Dictionary) -> bool:
	var effect_result := STARTER_CARD_EFFECT_RESOLVER.apply(
		card,
		gun_state,
		combat_runtime,
		wall_hp_max,
		hp,
		wall_shield,
		wall_shield_remaining,
		starter_growth_plays,
		starter_growth_damage_bonus,
		card_chain.chain_multiplier
	)
	hp = int(effect_result.get("hp", hp))
	wall_shield = int(effect_result.get("wall_shield", wall_shield))
	wall_shield_remaining = float(effect_result.get("wall_shield_remaining", wall_shield_remaining))
	starter_growth_plays = int(effect_result.get("starter_growth_plays", starter_growth_plays))
	starter_growth_damage_bonus = float(effect_result.get("starter_growth_damage_bonus", starter_growth_damage_bonus))
	return bool(effect_result.get("exhaust_card", false))


func _record_card_draw_result(draw_result: Dictionary) -> void:
	card_play_runtime.record_card_draw_result(draw_result)


func _resolve_effect_card_for_play(card: Dictionary) -> Dictionary:
	return card_play_runtime.resolve_effect_card_for_play(card)


func _card_requires_combat_target(card: Dictionary) -> bool:
	var effect_card := _resolve_effect_card_for_play(card)
	if STARTER_CARD_EFFECT_RESOLVER.requires_combat_target(effect_card):
		return true
	return not String(effect_card.get("core_skill", "")).is_empty()


func _is_copy_wildcard(card: Dictionary) -> bool:
	return card_play_runtime.is_copy_wildcard(card)


func _remember_effect_card_for_copy(effect_card: Dictionary) -> void:
	card_play_runtime.remember_effect_card_for_copy(effect_card)


func _get_reward_context() -> Dictionary:
	return {
		"card_configs": card_configs,
		"card_deck": card_deck,
		"gun_runtime": gun_runtime,
		"wall_hp_max": wall_hp_max,
		"hp": hp,
		"energy_regen_per_sec": energy_regen_per_sec,
		"card_chain": card_chain,
		"special_cooldown_until": special_cooldown_until,
		"elapsed_time": elapsed_time,
	}


func _on_combat_projectile_hit_resolved(payload: Dictionary, _commands: Array) -> void:
	card_play_runtime.on_combat_projectile_hit_resolved(payload)


func _begin_level_up() -> void:
	phase = Phase.LEVEL_UP
	level_rewards.begin_level_up(_load_upgrade_pool(), card_configs, card_deck, card_chain, upgrade_rng, LEVEL_REWARD_CHOICE_COUNT)
	status_text = "level up"


func _get_core_skill_runtime(core_skill: String) -> Dictionary:
	return gun_state.get_core_skill_runtime(core_skill)


func _get_core_skill_snapshot() -> Dictionary:
	return gun_state.get_core_skill_snapshot()


func _reject_card_play(reason: String, message: String) -> bool:
	last_card_play_failure = reason
	status_text = message
	_emit_all()
	return false


func _resolve_level_progress() -> void:
	while level < MAX_LEVEL and exp >= exp_max:
		exp -= exp_max
		level += 1
		exp_max = PROGRESS_RULES.get_exp_required_for_level(wave_configs, level)
		current_energy = minf(current_energy, float(get_energy_cap_by_level(level)))
		_begin_level_up()
		if phase == Phase.LEVEL_UP:
			break


func _check_battle_end() -> void:
	if hp <= 0:
		phase = Phase.LOST
		status_text = "wall destroyed"
	elif _is_battle_cleared():
		phase = Phase.WON
		status_text = "20 waves cleared"


func _is_battle_cleared() -> bool:
	return wave_state.is_battle_cleared(combat_runtime)


func _emit_all() -> void:
	phase_changed.emit(phase)
	status_changed.emit(status_text)
	score_changed.emit(score)
	hp_changed.emit(hp)
	time_changed.emit(elapsed_time)
	state_changed.emit(get_snapshot())
