extends RefCounted
class_name TriggerContext

var chain_id: StringName = &""
var depth := 0
var max_depth := 8
var spawn_budget := 48
var event_budget := 128
var visited_event_ids: Array[StringName] = []
var visited_edges: Dictionary = {}
var trace: Array[Dictionary] = []


static func create(new_chain_id: StringName, new_max_depth := 8, new_spawn_budget := 48, new_event_budget := 128) -> TriggerContext:
	var context := TriggerContext.new()
	context.chain_id = new_chain_id
	context.max_depth = new_max_depth
	context.spawn_budget = new_spawn_budget
	context.event_budget = new_event_budget
	return context


func duplicate_context() -> TriggerContext:
	var copied := TriggerContext.create(chain_id, max_depth, spawn_budget, event_budget)
	copied.depth = depth
	copied.visited_event_ids = visited_event_ids.duplicate(true)
	copied.visited_edges = visited_edges.duplicate(true)
	copied.trace = trace.duplicate(true)
	return copied


func enter_event(event_id: StringName) -> void:
	depth += 1
	event_budget -= 1
	if not visited_event_ids.has(event_id):
		visited_event_ids.append(event_id)
	(
		trace
		. append(
			{
				"kind": "event",
				"event_id": event_id,
				"depth": depth,
			}
		)
	)


func leave_event() -> void:
	if depth > 0:
		depth -= 1


func edge_key(from_event_id: StringName, to_event_id: StringName) -> String:
	return "%s>%s" % [String(from_event_id), String(to_event_id)]


func has_edge(from_event_id: StringName, to_event_id: StringName) -> bool:
	return visited_edges.has(edge_key(from_event_id, to_event_id))


func record_edge(from_event_id: StringName, to_event_id: StringName) -> void:
	visited_edges[edge_key(from_event_id, to_event_id)] = true
	(
		trace
		. append(
			{
				"kind": "edge",
				"from": from_event_id,
				"to": to_event_id,
				"depth": depth,
			}
		)
	)


func consume_spawn(count := 1) -> bool:
	if count <= 0:
		return true
	if spawn_budget < count:
		return false
	spawn_budget -= count
	return true
