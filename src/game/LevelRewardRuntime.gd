extends RefCounted
class_name LevelRewardRuntime

const UPGRADE_RESOLVER := preload("res://src/game/UpgradeResolver.gd")
const CARD_SNAPSHOT_BUILDER := preload("res://src/game/CardSnapshotBuilder.gd")

var upgrade_choices: Array = []
var upgrade_pick_counts: Dictionary = {}
var next_card_acquire_event_serial := 1
var last_card_acquire_event: Dictionary = {}


func reset() -> void:
	upgrade_choices.clear()
	upgrade_pick_counts.clear()
	next_card_acquire_event_serial = 1
	last_card_acquire_event.clear()


func begin_level_up(
	upgrade_pool: Array,
	card_configs: Dictionary,
	card_deck: CardDeckState,
	card_chain: CardChainState,
	rng: RandomNumberGenerator,
	choice_count: int
) -> void:
	upgrade_choices = UPGRADE_RESOLVER.build_upgrade_choices(
		upgrade_pool, card_configs, card_deck, upgrade_pick_counts, card_chain, rng, choice_count
	)


func choose(index: int, context: Dictionary) -> Dictionary:
	var result := {"accepted": false}
	if index < 0 or index >= upgrade_choices.size():
		return result
	var card_deck: CardDeckState = context.get("card_deck", null) as CardDeckState
	if card_deck == null:
		return result
	var selected_upgrade: Dictionary = upgrade_choices[index] as Dictionary
	var upgrade_result := UPGRADE_RESOLVER.apply_upgrade(
		selected_upgrade,
		context.get("card_configs", {}),
		card_deck,
		context.get("gun_runtime", {}),
		int(context.get("wall_hp_max", 1)),
		int(context.get("hp", 0)),
		float(context.get("energy_regen_per_sec", 1.0)),
		card_deck.refill_interval
	)
	card_deck.refill_interval = float(upgrade_result.get("refill_interval", card_deck.refill_interval))
	_record_card_acquire_event(upgrade_result.get("card_acquire_event", {}), context)
	UPGRADE_RESOLVER.record_upgrade_pick(selected_upgrade, upgrade_pick_counts)
	upgrade_choices.clear()
	result["accepted"] = true
	result["wall_hp_max"] = int(upgrade_result.get("wall_hp_max", int(context.get("wall_hp_max", 1))))
	result["hp"] = int(upgrade_result.get("hp", int(context.get("hp", 0))))
	result["energy_regen_per_sec"] = float(upgrade_result.get("energy_regen_per_sec", float(context.get("energy_regen_per_sec", 1.0))))
	return result


func _record_card_acquire_event(raw_event: Variant, context: Dictionary) -> void:
	if not (raw_event is Dictionary):
		return
	var event := (raw_event as Dictionary).duplicate(true)
	if event.is_empty():
		return
	var card_id := String(event.get("card_id", ""))
	if card_id.is_empty():
		return
	var card_index := int(event.get("hand_index", event.get("draw_index", 0)))
	var card_snapshot := CARD_SNAPSHOT_BUILDER.get_card_snapshot(
		card_id,
		card_index,
		context.get("card_configs", {}),
		context.get("card_chain", null) as CardChainState,
		context.get("special_cooldown_until", {}),
		float(context.get("elapsed_time", 0.0))
	)
	if card_snapshot.is_empty():
		return
	event["serial"] = next_card_acquire_event_serial
	next_card_acquire_event_serial += 1
	event["card"] = card_snapshot
	last_card_acquire_event = event
