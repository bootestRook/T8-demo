extends RefCounted
class_name CombatAreaRuntime


static func update_areas(runtime: CombatRuntime, delta: float, router: TriggerRouter, default_center: Vector2) -> Array:
	var survivors: Array = []
	for item in runtime.active_areas:
		if not (item is Dictionary):
			continue
		var area := (item as Dictionary).duplicate(true)
		area["remaining"] = float(area.get("remaining", 0.0)) - delta
		area["tick_timer"] = float(area.get("tick_timer", 0.0)) - delta
		if float(area.get("tick_timer", 0.0)) <= 0.0:
			area["tick_timer"] = float(area.get("tick_interval", 0.5))
			route_area_tick(runtime, area, router, default_center)
		if float(area.get("remaining", 0.0)) > 0.0:
			survivors.append(area)
	return survivors


static func spawn_area(runtime: CombatRuntime, command: Dictionary, event: CombatEvent, default_center: Vector2) -> void:
	var center: Vector2 = event.payload.get(String(command.get("center_key", "")), default_center)
	(
		runtime
		. active_areas
		. append(
			{
				"id": runtime._next_entity_id("area"),
				"area_id": String(command.get("area_id", "area")),
				"position": center,
				"radius": runtime._combat_radius(float(command.get("radius", 120.0))),
				"remaining": float(command.get("duration", 2.0)),
				"tick_interval": float(command.get("tick_interval", 0.5)),
				"tick_timer": 0.0,
				"on_tick_event_id": StringName(command.get("on_tick_event_id", &"")),
				"payload": event.payload.duplicate(true),
			}
		)
	)


static func route_area_tick(runtime: CombatRuntime, area: Dictionary, router: TriggerRouter, default_center: Vector2) -> void:
	var event_id := StringName(area.get("on_tick_event_id", &""))
	if event_id == &"" or router == null:
		return
	var payload: Dictionary = (area.get("payload", {}) as Dictionary).duplicate(true)
	payload["area_center"] = area.get("position", default_center)
	payload["area_radius"] = float(area.get("radius", 120.0))
	var event := CombatEvent.create(CombatEvent.TYPE_TICK, event_id, StringName(area.get("area_id", "area")), &"player", payload)
	router.route(event, runtime._combat_services())
