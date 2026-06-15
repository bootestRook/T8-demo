extends Node
class_name EquipmentStore

signal equipment_changed(slot_name: StringName, item: Dictionary)

const DEFAULT_SLOTS := [&"weapon", &"armor", &"accessory"]

var equipment: Dictionary = {}


func _ready() -> void:
	if equipment.is_empty():
		setup(DEFAULT_SLOTS)


func setup(slot_names: Array) -> void:
	equipment.clear()
	for slot_name in slot_names:
		equipment[StringName(slot_name)] = {}


func can_equip(slot_name: StringName, item: Dictionary) -> bool:
	var allowed_slots: Array = item.get("equip_slots", [])
	return bool(item.get("allow_any_slot", false)) or slot_name in allowed_slots


func equip(slot_name: StringName, item: Dictionary) -> Dictionary:
	if not equipment.has(slot_name) or not can_equip(slot_name, item):
		return {}
	var previous: Dictionary = equipment.get(slot_name, {})
	equipment[slot_name] = item.duplicate(true)
	equipment_changed.emit(slot_name, item.duplicate(true))
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.ITEM_EQUIPPED, {"slot": slot_name, "item": item})
	return previous


func unequip(slot_name: StringName) -> Dictionary:
	if not equipment.has(slot_name):
		return {}
	var previous: Dictionary = equipment.get(slot_name, {})
	equipment[slot_name] = {}
	equipment_changed.emit(slot_name, {})
	return previous


func bonus_totals() -> Dictionary:
	var totals: Dictionary = {}
	for slot_name in equipment:
		var item: Dictionary = equipment[slot_name]
		var stats: Dictionary = item.get("stats", {})
		for stat_name in stats:
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + float(stats[stat_name])
	return totals


func serialize() -> Dictionary:
	return equipment.duplicate(true)


func deserialize(data: Dictionary) -> void:
	for slot_name in equipment:
		var item: Dictionary = data.get(slot_name, {})
		equipment[slot_name] = item.duplicate(true)
		equipment_changed.emit(slot_name, equipment[slot_name])
