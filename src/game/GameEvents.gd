extends Node

# 通用游戏事件总线。用于解耦玩法规则、表现反馈、音效和成就。

const ROUND_STARTED := &"round_started"
const ROUND_FINISHED := &"round_finished"
const FEEDBACK_REQUESTED := &"feedback_requested"
const AUDIO_REQUESTED := &"audio_requested"
const ACHIEVEMENT_UNLOCKED := &"achievement_unlocked"
const SPAWNED := &"spawned"
const PICKUP_COLLECTED := &"pickup_collected"
const ITEM_ADDED := &"item_added"
const ITEM_EQUIPPED := &"item_equipped"
const QUEST_UPDATED := &"quest_updated"
const WAVE_STARTED := &"wave_started"
const WAVE_SPAWN_REQUESTED := &"wave_spawn_requested"
const MENU_ACTION := &"menu_action"
const SCENE_CHANGE_REQUESTED := &"scene_change_requested"
const TUTORIAL_HINT_SHOWN := &"tutorial_hint_shown"

signal event_emitted(event_id: StringName, payload: Dictionary)

var _listeners: Dictionary = {}


func subscribe(event_id: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	var callbacks: Array = _listeners.get(event_id, [])
	if callback in callbacks:
		return
	callbacks.append(callback)
	_listeners[event_id] = callbacks


func unsubscribe(event_id: StringName, callback: Callable) -> void:
	var callbacks: Array = _listeners.get(event_id, [])
	if callback not in callbacks:
		return
	callbacks.erase(callback)
	if callbacks.is_empty():
		_listeners.erase(event_id)
	else:
		_listeners[event_id] = callbacks


func emit_event(event_id: StringName, payload: Dictionary = {}) -> void:
	var safe_payload := payload.duplicate(true)
	event_emitted.emit(event_id, safe_payload)
	var callbacks: Array = _listeners.get(event_id, []).duplicate()
	var invalid_callbacks: Array = []
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call(safe_payload)
		else:
			invalid_callbacks.append(callback)
	if invalid_callbacks.is_empty():
		return
	var current_callbacks: Array = _listeners.get(event_id, [])
	for callback: Callable in invalid_callbacks:
		current_callbacks.erase(callback)
	if current_callbacks.is_empty():
		_listeners.erase(event_id)
	else:
		_listeners[event_id] = current_callbacks
