extends RefCounted
class_name UpgradePoolLoader


static func load_pool(csv_path: String, json_path := "") -> Array:
	if not json_path.is_empty():
		var json_pool := _load_json_pool(json_path)
		if not json_pool.is_empty():
			return json_pool
	if not FileAccess.file_exists(csv_path):
		return []
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return []
	var headers := file.get_csv_line()
	var header_index := {}
	for index in range(headers.size()):
		header_index[_clean_csv_cell(String(headers[index]))] = index
	var result: Array = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 0:
			continue
		var upgrade := _upgrade_from_csv_row(row, header_index)
		if not upgrade.is_empty():
			result.append(upgrade)
	return result


static func _load_json_pool(json_path: String) -> Array:
	if not FileAccess.file_exists(json_path):
		return []
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return []
	var result: Array = []
	for item in parsed:
		if not (item is Dictionary):
			continue
		var upgrade := (item as Dictionary).duplicate(true)
		if String(upgrade.get("id", "")).is_empty() or String(upgrade.get("kind", "")).is_empty():
			continue
		result.append(upgrade)
	return result


static func _upgrade_from_csv_row(row: PackedStringArray, header_index: Dictionary) -> Dictionary:
	var upgrade_id := _csv_value(row, header_index, "id")
	if upgrade_id.is_empty():
		return {}
	var entry_type := _csv_value(row, header_index, "entry_type")
	if entry_type.is_empty():
		entry_type = "upgrade"
	var kind := _csv_value(row, header_index, "kind")
	if kind.is_empty() and entry_type == "card":
		kind = "new_card"
	if kind.is_empty():
		return {}
	var config := {
		"id": upgrade_id,
		"entry_type": entry_type,
		"kind": kind,
		"weight": _csv_float_or_default(row, header_index, "weight", 1.0),
		"max_pick_count": _csv_int_or_default(row, header_index, "max_pick_count", 1),
		"prerequisites": _csv_indexed_values(row, header_index, "prereq"),
		"mutexes": _csv_indexed_values(row, header_index, "mutex"),
	}
	for key in ["card_id", "title", "school", "field", "core_skill"]:
		_set_csv_text_field(config, row, header_index, key)
	var description := _csv_value(row, header_index, "description")
	if not description.is_empty():
		config["description"] = description.replace("\\n", "\n")
	for key in ["add", "mul", "damage_mul", "value"]:
		_set_csv_float_field(config, row, header_index, key)
	return config


static func _csv_indexed_values(row: PackedStringArray, header_index: Dictionary, prefix: String) -> Array:
	var result: Array = []
	for index in range(1, 9):
		var value := _csv_value(row, header_index, "%s_%d" % [prefix, index])
		if not value.is_empty():
			result.append(value)
	return result


static func _set_csv_text_field(config: Dictionary, row: PackedStringArray, header_index: Dictionary, key: String) -> void:
	var value := _csv_value(row, header_index, key)
	if not value.is_empty():
		config[key] = value


static func _set_csv_float_field(config: Dictionary, row: PackedStringArray, header_index: Dictionary, key: String) -> void:
	var value := _csv_value(row, header_index, key)
	if value.is_empty() or not value.is_valid_float():
		return
	config[key] = float(value)


static func _csv_float_or_default(row: PackedStringArray, header_index: Dictionary, key: String, default_value: float) -> float:
	var value := _csv_value(row, header_index, key)
	if value.is_empty() or not value.is_valid_float():
		return default_value
	return float(value)


static func _csv_int_or_default(row: PackedStringArray, header_index: Dictionary, key: String, default_value: int) -> int:
	var value := _csv_value(row, header_index, key)
	if value.is_empty() or not value.is_valid_int():
		return default_value
	return int(value)


static func _csv_value(row: PackedStringArray, header_index: Dictionary, key: String) -> String:
	if not header_index.has(key):
		return ""
	var index := int(header_index[key])
	if index < 0 or index >= row.size():
		return ""
	return _clean_csv_cell(String(row[index]))


static func _clean_csv_cell(value: String) -> String:
	return value.replace("\uFEFF", "").strip_edges()
