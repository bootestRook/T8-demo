extends Node

# 视觉反馈统一入口。空脚手架不预置玩法反馈，新游戏按事件扩展即可。

var _screen_shake_tween: Tween
var _screen_shake_target: Node
var _screen_shake_offset := Vector2.ZERO
var _flash_tweens: Dictionary = {}
var _flash_original_modulates: Dictionary = {}


func _ready() -> void:
	if not has_node("/root/GameEvents"):
		return
	GameEvents.subscribe(GameEvents.FEEDBACK_REQUESTED, Callable(self, "_on_feedback_requested"))
	GameEvents.subscribe(GameEvents.ACHIEVEMENT_UNLOCKED, Callable(self, "_on_achievement_unlocked"))


func play_feedback(event_id: StringName, context: Dictionary = {}) -> void:
	if event_id == GameEvents.ACHIEVEMENT_UNLOCKED:
		_on_achievement_unlocked(context)


func screen_shake(intensity: float = 8.0, duration: float = 0.16) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("set_screen_feedback_offset"):
		return
	if _screen_shake_tween != null:
		_screen_shake_tween.kill()
		_screen_shake_tween = null
		_revert_screen_shake_offset()
	_screen_shake_target = scene
	var target_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	_screen_shake_tween = create_tween()
	_screen_shake_tween.tween_method(_set_screen_shake_offset, Vector2.ZERO, target_offset, duration * 0.5)
	_screen_shake_tween.tween_method(_set_screen_shake_offset, target_offset, Vector2.ZERO, duration * 0.5)
	_screen_shake_tween.finished.connect(
		func():
			_screen_shake_tween = null
			_revert_screen_shake_offset()
			_screen_shake_target = null
	)


func flash(node: CanvasItem, duration: float = 0.10) -> void:
	if not is_instance_valid(node):
		return
	var instance_id := node.get_instance_id()
	var previous_tween := _flash_tweens.get(instance_id, null) as Tween
	if previous_tween != null:
		previous_tween.kill()
		_flash_tweens.erase(instance_id)
	var original := _flash_original_modulates.get(instance_id, node.modulate) as Color
	_flash_original_modulates[instance_id] = original
	node.modulate = Color.WHITE
	var tween := create_tween()
	_flash_tweens[instance_id] = tween
	tween.tween_property(node, "modulate", original, duration)
	tween.finished.connect(
		func():
			_flash_tweens.erase(instance_id)
			_flash_original_modulates.erase(instance_id)
	)


func floating_text(parent: Node, text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.global_position = pos
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 42.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.finished.connect(
		func():
			if is_instance_valid(label):
				label.queue_free()
	)


func _on_feedback_requested(payload: Dictionary) -> void:
	play_feedback(payload.get("event_id", &""), payload)


func _on_achievement_unlocked(payload: Dictionary) -> void:
	var definition := payload.get("definition", {}) as Dictionary
	var title := String(definition.get("title", "成就解锁"))
	var parent := _feedback_parent(payload)
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	floating_text(parent, title, viewport_center + Vector2(-64.0, -80.0), Color(0.95, 0.75, 0.16))


func _feedback_parent(payload: Dictionary) -> Node:
	var parent = payload.get("parent", null)
	if parent is Node and is_instance_valid(parent):
		return parent
	var current := get_tree().current_scene
	return current if current != null else self


func _revert_screen_shake_offset() -> void:
	if is_instance_valid(_screen_shake_target) and _screen_shake_offset != Vector2.ZERO:
		_screen_shake_target.call("set_screen_feedback_offset", Vector2.ZERO)
	_screen_shake_offset = Vector2.ZERO


func _set_screen_shake_offset(offset: Vector2) -> void:
	if not is_instance_valid(_screen_shake_target):
		_screen_shake_offset = Vector2.ZERO
		return
	_screen_shake_target.call("set_screen_feedback_offset", offset)
	_screen_shake_offset = offset
