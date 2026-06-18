extends RefCounted
class_name CardChainRules

const BASE_NUMERIC_FIELDS := {
	"thermobaric":
	[
		"projectile_count",
		"impact_damage",
		"explosion_damage",
		"knockback_distance",
		"burn_duration",
		"burn_total_damage",
		"spark_count",
	],
	"dry_ice":
	[
		"projectile_count",
		"damage",
		"pierce_count",
		"knockback_distance",
		"freeze_duration",
		"frostbite_duration",
		"frostbite_max_stack",
		"small_ice_count",
		"small_ice_pierce_count",
	],
	"electro_pierce":
	[
		"projectile_count",
		"pierce_damage",
		"paralyze_duration",
		"explosion_damage",
		"explosion_radius",
		"matrix_duration",
		"matrix_tick_damage",
		"matrix_slow_duration",
		"particle_count",
		"particle_pierce_count",
	],
}
const INTEGER_FIELDS := [
	"projectile_count",
	"pierce_count",
	"spark_count",
	"small_ice_count",
	"small_ice_pierce_count",
	"frostbite_max_stack",
	"particle_count",
	"particle_pierce_count",
]
const EFFECT_SPECS := {
	"thermobaric_probe": {"mul": {"explosion_damage": 1.2}},
	"thermobaric_pressure_calibration": {"mul": {"explosion_radius": 1.2}},
	"thermobaric_barrage": {"add": {"projectile_count": 1}, "mul": {"impact_damage": 0.8, "explosion_damage": 0.8}},
	"thermal_explosion": {"mul": {"explosion_damage": 1.8}},
	"thermobaric_impact": {"mul": {"impact_damage": 1.8, "knockback_distance": 1.75}},
	"thermal_burst": {"mul": {"explosion_radius": 1.2}},
	"thermal_ignite": {"set": {"burn_enabled": true}},
	"rich_fuel_fill": {"mul": {"impact_damage": 1.2, "explosion_damage": 1.2, "spark_damage": 1.2, "burn_total_damage": 1.2}},
	"explosion_sparks": {"set": {"spawn_sparks_enabled": true}},
	"thermobaric_draw_supply": {"mul": {"impact_damage": 0.8, "explosion_damage": 0.8, "burn_total_damage": 0.8}},
	"dry_ice_probe": {"mul": {"damage": 1.15}},
	"condensation_calibration": {"add": {"pierce_count": 1}},
	"scatter_small_ice": {"set": {"split_on_first_hit": true}},
	"low_temperature_pierce": {"mul": {"damage": 1.3}, "add": {"pierce_count": 2}},
	"condensed_heavy_ice": {"mul": {"projectile_speed": 0.7, "damage": 1.5}, "add": {"pierce_count": 1}},
	"dry_ice_damage_boost": {"mul": {"damage": 1.6}},
	"flash_freeze_ice": {"mul": {"damage": 1.3}, "set": {"freeze_enabled": true}},
	"dry_ice_barrage": {"add": {"projectile_count": 1}, "mul": {"damage": 0.8}},
	"frostbite_invasion": {"set": {"frostbite_enabled": true}},
	"dry_ice_volley": {"add": {"projectile_count": 1}},
	"heavy_ice_pierce": {"mul": {"knockback_distance": 1.2}, "add": {"pierce_count": 2}},
	"dry_ice_draw_supply": {"mul": {"damage": 0.8}},
	"capacitor_test": {"mul": {"pierce_damage": 1.2}},
	"magnetic_pole_calibration": {"mul": {"explosion_radius": 1.2}},
	"electro_explosion": {"set": {"explosion_enabled": true}},
	"electro_explosion_damage": {"mul": {"explosion_damage": 1.8}, "set": {"explosion_enabled": true}},
	"electro_explosion_expand": {"mul": {"explosion_radius": 1.2}, "set": {"explosion_enabled": true}},
	"electro_matrix": {"set": {"explosion_enabled": true, "matrix_enabled": true}},
	"electro_diversion": {"add": {"projectile_count": 1}, "mul": {"pierce_damage": 0.8}},
	"paralyze_damage": {"mul": {"pierce_damage": 1.3}, "add": {"paralyze_duration": 1.5}},
	"electro_fission": {"set": {"fission_enabled": true}},
	"electro_diversion_plus": {"add": {"projectile_count": 1}},
	"electro_draw_supply": {"mul": {"pierce_damage": 0.8, "explosion_damage": 0.8, "matrix_tick_damage": 0.8}},
}


static func get_card_effect_spec(card_id: String) -> Dictionary:
	var effect_spec: Dictionary = EFFECT_SPECS.get(card_id, {}) as Dictionary
	return effect_spec.duplicate(true)


static func apply_base_multiplier(core_skill: String, payload: Dictionary, chain_scale: int) -> void:
	if chain_scale <= 1:
		return
	var fields: Array = BASE_NUMERIC_FIELDS.get(core_skill, []) as Array
	for field in fields:
		var key := String(field)
		if payload.has(key):
			_set_payload_number(payload, key, float(payload.get(key, 0.0)) * float(chain_scale))


static func apply_effect_spec(payload: Dictionary, effect_spec: Dictionary, chain_scale: int) -> void:
	var sets: Dictionary = effect_spec.get("set", {}) as Dictionary
	for key in sets.keys():
		payload[key] = sets[key]
	var muls: Dictionary = effect_spec.get("mul", {}) as Dictionary
	for key in muls.keys():
		var field := String(key)
		var multiplier := _scaled_positive_multiplier(float(muls[key]), chain_scale)
		_set_payload_number(payload, field, float(payload.get(field, 0.0)) * multiplier)
	var adds: Dictionary = effect_spec.get("add", {}) as Dictionary
	for key in adds.keys():
		var field := String(key)
		var amount := _scaled_positive_add(float(adds[key]), chain_scale)
		_set_payload_number(payload, field, float(payload.get(field, 0.0)) + amount)


static func _scaled_positive_multiplier(multiplier: float, chain_scale: int) -> float:
	if multiplier > 1.0:
		return 1.0 + (multiplier - 1.0) * float(chain_scale)
	return multiplier


static func _scaled_positive_add(amount: float, chain_scale: int) -> float:
	if amount > 0.0:
		return amount * float(chain_scale)
	return amount


static func _set_payload_number(payload: Dictionary, key: String, value: float) -> void:
	if INTEGER_FIELDS.has(key):
		payload[key] = maxi(0, int(value + 0.5))
	else:
		payload[key] = value
