extends RefCounted
class_name CombatMonsterRuntime


static func update_monsters(runtime: CombatRuntime, delta: float, wall_stop_y: float) -> Array:
	var survivors: Array = []
	for item in runtime.active_monsters:
		if not (item is Dictionary):
			continue
		var monster := (item as Dictionary).duplicate(true)
		runtime._update_statuses(monster, delta)
		if float(monster.get("hp", 0.0)) <= 0.0:
			on_monster_defeated(runtime, monster)
			continue
		var position: Vector2 = monster.get("position", Vector2.ZERO)
		if position.y < wall_stop_y:
			position.y += float(monster.get("speed", 0.0)) * runtime._monster_speed_mul(monster) * delta
			position.y = minf(position.y, wall_stop_y)
			monster["position"] = position
		else:
			monster = update_monster_attack(runtime, monster, delta)
		survivors.append(monster)
	return survivors


static func update_monster_attack(runtime: CombatRuntime, monster: Dictionary, delta: float) -> Dictionary:
	var attack_timer := float(monster.get("attack_timer", 0.0)) - delta
	if attack_timer <= 0.0:
		runtime.state.apply_wall_damage(int(monster.get("damage", 0)))
		attack_timer = float(monster.get("attack_interval", 1.4))
		runtime._add_combat_effect(monster.get("position", Vector2.ZERO), "wall_hit", float(monster.get("damage", 0)))
	monster["attack_timer"] = attack_timer
	return monster


static func on_monster_defeated(runtime: CombatRuntime, monster: Dictionary) -> void:
	var monster_id := String(monster.get("monster_id", ""))
	var monster_type := String(monster.get("type", ""))
	gain_exp_from_kill(runtime, int(monster.get("exp", 0)))
	runtime._add_combat_effect(monster.get("position", Vector2.ZERO), "defeat", float(monster.get("exp", 0)))
	if monster_id == "boss" or monster_id == "5000" or monster_type == "boss":
		runtime.state.boss_spawned = true
		runtime.state.boss_defeated = true


static func gain_exp_from_kill(runtime: CombatRuntime, amount: int) -> void:
	if int(runtime.state.phase) == 3 or int(runtime.state.phase) == 4:
		return
	runtime.state.grant_kill_progress(amount)


static func monster_by_id(monsters: Array, monster_id: String) -> Dictionary:
	var index := monster_index_by_id(monsters, monster_id)
	if index == -1:
		return {}
	return (monsters[index] as Dictionary).duplicate(true)


static func monster_index_by_id(monsters: Array, monster_id: String) -> int:
	var index := 0
	while index < monsters.size():
		if String((monsters[index] as Dictionary).get("id", "")) == monster_id:
			return index
		index += 1
	return -1
