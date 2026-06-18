extends RefCounted
class_name GameSnapshotBuilder

const GAME_SNAPSHOT_SECTIONS := preload("res://src/game/GameSnapshotSections.gd")


static func build(state, monster_attack_range_y: float, initial_ammo: int, is_playing: bool) -> Dictionary:
	var snapshot: Dictionary = {}
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.core(state, monster_attack_range_y))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.progression(state))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.combat_resources(state, initial_ammo))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.card_piles(state))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.card_play(state, is_playing))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.chain(state))
	_merge(snapshot, GAME_SNAPSHOT_SECTIONS.runtime_logs(state))
	GAME_SNAPSHOT_SECTIONS.merge_combat_snapshot(snapshot, state)
	return snapshot


static func _merge(snapshot: Dictionary, section: Dictionary) -> void:
	for key in section.keys():
		snapshot[key] = section[key]
