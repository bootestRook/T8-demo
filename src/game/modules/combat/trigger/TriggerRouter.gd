extends RefCounted
class_name TriggerRouter

var guard := TriggerGuard.new()
var executor := EffectExecutor.new()
var _routes: Dictionary = {}
var _next_chain_index := 1


func clear() -> void:
	_routes.clear()
	_next_chain_index = 1


func register_route(event_type: StringName, event_id: StringName, effects: Array) -> void:
	var routes_by_id: Dictionary = _routes.get(event_type, {}) as Dictionary
	routes_by_id[event_id] = effects.duplicate(true)
	_routes[event_type] = routes_by_id


func register_routes(routes: Dictionary) -> void:
	for event_type_key in routes.keys():
		var routes_by_id: Dictionary = routes[event_type_key] as Dictionary
		for event_id_key in routes_by_id.keys():
			register_route(StringName(event_type_key), StringName(event_id_key), routes_by_id[event_id_key] as Array)


func route(event: CombatEvent, services: Dictionary = {}) -> Array:
	if event.context == null:
		event.context = _new_context(event)
	var guard_result := guard.can_enter(event)
	if not bool(guard_result.get("ok", false)):
		return [guard_result]
	event.context.enter_event(event.event_id)
	var results: Array = []
	var effects := _effects_for(event.event_type, event.event_id)
	for effect: Dictionary in effects:
		var effect_results := executor.execute(effect, event, services, self)
		for result in effect_results:
			results.append(result)
	event.context.leave_event()
	return results


func emit_child_event(
	parent_event: CombatEvent,
	child_event_type: StringName,
	child_event_id: StringName,
	child_payload: Dictionary = {},
	services: Dictionary = {}
) -> Array:
	var guard_result := guard.can_emit(parent_event, child_event_id)
	if not bool(guard_result.get("ok", false)):
		return [guard_result]
	parent_event.context.record_edge(parent_event.event_id, child_event_id)
	var child := CombatEvent.create(
		child_event_type, child_event_id, parent_event.source_id, parent_event.owner_id, child_payload, parent_event.context
	)
	return route(child, services)


func has_route(event_type: StringName, event_id: StringName) -> bool:
	var routes_by_id: Dictionary = _routes.get(event_type, {}) as Dictionary
	return routes_by_id.has(event_id)


func _effects_for(event_type: StringName, event_id: StringName) -> Array:
	var routes_by_id: Dictionary = _routes.get(event_type, {}) as Dictionary
	return (routes_by_id.get(event_id, []) as Array).duplicate(true)


func _new_context(event: CombatEvent) -> TriggerContext:
	var chain_id := StringName("%s:%s:%d" % [String(event.event_type), String(event.event_id), _next_chain_index])
	_next_chain_index += 1
	return TriggerContext.create(chain_id)
