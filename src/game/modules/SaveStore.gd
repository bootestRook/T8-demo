extends Node
class_name SaveStore

signal saved(path: String)
signal loaded(data: Dictionary)

@export var save_path := "user://save_state.json"
@export var version := 1

var providers: Dictionary = {}


func register_provider(provider_id: StringName, save_callback: Callable, load_callback: Callable = Callable()) -> void:
	if not save_callback.is_valid():
		return
	providers[provider_id] = {"save": save_callback, "load": load_callback}


func save_game(extra: Dictionary = {}) -> bool:
	var data := {"version": version, "providers": {}, "extra": extra}
	for provider_id in providers:
		var provider: Dictionary = providers[provider_id]
		data["providers"][provider_id] = provider["save"].call()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	saved.emit(save_path)
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data := parsed as Dictionary
	var provider_data: Dictionary = data.get("providers", {})
	for provider_id in providers:
		var provider: Dictionary = providers[provider_id]
		var load_callback: Callable = provider.get("load", Callable())
		if load_callback.is_valid():
			load_callback.call(provider_data.get(provider_id, {}))
	loaded.emit(data)
	return data
