extends RefCounted
class_name CombatEvent

const TYPE_CAST := &"cast"
const TYPE_HIT := &"hit"
const TYPE_TICK := &"tick"
const TYPE_DEATH := &"death"
const TYPE_KILL := &"kill"
const TYPE_EXPIRE := &"expire"
const TYPE_RESOLVED := &"resolved"
const TYPE_CUSTOM := &"custom"

var event_type: StringName = TYPE_CUSTOM
var event_id: StringName = &""
var source_id: StringName = &""
var owner_id: StringName = &""
var payload: Dictionary = {}
var context: TriggerContext = null


static func create(
	new_event_type: StringName,
	new_event_id: StringName,
	new_source_id: StringName = &"",
	new_owner_id: StringName = &"",
	new_payload: Dictionary = {},
	new_context: TriggerContext = null
) -> CombatEvent:
	var event := CombatEvent.new()
	event.event_type = new_event_type
	event.event_id = new_event_id
	event.source_id = new_source_id
	event.owner_id = new_owner_id
	event.payload = new_payload.duplicate(true)
	event.context = new_context
	return event


static func from_dictionary(data: Dictionary, new_context: TriggerContext = null) -> CombatEvent:
	return CombatEvent.create(
		StringName(data.get("event_type", TYPE_CUSTOM)),
		StringName(data.get("event_id", &"")),
		StringName(data.get("source_id", &"")),
		StringName(data.get("owner_id", &"")),
		data.get("payload", {}) as Dictionary,
		new_context
	)


func duplicate_event(keep_context := true) -> CombatEvent:
	var copied_context := context if keep_context else null
	return CombatEvent.create(event_type, event_id, source_id, owner_id, payload, copied_context)


func with_payload(extra_payload: Dictionary) -> CombatEvent:
	var copied := duplicate_event(true)
	for key in extra_payload.keys():
		copied.payload[key] = extra_payload[key]
	return copied


func to_dictionary() -> Dictionary:
	return {
		"event_type": event_type,
		"event_id": event_id,
		"source_id": source_id,
		"owner_id": owner_id,
		"payload": payload.duplicate(true),
		"chain_id": context.chain_id if context != null else &"",
	}
