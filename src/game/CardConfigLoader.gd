extends RefCounted
class_name CardConfigLoader


static func load_configs(json_path: String) -> Array:
	if not FileAccess.file_exists(json_path):
		return []
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return _array_to_card_configs(parsed as Array)
	if parsed is Dictionary:
		return _dictionary_to_card_configs(parsed as Dictionary)
	return []


static func _array_to_card_configs(source: Array) -> Array:
	var result: Array = []
	for item in source:
		if item is Dictionary:
			var card := (item as Dictionary).duplicate(true)
			if not String(card.get("card_id", "")).is_empty():
				result.append(card)
	return result


static func _dictionary_to_card_configs(source: Dictionary) -> Array:
	var result: Array = []
	for card_id in source.keys():
		var item: Variant = source[card_id]
		if not (item is Dictionary):
			continue
		var card := (item as Dictionary).duplicate(true)
		if String(card.get("card_id", "")).is_empty():
			card["card_id"] = String(card_id)
		if not String(card.get("card_id", "")).is_empty():
			result.append(card)
	return result
