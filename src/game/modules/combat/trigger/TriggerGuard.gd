extends RefCounted
class_name TriggerGuard

const REASON_NO_CONTEXT := &"no_context"
const REASON_DEPTH_LIMIT := &"depth_limit"
const REASON_EVENT_BUDGET := &"event_budget"
const REASON_SELF_LOOP := &"self_loop"
const REASON_REPEATED_EDGE := &"repeated_edge"
const REASON_SPAWN_BUDGET := &"spawn_budget"


func can_enter(event: CombatEvent) -> Dictionary:
	if event.context == null:
		return _blocked(REASON_NO_CONTEXT, event.event_id)
	if event.context.depth >= event.context.max_depth:
		return _blocked(REASON_DEPTH_LIMIT, event.event_id)
	if event.context.event_budget <= 0:
		return _blocked(REASON_EVENT_BUDGET, event.event_id)
	return _allowed(event.event_id)


func can_emit(parent_event: CombatEvent, child_event_id: StringName) -> Dictionary:
	if parent_event.context == null:
		return _blocked(REASON_NO_CONTEXT, child_event_id)
	if parent_event.event_id == child_event_id:
		return _blocked(REASON_SELF_LOOP, child_event_id)
	if parent_event.context.has_edge(parent_event.event_id, child_event_id):
		return _blocked(REASON_REPEATED_EDGE, child_event_id)
	if parent_event.context.depth >= parent_event.context.max_depth:
		return _blocked(REASON_DEPTH_LIMIT, child_event_id)
	if parent_event.context.event_budget <= 0:
		return _blocked(REASON_EVENT_BUDGET, child_event_id)
	return _allowed(child_event_id)


func can_spawn(event: CombatEvent, count: int) -> Dictionary:
	if event.context == null:
		return _blocked(REASON_NO_CONTEXT, event.event_id)
	if event.context.spawn_budget < count:
		return _blocked(REASON_SPAWN_BUDGET, event.event_id)
	return _allowed(event.event_id)


func _allowed(event_id: StringName) -> Dictionary:
	return {
		"ok": true,
		"event_id": event_id,
		"reason": &"",
	}


func _blocked(reason: StringName, event_id: StringName) -> Dictionary:
	return {
		"ok": false,
		"command": &"guard_blocked",
		"event_id": event_id,
		"reason": reason,
	}
