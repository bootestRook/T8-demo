extends Node2D
class_name Spawner

signal spawned(node: Node, spawn_id: StringName)

@export var default_scene: PackedScene
@export var parent_path: NodePath
@export var spawn_radius := 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func spawn(scene: PackedScene = null, spawn_position: Variant = null, payload: Dictionary = {}) -> Node:
	var packed_scene := scene if scene != null else default_scene
	if packed_scene == null:
		return null
	var instance := packed_scene.instantiate()
	_apply_payload(instance, payload)
	_spawn_parent().add_child(instance)
	if instance is Node2D:
		instance.global_position = _resolve_position(spawn_position)
	var spawn_id := StringName(payload.get("spawn_id", ""))
	spawned.emit(instance, spawn_id)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.SPAWNED, {"node": instance, "spawn_id": spawn_id, "payload": payload})
	return instance


func _spawn_parent() -> Node:
	if String(parent_path) != "":
		var explicit_parent := get_node_or_null(parent_path)
		if explicit_parent != null:
			return explicit_parent
	var current_scene := get_tree().current_scene
	return current_scene if current_scene != null else self


func _resolve_position(spawn_position: Variant) -> Vector2:
	var position := global_position
	if spawn_position is Vector2:
		position = spawn_position
	if spawn_radius > 0.0:
		position += Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI)) * _rng.randf_range(0.0, spawn_radius)
	return position


func _apply_payload(instance: Node, payload: Dictionary) -> void:
	for key in payload:
		if key == "spawn_id":
			continue
		instance.set(StringName(key), payload[key])
