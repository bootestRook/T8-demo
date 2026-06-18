class_name HudCardTargetPreview

const DEFAULT_RELEASE_RADIUS := 1100.0
const CORE_SKILL_RELEASE_RADIUS := {
	"thermobaric": 1100.0,
	"dry_ice": 950.0,
	"electro_pierce": 800.0,
}


static func build(snapshot: Dictionary, hand_index: int, fallback_center: Vector2) -> Dictionary:
	var card := _card_snapshot_for_index(snapshot, hand_index)
	if card.is_empty():
		return {}
	var core_skill := String(card.get("core_skill", "")).strip_edges()
	return {
		"visible": true,
		"position": fallback_center,
		"radius": _target_radius(snapshot, core_skill),
		"core_skill": core_skill,
	}


static func _card_snapshot_for_index(snapshot: Dictionary, index: int) -> Dictionary:
	var cards_variant: Variant = snapshot.get("hand_cards", [])
	if not (cards_variant is Array):
		return {}
	var cards: Array = cards_variant as Array
	if index < 0 or index >= cards.size() or not (cards[index] is Dictionary):
		return {}
	return (cards[index] as Dictionary).duplicate(true)


static func _target_radius(snapshot: Dictionary, core_skill: String) -> float:
	var runtime := _core_skill_runtime(snapshot, core_skill)
	if runtime.has("target_radius"):
		return float(runtime.get("target_radius", _default_radius_for_core_skill(core_skill)))
	return _default_radius_for_core_skill(core_skill)


static func _default_radius_for_core_skill(core_skill: String) -> float:
	if CORE_SKILL_RELEASE_RADIUS.has(core_skill):
		return float(CORE_SKILL_RELEASE_RADIUS[core_skill])
	return DEFAULT_RELEASE_RADIUS


static func _core_skill_runtime(snapshot: Dictionary, core_skill: String) -> Dictionary:
	var runtime_variant: Variant = snapshot.get("core_skill_runtime", {})
	if not (runtime_variant is Dictionary):
		return {}
	var all_runtime: Dictionary = runtime_variant
	if not (all_runtime.get(core_skill, {}) is Dictionary):
		return {}
	return all_runtime.get(core_skill, {}) as Dictionary
