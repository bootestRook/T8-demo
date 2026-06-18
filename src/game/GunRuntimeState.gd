extends RefCounted
class_name GunRuntimeState

const DEFAULT_BULLET_DAMAGE := 30.0
const SHOT_LOG_LIMIT := 12

var runtime: Dictionary = {}
var ammo := 0
var is_reloading := false
var reload_timer := 0.0
var fire_timer := 0.0


func reset(initial_ammo: int, initial_fire_interval: float, initial_reload_time: float) -> void:
	runtime = {
		"bullet_damage_mul": 1.0,
		"sub_bullet_damage_mul": 1.0,
		"fire_interval": initial_fire_interval,
		"burst_count": 1,
		"gun_projectile_count": 1,
		"max_ammo": initial_ammo,
		"reload_time": initial_reload_time,
		"infinite_ammo_remaining": 0.0,
		"cease_fire_remaining": 0.0,
		"queued_focus_buff": false,
		"temp_damage_mul": 1.0,
		"temp_damage_remaining": 0.0,
		"temp_fire_interval_mul": 1.0,
		"temp_fire_interval_remaining": 0.0,
		"base_damage_growth_mul": 1.0,
		"on_hit_effects": [],
		"core_skills":
		{
			"thermobaric": _new_core_skill_runtime(),
			"dry_ice": _new_core_skill_runtime(),
			"electro_pierce": _new_core_skill_runtime(),
		},
		"shot_log": [],
	}
	ammo = int(runtime.get("max_ammo", initial_ammo))
	is_reloading = false
	reload_timer = 0.0
	fire_timer = float(runtime.get("fire_interval", initial_fire_interval))


func tick_buffs(delta: float) -> void:
	_tick_runtime_timer("infinite_ammo_remaining", delta)
	_tick_runtime_timer("temp_damage_remaining", delta)
	if float(runtime.get("temp_damage_remaining", 0.0)) <= 0.0:
		runtime["temp_damage_mul"] = 1.0
	_tick_runtime_timer("temp_fire_interval_remaining", delta)
	if float(runtime.get("temp_fire_interval_remaining", 0.0)) <= 0.0:
		runtime["temp_fire_interval_mul"] = 1.0
	var before_cease := float(runtime.get("cease_fire_remaining", 0.0))
	_tick_runtime_timer("cease_fire_remaining", delta)
	if before_cease > 0.0 and float(runtime.get("cease_fire_remaining", 0.0)) <= 0.0 and bool(runtime.get("queued_focus_buff", false)):
		apply_timed_buff(
			float(runtime.get("queued_focus_damage_mul", 1.0)),
			float(runtime.get("queued_focus_fire_interval_mul", 1.0)),
			float(runtime.get("queued_focus_duration", 0.0))
		)
		runtime["queued_focus_buff"] = false


func tick_fire(delta: float, combat_runtime: CombatRuntime, combat_router: TriggerRouter, elapsed_time: float) -> Dictionary:
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			ammo = int(runtime.get("max_ammo", ammo))
			is_reloading = false
		return {}
	fire_timer -= delta
	if fire_timer > 0.0:
		return {}
	if float(runtime.get("cease_fire_remaining", 0.0)) > 0.0:
		return {}
	if combat_runtime == null or not combat_runtime.has_living_targets():
		return {}
	if ammo <= 0:
		start_reload()
		return {"status_text": "reloading"}
	var fire_event := _build_fire_event()
	if float(runtime.get("infinite_ammo_remaining", 0.0)) <= 0.0:
		ammo -= 1
	var commands := combat_runtime.route_event(fire_event, combat_router)
	_record_shot(elapsed_time, fire_event, commands)
	fire_timer = current_fire_interval()
	return {}


func start_reload() -> void:
	is_reloading = true
	reload_timer = float(runtime.get("reload_time", reload_timer))


func apply_timed_buff(damage_mul: float, fire_interval_mul: float, duration: float) -> void:
	if duration <= 0.0:
		return
	runtime["temp_damage_mul"] = maxf(float(runtime.get("temp_damage_mul", 1.0)), damage_mul)
	runtime["temp_damage_remaining"] = maxf(float(runtime.get("temp_damage_remaining", 0.0)), duration)
	runtime["temp_fire_interval_mul"] = minf(float(runtime.get("temp_fire_interval_mul", 1.0)), fire_interval_mul)
	runtime["temp_fire_interval_remaining"] = maxf(float(runtime.get("temp_fire_interval_remaining", 0.0)), duration)


func extend_infinite_ammo(duration: float) -> void:
	runtime["infinite_ammo_remaining"] = maxf(float(runtime.get("infinite_ammo_remaining", 0.0)), duration)


func reload_ammo_ratio(ratio: float) -> void:
	var max_ammo := int(runtime.get("max_ammo", ammo))
	ammo = mini(max_ammo, ammo + maxi(1, int(float(max_ammo) * ratio + 0.5)))
	if ammo > 0:
		is_reloading = false
		reload_timer = 0.0


func queue_focus_buff(rest_duration: float, damage_mul: float, fire_interval_mul: float, duration: float) -> void:
	runtime["cease_fire_remaining"] = maxf(float(runtime.get("cease_fire_remaining", 0.0)), rest_duration)
	runtime["queued_focus_buff"] = true
	runtime["queued_focus_damage_mul"] = damage_mul
	runtime["queued_focus_fire_interval_mul"] = fire_interval_mul
	runtime["queued_focus_duration"] = duration


func set_base_damage_growth_mul(value: float) -> void:
	runtime["base_damage_growth_mul"] = value


func get_core_skill_runtime(core_skill: String) -> Dictionary:
	var core_skills: Dictionary = runtime.get("core_skills", {})
	return (core_skills.get(core_skill, {}) as Dictionary).duplicate(true)


func get_core_skill_snapshot() -> Dictionary:
	return (runtime.get("core_skills", {}) as Dictionary).duplicate(true)


func current_gun_damage_mul() -> float:
	return float(runtime.get("bullet_damage_mul", 1.0)) * current_gun_base_temp_damage_mul()


func current_gun_base_temp_damage_mul() -> float:
	return float(runtime.get("base_damage_growth_mul", 1.0)) * float(runtime.get("temp_damage_mul", 1.0))


func current_fire_interval() -> float:
	return maxf(0.05, float(runtime.get("fire_interval", 0.5)) * float(runtime.get("temp_fire_interval_mul", 1.0)))


func _build_fire_event() -> CombatEvent:
	var damage_mul := current_gun_damage_mul()
	var base_temp_damage_mul := current_gun_base_temp_damage_mul()
	var payload := {
		"gun_projectile_count": int(runtime.get("gun_projectile_count", 1)),
		"bullet_damage": DEFAULT_BULLET_DAMAGE * damage_mul,
		"split_bullet_damage": DEFAULT_BULLET_DAMAGE * float(runtime.get("sub_bullet_damage_mul", 1.0)) * base_temp_damage_mul,
		"bullet_explosion_damage": DEFAULT_BULLET_DAMAGE * damage_mul,
		"bullet_explosion_radius": 1.0,
		"split_count": 2,
		"split_mode": &"nearest",
		"on_hit_effects": (runtime.get("on_hit_effects", []) as Array).duplicate(true),
	}
	return CombatEvent.create(CombatEvent.TYPE_CAST, GunEvents.FIRE, &"player_gun", &"player", payload)


func _record_shot(elapsed_time: float, fire_event: CombatEvent, commands: Array) -> void:
	var shot_event := {
		"time": elapsed_time,
		"target_rule": "nearest_to_wall",
		"burst_count": int(runtime.get("burst_count", 1)),
		"projectile_count": int(runtime.get("gun_projectile_count", 1)),
		"bullet_damage_mul": float(runtime.get("bullet_damage_mul", 1.0)),
		"on_hit_effects": (runtime.get("on_hit_effects", []) as Array).duplicate(true),
		"trigger_event": fire_event.to_dictionary(),
		"commands": commands,
	}
	var shot_log: Array = runtime.get("shot_log", [])
	shot_log.append(shot_event)
	while shot_log.size() > SHOT_LOG_LIMIT:
		shot_log.remove_at(0)
	runtime["shot_log"] = shot_log


func _tick_runtime_timer(key: String, delta: float) -> void:
	runtime[key] = maxf(0.0, float(runtime.get(key, 0.0)) - delta)


func _new_core_skill_runtime() -> Dictionary:
	return {
		"projectile_count": 1,
		"release_count": 1,
		"release_interval": 0.16,
	}
