extends Node
class_name InventoryStore

signal inventory_changed(slots: Array[Dictionary])
signal item_added(item_id: StringName, quantity: int)

@export var capacity := 20

var slots: Array[Dictionary] = []


func _ready() -> void:
	if slots.is_empty():
		setup(capacity)


func setup(slot_count: int) -> void:
	capacity = maxi(1, slot_count)
	slots.clear()
	for _index in range(capacity):
		slots.append({})
	inventory_changed.emit(slots.duplicate(true))


func add_item(item_id: StringName, quantity: int = 1, max_stack: int = 99, metadata: Dictionary = {}) -> int:
	var remaining := maxi(0, quantity)
	var stack_limit := maxi(1, max_stack)
	for index in range(slots.size()):
		if remaining <= 0:
			break
		var slot := slots[index]
		if _same_stack(slot, item_id, metadata):
			var can_add := mini(remaining, stack_limit - int(slot.get("quantity", 0)))
			slot["quantity"] = int(slot.get("quantity", 0)) + can_add
			slots[index] = slot
			remaining -= can_add
	for index in range(slots.size()):
		if remaining <= 0:
			break
		if not slots[index].is_empty():
			continue
		var can_place := mini(remaining, stack_limit)
		slots[index] = {"id": item_id, "quantity": can_place, "metadata": metadata.duplicate(true)}
		remaining -= can_place
	if remaining != quantity:
		item_added.emit(item_id, quantity - remaining)
		if has_node("/root/GameEvents"):
			GameEvents.emit_event(GameEvents.ITEM_ADDED, {"item_id": item_id, "quantity": quantity - remaining})
		inventory_changed.emit(slots.duplicate(true))
	return remaining


func remove_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := maxi(0, quantity)
	for index in range(slots.size()):
		if remaining <= 0:
			break
		var slot := slots[index]
		if StringName(slot.get("id", "")) != item_id:
			continue
		var removed := mini(remaining, int(slot.get("quantity", 0)))
		slot["quantity"] = int(slot.get("quantity", 0)) - removed
		remaining -= removed
		slots[index] = {} if int(slot.get("quantity", 0)) <= 0 else slot
	if remaining != quantity:
		inventory_changed.emit(slots.duplicate(true))
	return quantity - remaining


func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if StringName(slot.get("id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func move_slot(from_index: int, to_index: int) -> bool:
	if not _valid_index(from_index) or not _valid_index(to_index):
		return false
	var previous := slots[to_index]
	slots[to_index] = slots[from_index]
	slots[from_index] = previous
	inventory_changed.emit(slots.duplicate(true))
	return true


func serialize() -> Dictionary:
	return {"capacity": capacity, "slots": slots.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	setup(int(data.get("capacity", capacity)))
	var saved_slots: Array = data.get("slots", [])
	for index in range(mini(saved_slots.size(), slots.size())):
		if saved_slots[index] is Dictionary:
			slots[index] = saved_slots[index].duplicate(true)
	inventory_changed.emit(slots.duplicate(true))


func _same_stack(slot: Dictionary, item_id: StringName, metadata: Dictionary) -> bool:
	return not slot.is_empty() and StringName(slot.get("id", "")) == item_id and Dictionary(slot.get("metadata", {})) == metadata


func _valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
