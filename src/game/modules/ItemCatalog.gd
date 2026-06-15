extends Node
class_name ItemCatalog

signal item_registered(item_id: StringName, definition: Dictionary)

var definitions: Dictionary = {}


func register_item(item_id: StringName, display_name: String, item_type: StringName, max_stack: int = 1, extra: Dictionary = {}) -> void:
	var definition := extra.duplicate(true)
	definition["id"] = item_id
	definition["name"] = display_name
	definition["type"] = item_type
	definition["max_stack"] = maxi(1, max_stack)
	definitions[item_id] = definition
	item_registered.emit(item_id, definition.duplicate(true))


func has_item(item_id: StringName) -> bool:
	return definitions.has(item_id)


func get_item(item_id: StringName) -> Dictionary:
	return definitions.get(item_id, {}).duplicate(true)


func max_stack(item_id: StringName) -> int:
	return int(get_item(item_id).get("max_stack", 1))


func item_type(item_id: StringName) -> StringName:
	return StringName(get_item(item_id).get("type", ""))


func can_equip_to(item_id: StringName, slot_name: StringName) -> bool:
	var definition := get_item(item_id)
	var allowed_slots: Array = definition.get("equip_slots", [])
	return bool(definition.get("allow_any_slot", false)) or slot_name in allowed_slots


func load_definitions(items: Array[Dictionary]) -> void:
	for item in items:
		register_item(
			StringName(item.get("id", "")),
			String(item.get("name", "")),
			StringName(item.get("type", "")),
			int(item.get("max_stack", 1)),
			item
		)
