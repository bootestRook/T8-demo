extends Area2D
class_name Pickup

signal collected(collector: Node, item_id: StringName, quantity: int)

@export var item_id: StringName = &""
@export var quantity := 1
@export var auto_collect := true
@export var auto_free := true

var collected_once := false


func _ready() -> void:
	if auto_collect:
		body_entered.connect(_on_collector_entered)
		area_entered.connect(_on_collector_entered)


func collect(collector: Node = null) -> bool:
	if collected_once:
		return false
	collected_once = true
	collected.emit(collector, item_id, quantity)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.PICKUP_COLLECTED, {"collector": collector, "item_id": item_id, "quantity": quantity})
	if auto_free:
		queue_free()
	return true


func _on_collector_entered(collector: Node) -> void:
	collect(collector)
