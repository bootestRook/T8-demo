extends RefCounted
class_name GunRuntime

const DEFAULT_BULLET_DAMAGE := 30.0

var bullet_damage_mul := 1.0
var split_bullet_damage_mul := 1.0
var fire_interval := 0.5
var burst_count := 1
var gun_projectile_count := 1
var max_ammo := 30
var reload_time := 2.0
var on_hit_effects: Array[StringName] = []


func to_fire_payload() -> Dictionary:
	return {
		"gun_projectile_count": gun_projectile_count,
		"bullet_damage": DEFAULT_BULLET_DAMAGE * bullet_damage_mul,
		"split_bullet_damage": DEFAULT_BULLET_DAMAGE * split_bullet_damage_mul,
		"bullet_explosion_damage": DEFAULT_BULLET_DAMAGE * bullet_damage_mul,
		"bullet_explosion_radius": 1.0,
		"split_count": 2,
		"split_mode": &"nearest",
		"on_hit_effects": on_hit_effects.duplicate(true),
	}


func build_fire_event(owner_id: StringName) -> CombatEvent:
	return CombatEvent.create(CombatEvent.TYPE_CAST, GunEvents.FIRE, &"player_gun", owner_id, to_fire_payload())


func apply_upgrade(upgrade_id: StringName) -> void:
	match upgrade_id:
		&"bullet_explosion":
			_add_on_hit_effect(&"bullet_explosion")
		&"split_bullet":
			_add_on_hit_effect(&"split_bullet")
		&"split_bullet_four_way":
			_add_on_hit_effect(&"split_bullet_four_way")
		&"bullet_head":
			bullet_damage_mul += 1.0
			split_bullet_damage_mul += 1.0
		&"bullet_damage":
			bullet_damage_mul += 0.6
		&"fire_rate":
			fire_interval *= 0.9
		&"burst_fire":
			burst_count += 1
			bullet_damage_mul *= 0.8
		&"multi_projectile":
			gun_projectile_count += 1
			bullet_damage_mul *= 0.8


func _add_on_hit_effect(effect_id: StringName) -> void:
	if not on_hit_effects.has(effect_id):
		on_hit_effects.append(effect_id)
