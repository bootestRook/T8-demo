extends RefCounted
class_name CardChainParamRules

const HIGHLIGHT_FONT_SIZE_TOKEN := "{chain_font_size}"
const HIGHLIGHT_OPEN := "[b][color=#a66f00][font_size=" + HIGHLIGHT_FONT_SIZE_TOKEN + "]"
const HIGHLIGHT_CLOSE := "[/font_size][/color][/b]"


static func apply_overrides(source_cards: Array, csv_path: String, json_path: String) -> Array:
	var params_by_card := _load_params(csv_path, json_path)
	if params_by_card.is_empty():
		return source_cards
	var result: Array = []
	for item in source_cards:
		if not (item is Dictionary):
			continue
		var card := (item as Dictionary).duplicate(true)
		var card_id := String(card.get("card_id", ""))
		if params_by_card.has(card_id):
			card["chain_params"] = ((params_by_card[card_id] as Array).duplicate(true))
		result.append(card)
	return result


static func format_effect_text(card: Dictionary, chain_scale: int, rich_text := false) -> String:
	var result := String(card.get("effect", card.get("text", card.get("desc", "")))).strip_edges()
	if result.is_empty():
		result = "释放后立即生效"
	var params: Array = card.get("chain_params", []) as Array
	if params.is_empty():
		return result
	chain_scale = maxi(1, chain_scale)
	for item in params:
		if not (item is Dictionary):
			continue
		var param := item as Dictionary
		var source_text := String(param.get("text", "")).strip_edges()
		if source_text.is_empty() or result.find(source_text) < 0:
			continue
		var value_text := format_param_value(param, chain_scale)
		if rich_text:
			value_text = HIGHLIGHT_OPEN + value_text + HIGHLIGHT_CLOSE
		result = result.replace(source_text, value_text)
	return result


static func scaled_runtime_value(card: Dictionary, field: String, chain_scale: int, default_value: Variant) -> Variant:
	var params: Array = card.get("chain_params", []) as Array
	if params.is_empty():
		return default_value
	chain_scale = maxi(1, chain_scale)
	for item in params:
		if not (item is Dictionary):
			continue
		var param := item as Dictionary
		if String(param.get("runtime_field", "")) != field:
			continue
		var runtime_kind := String(param.get("runtime_kind", "scale"))
		match runtime_kind:
			"multiplier_bonus":
				return 1.0 + _runtime_base_ratio(param, default_value) * float(chain_scale)
			"round_scale":
				return maxi(0, int(float(param.get("base_value", default_value)) * float(chain_scale) + 0.5))
			"scale":
				return _runtime_base_value(param, default_value) * float(chain_scale)
		return default_value
	return default_value


static func format_param_value(param: Dictionary, chain_scale: int) -> String:
	var base_value := float(param.get("base_value", 0.0))
	var value := base_value * float(maxi(1, chain_scale))
	var decimals := int(param.get("decimals", 0))
	var unit := String(param.get("unit", ""))
	match String(param.get("format", "")):
		"signed_percent":
			return _signed_number(value, decimals) + "%"
		"percent":
			return _number(value, decimals) + "%"
		"seconds":
			return _number(value, decimals) + "秒"
		"signed_seconds":
			return _signed_number(value, decimals) + "秒"
		"count":
			return _number(value, decimals) + unit
		"signed_count":
			return _signed_number(value, decimals) + unit
		"signed_number":
			return _signed_number(value, decimals)
	return _number(value, decimals) + unit


static func _load_params(csv_path: String, json_path: String) -> Dictionary:
	var json_params := _load_json_params(json_path)
	if not json_params.is_empty():
		return json_params
	return _load_csv_params(csv_path)


static func _load_json_params(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var result := {}
	for card_id in (parsed as Dictionary).keys():
		var params: Variant = (parsed as Dictionary)[card_id]
		if params is Array:
			result[String(card_id)] = _normalize_params(params as Array)
	return result


static func _load_csv_params(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
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
		var param := {
			"key": _csv_value(row, header_index, "key"),
			"text": _csv_value(row, header_index, "text"),
			"base_value": _to_float(_csv_value(row, header_index, "base_value")),
			"format": _csv_value(row, header_index, "format"),
			"unit": _csv_value(row, header_index, "unit"),
			"runtime_field": _csv_value(row, header_index, "runtime_field"),
			"runtime_kind": _csv_value(row, header_index, "runtime_kind"),
			"decimals": _to_int(_csv_value(row, header_index, "decimals")),
		}
		var params: Array = result.get(card_id, []) as Array
		params.append(param)
		result[card_id] = params
	for card_id in result.keys():
		result[card_id] = _normalize_params(result[card_id] as Array)
	return result


static func _normalize_params(params: Array) -> Array:
	var result: Array = []
	for item in params:
		if not (item is Dictionary):
			continue
		var param := (item as Dictionary).duplicate(true)
		param["text"] = String(param.get("text", "")).strip_edges()
		param["format"] = String(param.get("format", "")).strip_edges()
		if param["text"].is_empty() or param["format"].is_empty():
			continue
		param["base_value"] = float(param.get("base_value", 0.0))
		param["decimals"] = int(param.get("decimals", 0))
		result.append(param)
	return result


static func _csv_value(row: PackedStringArray, header_index: Dictionary, key: String) -> String:
	if not header_index.has(key):
		return ""
	var index := int(header_index[key])
	if index < 0 or index >= row.size():
		return ""
	return _clean_csv_cell(String(row[index]))


static func _clean_csv_cell(value: String) -> String:
	return value.replace("\uFEFF", "").strip_edges()


static func _to_float(value: String) -> float:
	if value.strip_edges().is_empty():
		return 0.0
	return float(value)


static func _to_int(value: String) -> int:
	if value.strip_edges().is_empty():
		return 0
	return int(float(value))


static func _runtime_base_value(param: Dictionary, default_value: Variant) -> float:
	var format := String(param.get("format", ""))
	var base_value := float(param.get("base_value", default_value))
	if format == "percent" or format == "signed_percent":
		return base_value / 100.0
	return base_value


static func _runtime_base_ratio(param: Dictionary, default_value: Variant) -> float:
	var format := String(param.get("format", ""))
	if format == "percent" or format == "signed_percent":
		return float(param.get("base_value", 0.0)) / 100.0
	return maxf(0.0, float(default_value) - 1.0)


static func _signed_number(value: float, decimals: int) -> String:
	if value >= 0.0:
		return "+" + _number(value, decimals)
	return _number(value, decimals)


static func _number(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(int(value + 0.5))
	var format_text := "%." + str(decimals) + "f"
	var text := format_text % value
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
