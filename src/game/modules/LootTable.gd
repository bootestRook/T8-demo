extends Node
class_name LootTable

var entries: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func add_entry(item_id: StringName, weight: float, min_quantity: int = 1, max_quantity: int = 1) -> void:
	(
		entries
		. append(
			{
				"id": item_id,
				"weight": maxf(0.0, weight),
				"min_quantity": maxi(1, min_quantity),
				"max_quantity": maxi(min_quantity, max_quantity),
			}
		)
	)


func roll(random: RandomNumberGenerator = null) -> Dictionary:
	if entries.is_empty():
		return {}
	var source := random if random != null else _rng
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return {}
	var cursor := source.randf_range(0.0, total_weight)
	for entry in entries:
		cursor -= float(entry.get("weight", 0.0))
		if cursor <= 0.0:
			return {
				"id": StringName(entry.get("id", "")),
				"quantity": source.randi_range(int(entry.get("min_quantity", 1)), int(entry.get("max_quantity", 1))),
			}
	return {}
