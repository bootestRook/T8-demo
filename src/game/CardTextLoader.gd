extends RefCounted
class_name CardTextLoader


static func apply_overrides(source_cards: Array, csv_path: String, json_path: String) -> Array:
	var overrides := _load_overrides(csv_path, json_path)
	if overrides.is_empty():
		return source_cards
	var result: Array = []
	for item in source_cards:
		if not (item is Dictionary):
			continue
		var card := (item as Dictionary).duplicate(true)
		var card_id := String(card.get("card_id", ""))
		if overrides.has(card_id):
			var text_config: Dictionary = overrides[card_id] as Dictionary
			for key in text_config.keys():
				card[key] = text_config[key]
			if text_config.has("card_name"):
				card["name"] = text_config["card_name"]
			if text_config.has("text"):
				card["desc"] = text_config["text"]
				card["effect"] = text_config["text"]
		result.append(card)
	return result


static func _load_overrides(csv_path: String, json_path: String) -> Dictionary:
	var json_overrides := _load_json_overrides(json_path)
	if not json_overrides.is_empty():
		return json_overrides
	return _load_csv_overrides(csv_path)


static func _load_csv_overrides(csv_path: String) -> Dictionary:
	if not FileAccess.file_exists(csv_path):
		return {}
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return {}
	var headers := file.get_csv_line()
	var header_index := {}
	for index in range(headers.size()):
		header_index[_clean_csv_cell(String(headers[index]))] = index
	var result := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 0:
			continue
		var card_id := _csv_value(row, header_index, "card_id")
		if card_id.is_empty():
			continue
		var config := {}
		_set_csv_text_field(config, row, header_index, "card_name")
		_set_csv_text_field(config, row, header_index, "school")
		_set_csv_text_field(config, row, header_index, "type")
		_set_csv_text_field(config, row, header_index, "icon")
		_set_csv_text_field(config, row, header_index, "text")
		var cost_text := _csv_value(row, header_index, "cost")
		if not cost_text.is_empty() and cost_text.is_valid_int():
			config["cost"] = int(cost_text)
		result[card_id] = config
	return result


static func _load_json_overrides(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var result := {}
	for card_id in (parsed as Dictionary).keys():
		var config: Variant = (parsed as Dictionary)[card_id]
		if config is Dictionary:
			result[String(card_id)] = (config as Dictionary).duplicate(true)
	return result


static func _set_csv_text_field(config: Dictionary, row: PackedStringArray, header_index: Dictionary, key: String) -> void:
	var value := _csv_value(row, header_index, key)
	if not value.is_empty():
		config[key] = value


static func _csv_value(row: PackedStringArray, header_index: Dictionary, key: String) -> String:
	if not header_index.has(key):
		return ""
	var index := int(header_index[key])
	if index < 0 or index >= row.size():
		return ""
	return _clean_csv_cell(String(row[index]))


static func _clean_csv_cell(value: String) -> String:
	return value.replace("\uFEFF", "").strip_edges()
