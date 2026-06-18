extends RefCounted
class_name EffectExecutor

const TYPE_DEAL_DAMAGE := &"deal_damage"
const TYPE_APPLY_STATUS := &"apply_status"
const TYPE_KNOCKBACK := &"knockback"
const TYPE_SPAWN_PROJECTILE := &"spawn_projectile"
const TYPE_SPAWN_AREA := &"spawn_area"
const TYPE_QUERY_TARGETS := &"query_targets"
const TYPE_EMIT_EVENT := &"emit_event"
const TYPE_LOG := &"log"
const TYPE_NOOP := &"noop"


func execute(effect_spec: Dictionary, event: CombatEvent, services: Dictionary = {}, router: TriggerRouter = null) -> Array:
	var results: Array = []
	if _conditions_pass(effect_spec, event):
		var effect_type := StringName(effect_spec.get("type", TYPE_NOOP))
		match effect_type:
			TYPE_DEAL_DAMAGE:
				results = [_execute_command(effect_spec, event, TYPE_DEAL_DAMAGE, services)]
			TYPE_APPLY_STATUS:
				results = [_execute_command(effect_spec, event, TYPE_APPLY_STATUS, services)]
			TYPE_KNOCKBACK:
				results = [_execute_command(effect_spec, event, TYPE_KNOCKBACK, services)]
			TYPE_QUERY_TARGETS:
				results = [_execute_command(effect_spec, event, TYPE_QUERY_TARGETS, services)]
			TYPE_SPAWN_PROJECTILE:
				results = _execute_spawn(effect_spec, event, TYPE_SPAWN_PROJECTILE, services)
			TYPE_SPAWN_AREA:
				results = _execute_spawn(effect_spec, event, TYPE_SPAWN_AREA, services)
			TYPE_EMIT_EVENT:
				results = [_execute_emit(effect_spec, event, services, router)]
			TYPE_LOG:
				results = [_execute_command(effect_spec, event, TYPE_LOG, services)]
			_:
				results = [_execute_command(effect_spec, event, TYPE_NOOP, services)]
	return results


func _execute_spawn(effect_spec: Dictionary, event: CombatEvent, command_type: StringName, services: Dictionary) -> Array:
	var count := int(_resolve_value(effect_spec, event, "count", 1))
	if count < 1:
		count = 1
	var guard := TriggerGuard.new()
	var guard_result := guard.can_spawn(event, count)
	if not bool(guard_result.get("ok", false)):
		return [guard_result]
	if not event.context.consume_spawn(count):
		return [guard._blocked(TriggerGuard.REASON_SPAWN_BUDGET, event.event_id)]
	var commands: Array = []
	for index in range(count):
		var command := _build_command(effect_spec, event, command_type)
		command["index"] = index
		command["count"] = count
		_call_service(command_type, command, event, services)
		commands.append(command)
	return commands


func _execute_emit(effect_spec: Dictionary, event: CombatEvent, services: Dictionary, router: TriggerRouter) -> Dictionary:
	var next_event_type := StringName(effect_spec.get("event_type", event.event_type))
	var next_event_id := StringName(effect_spec.get("event_id", &""))
	var payload := _merged_payload(event.payload, effect_spec.get("payload", {}) as Dictionary)
	var command := _build_command(effect_spec, event, TYPE_EMIT_EVENT)
	command["next_event_type"] = next_event_type
	command["next_event_id"] = next_event_id
	command["payload"] = payload.duplicate(true)
	if router == null:
		command["children"] = []
		command["blocked"] = true
		command["reason"] = &"missing_router"
		return command
	var child_results := router.emit_child_event(event, next_event_type, next_event_id, payload, services)
	command["children"] = child_results
	return command


func _execute_command(effect_spec: Dictionary, event: CombatEvent, command_type: StringName, services: Dictionary) -> Dictionary:
	var command := _build_command(effect_spec, event, command_type)
	_call_service(command_type, command, event, services)
	return command


func _build_command(effect_spec: Dictionary, event: CombatEvent, command_type: StringName) -> Dictionary:
	var command := effect_spec.duplicate(true)
	command["command"] = command_type
	command["event_type"] = event.event_type
	command["event_id"] = event.event_id
	command["source_id"] = event.source_id
	command["owner_id"] = event.owner_id
	command["chain_id"] = event.context.chain_id if event.context != null else &""
	command["event_payload"] = event.payload.duplicate(true)
	for key in effect_spec.keys():
		if String(key).ends_with("_key"):
			var field := String(key).trim_suffix("_key")
			command[field] = event.payload.get(String(effect_spec[key]), command.get(field, null))
	return command


func _call_service(command_type: StringName, command: Dictionary, event: CombatEvent, services: Dictionary) -> void:
	if not services.has(command_type):
		return
	var callback: Variant = services[command_type]
	if callback is Callable and (callback as Callable).is_valid():
		(callback as Callable).call(command, event)


func _resolve_value(effect_spec: Dictionary, event: CombatEvent, field: String, default_value: Variant) -> Variant:
	var key_field := "%s_key" % field
	if effect_spec.has(key_field):
		return event.payload.get(String(effect_spec[key_field]), default_value)
	return effect_spec.get(field, default_value)


func _merged_payload(base_payload: Dictionary, extra_payload: Dictionary) -> Dictionary:
	var result := base_payload.duplicate(true)
	for key in extra_payload.keys():
		result[key] = extra_payload[key]
	return result


func _conditions_pass(effect_spec: Dictionary, event: CombatEvent) -> bool:
	if effect_spec.has("requires_payload"):
		var requirements: Dictionary = effect_spec.get("requires_payload", {}) as Dictionary
		for key in requirements.keys():
			if event.payload.get(key, null) != requirements[key]:
				return false
	if effect_spec.has("requires_tag"):
		var tag_list_key := String(effect_spec.get("tag_list_key", "tags"))
		var tags: Array = event.payload.get(tag_list_key, []) as Array
		if not tags.has(effect_spec["requires_tag"]):
			return false
	if effect_spec.has("requires_flag"):
		var flag_key := String(effect_spec["requires_flag"])
		if not bool(event.payload.get(flag_key, false)):
			return false
	return true
