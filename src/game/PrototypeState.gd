extends Node

enum Phase { PLAYING, UPGRADE, WON, LOST }

# Review aliases for the common loop gate: Phase.SUCCESS maps to WON, Phase.FAILURE maps to LOST.
# CoreLoopContract / RunState / RewardDraft / MetaProgress are implemented in this script and ContentUnits.

const CONCEPT_ID := "vertical-defense-card-v1"
const WALL_MAX_HP := 1000.0
const WALL_Y := 1680.0
const ATTACK_RANGE_Y := 1540.0
const HAND_LIMIT := 4
const MAX_LEVEL := 20
const DISCARD_COOLDOWN := 20.0
const REFILL_INTERVAL := 1.5
const SAME_NAME_WINDOW := 10.0
const SAME_NAME_TRIGGER_COUNT := 3
const SAME_NAME_COOLDOWN := 10.0
const BATTLE_DURATION := 300.0
const GUN_BASE_DAMAGE := 55.0
const GUN_BASE_INTERVAL := 0.8
const GUN_MAX_AMMO := 30
const GUN_RELOAD_TIME := 2.0
const LANES: Array[float] = [170.0, 335.0, 500.0, 665.0, 830.0, 995.0]

signal phase_changed(new_phase: Phase)
signal status_changed(new_status: String)
signal score_changed(new_score: int)
signal hp_changed(new_hp: int)
signal time_changed(new_time: float)
signal state_changed(snapshot: Dictionary)
signal feedback_requested(kind: String, payload: Dictionary)

var phase: Phase = Phase.PLAYING
var concept_id := CONCEPT_ID
var status_text := "防守 5 分钟并击败 Boss"
var battle_time := 0.0
var wall_hp := WALL_MAX_HP
var score := 0
var kills := 0
var level := 1
var exp_value := 0.0
var exp_to_next := 10.0
var current_energy := 0.0
var energy_regen := 1.0
var max_energy := 3
var chain_multiplier := 1
var last_positive_cost := -1
var discard_timer := 0.0
var refill_timer := 0.0
var selected_unit := 0

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var deck: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var upgrade_choices: Array[Dictionary] = []
var chosen_upgrades: Array[String] = []
var last_event := "拖住防线，等待能量出牌"

var _next_enemy_id := 1
var _next_projectile_id := 1
var _next_effect_id := 1
var _next_wave_index := 0
var _spawn_queue: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _gun_fire_timer := 0.25
var _gun_ammo := GUN_MAX_AMMO
var _gun_reload_timer := 0.0
var _gun_damage_mul := 1.0
var _gun_interval_mul := 1.0
var _gun_burst_count := 1
var _gun_projectile_count := 1
var _gun_on_hit: Array[String] = []
var _card_power_mul: Dictionary = {}
var _core_projectile_add := {"thermobaric": 0, "dry_ice": 0, "electro_pierce": 0}
var _core_release_add := {"thermobaric": 0, "dry_ice": 0, "electro_pierce": 0}
var _next_modifiers := {"thermobaric": {}, "dry_ice": {}, "electro_pierce": {}}
var _same_name_streak_key := ""
var _same_name_streak_count := 0
var _same_name_streak_start := 0.0
var _same_name_cooldown_until := {}
var _waves: Array[Dictionary] = []

var cards: Array[Dictionary] = [
	{
		"id": "T0",
		"name": "试射温压弹",
		"same": "试射温压弹",
		"skill": "thermobaric",
		"cost": 0,
		"rarity": "normal",
		"unlock": 1,
		"text": "低伤温压弹；命中后下张温压爆炸+20%",
		"effect": "thermo_probe"
	},
	{
		"id": "T1",
		"name": "温压弹连发",
		"same": "温压弹连发",
		"skill": "thermobaric",
		"cost": 2,
		"rarity": "normal",
		"unlock": 1,
		"text": "额外释放 1 枚，伤害 -20%",
		"effect": "thermo_release"
	},
	{
		"id": "T2",
		"name": "热能爆炸",
		"same": "热能爆炸",
		"skill": "thermobaric",
		"cost": 2,
		"rarity": "normal",
		"unlock": 1,
		"text": "爆炸伤害 +80%",
		"effect": "thermo_boom"
	},
	{
		"id": "T3",
		"name": "热能爆发",
		"same": "热能爆发",
		"skill": "thermobaric",
		"cost": 3,
		"rarity": "rare",
		"unlock": 3,
		"text": "爆炸范围 +80%",
		"effect": "thermo_radius"
	},
	{
		"id": "T4",
		"name": "热能引燃",
		"same": "热能引燃",
		"skill": "thermobaric",
		"cost": 2,
		"rarity": "rare",
		"unlock": 4,
		"text": "爆炸燃烧 6 秒",
		"effect": "thermo_burn"
	},
	{
		"id": "D0",
		"name": "试射干冰弹",
		"same": "试射干冰弹",
		"skill": "dry_ice",
		"cost": 0,
		"rarity": "normal",
		"unlock": 1,
		"text": "低伤穿透；下张干冰伤害+15%",
		"effect": "dry_probe"
	},
	{
		"id": "D1",
		"name": "低温贯穿",
		"same": "低温贯穿",
		"skill": "dry_ice",
		"cost": 2,
		"rarity": "normal",
		"unlock": 1,
		"text": "伤害 +30%，穿透 +2",
		"effect": "dry_pierce"
	},
	{
		"id": "D2",
		"name": "急冻寒冰",
		"same": "急冻寒冰",
		"skill": "dry_ice",
		"cost": 3,
		"rarity": "rare",
		"unlock": 3,
		"text": "伤害 +30%，冻结 2 秒",
		"effect": "dry_freeze"
	},
	{
		"id": "D3",
		"name": "干冰弹齐射",
		"same": "干冰弹齐射",
		"skill": "dry_ice",
		"cost": 4,
		"rarity": "rare",
		"unlock": 5,
		"text": "干冰弹数量 +1",
		"effect": "dry_volley"
	},
	{
		"id": "E0",
		"name": "电容试放",
		"same": "电容试放",
		"skill": "electro_pierce",
		"cost": 0,
		"rarity": "normal",
		"unlock": 1,
		"text": "低伤穿刺；下张电磁伤害+20%",
		"effect": "electro_probe"
	},
	{
		"id": "E1",
		"name": "电磁爆炸",
		"same": "电磁爆炸",
		"skill": "electro_pierce",
		"cost": 1,
		"rarity": "normal",
		"unlock": 1,
		"text": "穿刺命中附带小爆炸",
		"effect": "electro_bomb"
	},
	{
		"id": "E2",
		"name": "电磁矩阵",
		"same": "电磁矩阵",
		"skill": "electro_pierce",
		"cost": 3,
		"rarity": "rare",
		"unlock": 4,
		"text": "爆炸处生成减速矩阵",
		"effect": "electro_matrix"
	},
	{
		"id": "E3",
		"name": "电磁裂变",
		"same": "电磁裂变",
		"skill": "electro_pierce",
		"cost": 4,
		"rarity": "epic",
		"unlock": 6,
		"text": "命中后释放 6 个粒子",
		"effect": "electro_fission"
	},
]

var upgrades: Array[Dictionary] = [
	{"id": "U_GUN_DMG", "name": "子弹增伤", "type": "gun", "text": "自动枪械伤害 +60%", "unlock": 1, "weight": 100},
	{"id": "U_GUN_RATE", "name": "射速提升", "type": "gun", "text": "自动枪械射击间隔 -10%", "unlock": 1, "weight": 90},
	{"id": "U_GUN_EXPLODE", "name": "子弹爆炸", "type": "gun", "text": "子弹命中后小范围爆炸", "unlock": 2, "weight": 85},
	{"id": "U_GUN_BURST", "name": "连发射击", "type": "gun", "text": "每次射击连发 +1，单发伤害 -20%", "unlock": 3, "weight": 80},
	{"id": "U_WALL_HP", "name": "加固城墙", "type": "survival", "text": "城墙回复 20% 并提高最大耐久感", "unlock": 1, "weight": 85},
	{"id": "U_ENERGY_REGEN", "name": "能量回路", "type": "energy", "text": "能量回复 +15%", "unlock": 1, "weight": 90},
	{"id": "U_REFILL", "name": "快速补牌", "type": "energy", "text": "补牌间隔 -15%", "unlock": 2, "weight": 75},
	{"id": "U_THERMO_COUNT", "name": "温压弹数量+1", "type": "core", "skill": "thermobaric", "text": "温压弹卡牌每次多发 1 枚", "unlock": 3, "weight": 70},
	{"id": "U_DRY_COUNT", "name": "干冰弹数量+1", "type": "core", "skill": "dry_ice", "text": "干冰弹卡牌每次多发 1 枚", "unlock": 3, "weight": 70},
	{
		"id": "U_ELECTRO_RELEASE",
		"name": "电磁穿刺额外释放",
		"type": "core",
		"skill": "electro_pierce",
		"text": "电磁穿刺卡牌额外释放 1 次",
		"unlock": 4,
		"weight": 70
	},
	{"id": "U_CARD_POWER", "name": "强化已有卡牌", "type": "card_upgrade", "text": "随机一张已拥有卡牌伤害 +20%", "unlock": 2, "weight": 95},
	{"id": "U_CARD_ADD", "name": "获得新卡牌", "type": "card_add", "text": "把一张当前等级可用卡加入牌库", "unlock": 1, "weight": 100},
]


func _ready() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	phase = Phase.PLAYING
	battle_time = 0.0
	wall_hp = WALL_MAX_HP
	score = 0
	kills = 0
	level = 1
	exp_value = 0.0
	exp_to_next = 10.0
	current_energy = 3.0
	energy_regen = 1.0
	max_energy = 3
	chain_multiplier = 1
	last_positive_cost = -1
	discard_timer = 0.0
	refill_timer = 0.0
	_next_enemy_id = 1
	_next_projectile_id = 1
	_next_effect_id = 1
	_next_wave_index = 0
	_spawn_queue.clear()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	floaters.clear()
	upgrade_choices.clear()
	chosen_upgrades.clear()
	_card_power_mul.clear()
	_core_projectile_add = {"thermobaric": 0, "dry_ice": 0, "electro_pierce": 0}
	_core_release_add = {"thermobaric": 0, "dry_ice": 0, "electro_pierce": 0}
	_next_modifiers = {"thermobaric": {}, "dry_ice": {}, "electro_pierce": {}}
	_same_name_streak_key = ""
	_same_name_streak_count = 0
	_same_name_streak_start = 0.0
	_same_name_cooldown_until.clear()
	_gun_fire_timer = 0.25
	_gun_ammo = GUN_MAX_AMMO
	_gun_reload_timer = 0.0
	_gun_damage_mul = 1.0
	_gun_interval_mul = 1.0
	_gun_burst_count = 1
	_gun_projectile_count = 1
	_gun_on_hit.clear()
	_build_waves()
	_build_starting_deck()
	_draw_to_full()
	last_event = "防线启动：自动枪械会保底输出，点手牌释放技能"
	status_text = last_event
	_emit_all()


func tick(delta: float) -> void:
	if phase != Phase.PLAYING:
		_emit_all()
		return
	battle_time += delta
	discard_timer = maxf(0.0, discard_timer - delta)
	current_energy = minf(float(max_energy), current_energy + energy_regen * delta)
	_process_waves()
	_process_spawn_queue(delta)
	_process_enemy_status(delta)
	_process_enemies(delta)
	_process_effects(delta)
	_process_projectiles(delta)
	_process_gun(delta)
	_process_refill(delta)
	_process_floaters(delta)
	_check_end_state()
	_emit_all()


func try_play_hand(index: int) -> bool:
	if phase != Phase.PLAYING or index < 0 or index >= hand.size():
		return false
	var card := hand[index]
	var cost := int(card.get("cost", 0))
	var same := String(card.get("same", card.get("name", "")))
	if _same_name_cooldown_until.get(same, 0.0) > battle_time:
		last_event = "%s 过热冷却中" % String(card.get("name", "卡牌"))
		_emit_all()
		return false
	if current_energy + 0.001 < float(cost):
		last_event = "能量不足：%s 需要 %d" % [String(card.get("name", "卡牌")), cost]
		_emit_all()
		return false
	current_energy -= float(cost)
	_update_chain(cost)
	_cast_card(card)
	_update_same_name(same)
	discard_pile.append(card)
	hand.remove_at(index)
	refill_timer = minf(refill_timer, 0.2) if hand.size() < HAND_LIMIT else refill_timer
	last_event = "打出 %s：连锁 %dx" % [String(card.get("name", "卡牌")), chain_multiplier]
	_emit_feedback("card", {"name": card.get("name", ""), "skill": card.get("skill", "")})
	_emit_all()
	return true


func discard_hand() -> bool:
	if phase != Phase.PLAYING or discard_timer > 0.0 or hand.is_empty():
		return false
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	_break_chain()
	discard_timer = DISCARD_COOLDOWN
	_draw_to_full()
	last_event = "弃牌重抽：连锁中断"
	_emit_feedback("discard", {})
	_emit_all()
	return true


func choose_upgrade(index: int) -> bool:
	if phase != Phase.UPGRADE or index < 0 or index >= upgrade_choices.size():
		return false
	var upgrade := upgrade_choices[index]
	_apply_upgrade(upgrade)
	chosen_upgrades.append(String(upgrade.get("name", "升级")))
	upgrade_choices.clear()
	phase = Phase.PLAYING
	last_event = "选择升级：%s" % String(upgrade.get("name", "升级"))
	_emit_feedback("upgrade", upgrade)
	_emit_all()
	return true


func get_snapshot() -> Dictionary:
	return {
		"concept_id": concept_id,
		"phase": phase,
		"status_text": status_text,
		"last_event": last_event,
		"battle_time": battle_time,
		"remaining_time": maxf(0.0, BATTLE_DURATION - battle_time),
		"wall_hp": wall_hp,
		"wall_max_hp": WALL_MAX_HP,
		"score": score,
		"kills": kills,
		"level": level,
		"exp": exp_value,
		"exp_to_next": exp_to_next,
		"energy": current_energy,
		"max_energy": max_energy,
		"energy_regen": energy_regen,
		"chain": chain_multiplier,
		"discard_cd": discard_timer,
		"hand": hand.duplicate(true),
		"deck_count": deck.size(),
		"discard_count": discard_pile.size(),
		"upgrade_choices": upgrade_choices.duplicate(true),
		"enemies": enemies.duplicate(true),
		"projectiles": projectiles.duplicate(true),
		"effects": effects.duplicate(true),
		"floaters": floaters.duplicate(true),
		"gun_ammo": _gun_ammo,
		"gun_max_ammo": GUN_MAX_AMMO,
		"gun_reloading": _gun_reload_timer > 0.0,
		"chosen_upgrades": chosen_upgrades.duplicate(),
	}


func _build_waves() -> void:
	_waves = ContentUnits.wave_configs.duplicate(true)


func _build_starting_deck() -> void:
	deck.clear()
	var ids := ["T0", "T1", "T2", "D0", "D1", "E0", "E1", "E1"]
	for id in ids:
		deck.append(_card_by_id(id))
	_shuffle_deck()


func _process_waves() -> void:
	while _next_wave_index < _waves.size() and float(_waves[_next_wave_index].get("time", 0.0)) <= battle_time:
		var wave := _waves[_next_wave_index]
		_next_wave_index += 1
		for i in int(wave.get("count", 1)):
			_spawn_queue.append({"delay": float(wave.get("interval", 0.0)) * float(i), "wave": wave})
		last_event = "新波次：%s x%d" % [String(wave.get("monster", "normal")), int(wave.get("count", 1))]


func _process_spawn_queue(delta: float) -> void:
	for i in range(_spawn_queue.size() - 1, -1, -1):
		_spawn_queue[i]["delay"] = float(_spawn_queue[i].get("delay", 0.0)) - delta
		if float(_spawn_queue[i].get("delay", 0.0)) <= 0.0:
			_spawn_enemy(_spawn_queue[i].get("wave", {}) as Dictionary)
			_spawn_queue.remove_at(i)


func _spawn_enemy(wave: Dictionary) -> void:
	var monster_id := String(wave.get("monster", "normal"))
	var spec := _monster_spec(monster_id)
	var hp := float(spec.get("hp", 90.0)) * float(wave.get("hp_mul", 1.0))
	var lane := LANES[_rng.randi_range(0, LANES.size() - 1)]
	if monster_id == "elite" or monster_id == "boss":
		lane = 540.0
	(
		enemies
		. append(
			{
				"id": _next_enemy_id,
				"kind": monster_id,
				"name": spec.get("name", monster_id),
				"pos": Vector2(lane, -80.0),
				"hp": hp,
				"max_hp": hp,
				"speed": float(spec.get("speed", 72.0)) * float(wave.get("speed_mul", 1.0)),
				"attack": float(spec.get("attack", 20.0)),
				"attack_interval": float(spec.get("attack_interval", 1.5)),
				"attack_timer": 0.4,
				"exp": int(spec.get("exp", 2)),
				"radius": float(spec.get("radius", 28.0)),
				"freeze_mul": float(spec.get("freeze_mul", 1.0)),
				"paralyze_mul": float(spec.get("paralyze_mul", 1.0)),
				"frozen": 0.0,
				"paralyzed": 0.0,
				"burn": [],
				"frostbite": [],
				"slow": 1.0,
			}
		)
	)
	_next_enemy_id += 1


func _process_enemy_status(delta: float) -> void:
	for enemy in enemies:
		enemy["frozen"] = maxf(0.0, float(enemy.get("frozen", 0.0)) - delta)
		enemy["paralyzed"] = maxf(0.0, float(enemy.get("paralyzed", 0.0)) - delta)
		_process_dot(enemy, "burn", delta)
		_process_dot(enemy, "frostbite", delta)
		enemy["slow"] = 1.0
	for effect in effects:
		if String(effect.get("kind", "")) == "matrix":
			for enemy in _enemies_in_radius(effect.get("pos", Vector2.ZERO), float(effect.get("radius", 90.0))):
				enemy["slow"] = minf(float(enemy.get("slow", 1.0)), 0.65)


func _process_dot(enemy: Dictionary, key: String, delta: float) -> void:
	var stacks: Array = enemy.get(key, [])
	for i in range(stacks.size() - 1, -1, -1):
		var stack: Dictionary = stacks[i]
		stack["remaining"] = float(stack.get("remaining", 0.0)) - delta
		stack["tick"] = float(stack.get("tick", 1.0)) - delta
		if float(stack.get("tick", 0.0)) <= 0.0:
			stack["tick"] = 1.0
			_deal_damage(enemy, float(stack.get("damage", 1.0)), key, false)
		if float(stack.get("remaining", 0.0)) <= 0.0:
			stacks.remove_at(i)
		enemy[key] = stacks


func _process_enemies(delta: float) -> void:
	for enemy in enemies:
		if float(enemy.get("frozen", 0.0)) > 0.0 or float(enemy.get("paralyzed", 0.0)) > 0.0:
			continue
		var pos := enemy.get("pos", Vector2.ZERO) as Vector2
		if pos.y < ATTACK_RANGE_Y:
			pos.y += float(enemy.get("speed", 60.0)) * float(enemy.get("slow", 1.0)) * delta
			enemy["pos"] = pos
		else:
			enemy["attack_timer"] = float(enemy.get("attack_timer", 0.0)) - delta
			if float(enemy.get("attack_timer", 0.0)) <= 0.0:
				wall_hp = maxf(0.0, wall_hp - float(enemy.get("attack", 10.0)))
				enemy["attack_timer"] = float(enemy.get("attack_interval", 1.5))
				_add_floater("城墙 -%d" % int(enemy.get("attack", 10.0)), Vector2(pos.x - 50.0, WALL_Y - 95.0), Color(1.0, 0.35, 0.22))


func _process_gun(delta: float) -> void:
	if _gun_reload_timer > 0.0:
		_gun_reload_timer -= delta
		if _gun_reload_timer <= 0.0:
			_gun_ammo = GUN_MAX_AMMO
		return
	_gun_fire_timer -= delta
	if _gun_fire_timer > 0.0:
		return
	if _gun_ammo <= 0:
		_gun_reload_timer = GUN_RELOAD_TIME
		last_event = "自动枪械换弹"
		return
	var target := _find_nearest_to_wall_enemy()
	if target.is_empty():
		_gun_fire_timer = 0.15
		return
	for burst in _gun_burst_count:
		for lane_shot in _gun_projectile_count:
			_fire_projectile(
				"bullet",
				Vector2(540.0 + (lane_shot - (_gun_projectile_count - 1) * 0.5) * 42.0, WALL_Y - 45.0),
				target,
				980.0,
				GUN_BASE_DAMAGE * _gun_damage_mul * (0.8 if _gun_burst_count > 1 or _gun_projectile_count > 1 else 1.0),
				1,
				Color(1.0, 0.85, 0.35),
				{}
			)
	_gun_ammo -= 1
	_gun_fire_timer = GUN_BASE_INTERVAL * _gun_interval_mul


func _process_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[i]
		var target := _enemy_by_id(int(projectile.get("target_id", -1)))
		if target.is_empty():
			projectiles.remove_at(i)
			continue
		var pos := projectile.get("pos", Vector2.ZERO) as Vector2
		var target_pos := target.get("pos", Vector2.ZERO) as Vector2
		var step := float(projectile.get("speed", 500.0)) * delta
		pos = pos.move_toward(target_pos, step)
		projectile["pos"] = pos
		projectiles[i] = projectile
		if pos.distance_to(target_pos) <= maxf(step, float(target.get("radius", 24.0))):
			_resolve_projectile_hit(projectile, target)
			projectiles.remove_at(i)


func _process_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["ttl"] = float(effects[i].get("ttl", 0.0)) - delta
		if String(effects[i].get("kind", "")) == "matrix":
			effects[i]["tick"] = float(effects[i].get("tick", 0.0)) - delta
			if float(effects[i].get("tick", 0.0)) <= 0.0:
				effects[i]["tick"] = 0.5
				for enemy in _enemies_in_radius(effects[i].get("pos", Vector2.ZERO), float(effects[i].get("radius", 90.0))):
					_deal_damage(enemy, 10.0 * float(chain_multiplier), "matrix")
		if float(effects[i].get("ttl", 0.0)) <= 0.0:
			effects.remove_at(i)


func _process_refill(delta: float) -> void:
	if hand.size() >= HAND_LIMIT:
		return
	refill_timer -= delta
	if refill_timer <= 0.0:
		_draw_one()
		refill_timer = REFILL_INTERVAL


func _process_floaters(delta: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i]["ttl"] = float(floaters[i].get("ttl", 0.0)) - delta
		var pos := floaters[i].get("pos", Vector2.ZERO) as Vector2
		pos.y -= 36.0 * delta
		floaters[i]["pos"] = pos
		if float(floaters[i].get("ttl", 0.0)) <= 0.0:
			floaters.remove_at(i)


func _cast_card(card: Dictionary) -> void:
	var skill := String(card.get("skill", ""))
	var releases := 1 + int(_core_release_add.get(skill, 0))
	var effect := String(card.get("effect", ""))
	if effect in ["thermo_release", "electro_pierce_release"]:
		releases += 1
	if effect == "electro_fission":
		releases += 0
	for release_index in releases:
		_cast_skill_release(card, release_index)


func _cast_skill_release(card: Dictionary, release_index: int) -> void:
	var skill := String(card.get("skill", ""))
	var count := 1 + int(_core_projectile_add.get(skill, 0))
	var effect := String(card.get("effect", ""))
	if effect == "dry_volley":
		count += 1
	for shot in count:
		var target := _find_nearest_to_wall_enemy(shot)
		if target.is_empty():
			return
		var offset := float(shot - (count - 1) * 0.5) * 36.0 + float(release_index) * 18.0
		match skill:
			"thermobaric":
				_fire_thermobaric(card, target, offset)
			"dry_ice":
				_fire_dry_ice(card, target, offset)
			"electro_pierce":
				_fire_electro(card, target, offset)


func _fire_thermobaric(card: Dictionary, target: Dictionary, offset: float) -> void:
	var spec := _consume_next_modifier("thermobaric")
	var impact_mul := 1.0 + float(spec.get("impact_add", 0.0))
	var explosion_mul := 1.0 + float(spec.get("explosion_add", 0.0))
	var radius_mul := 1.0 + float(spec.get("radius_add", 0.0))
	var knockback_mul := 1.0
	var effect := String(card.get("effect", ""))
	match effect:
		"thermo_probe":
			impact_mul *= 0.4
			explosion_mul *= 0.4
			radius_mul *= 0.7
		"thermo_release":
			impact_mul *= 0.8
			explosion_mul *= 0.8
		"thermo_boom":
			explosion_mul *= 1.8
		"thermo_radius":
			radius_mul *= 1.8
	var payload := {
		"skill": "thermobaric",
		"impact": 100.0 * impact_mul * _card_mul(card) * float(chain_multiplier),
		"explosion": 70.0 * explosion_mul * _card_mul(card) * float(chain_multiplier),
		"radius": 105.0 * radius_mul,
		"knockback": 70.0 * knockback_mul,
		"effect": effect
	}
	_fire_projectile(
		"thermobaric", Vector2(540.0 + offset, WALL_Y - 65.0), target, 760.0, payload["impact"], 1, Color(1.0, 0.32, 0.12), payload
	)


func _fire_dry_ice(card: Dictionary, target: Dictionary, offset: float) -> void:
	var spec := _consume_next_modifier("dry_ice")
	var damage_mul := 1.0 + float(spec.get("damage_add", 0.0))
	var pierce := 3 + int(spec.get("pierce_add", 0))
	var speed := 820.0
	var effect := String(card.get("effect", ""))
	match effect:
		"dry_probe":
			damage_mul *= 0.4
			pierce -= 1
		"dry_pierce":
			damage_mul *= 1.3
			pierce += 2
		"dry_freeze":
			damage_mul *= 1.3
		"dry_volley":
			damage_mul *= 0.9
	var payload := {"skill": "dry_ice", "pierce": maxi(1, pierce), "knockback": 30.0, "effect": effect}
	_fire_projectile(
		"dry_ice",
		Vector2(540.0 + offset, WALL_Y - 65.0),
		target,
		speed,
		80.0 * damage_mul * _card_mul(card) * float(chain_multiplier),
		int(payload["pierce"]),
		Color(0.45, 0.85, 1.0),
		payload
	)


func _fire_electro(card: Dictionary, target: Dictionary, offset: float) -> void:
	var spec := _consume_next_modifier("electro_pierce")
	var damage_mul := 1.0 + float(spec.get("damage_add", 0.0))
	var radius_mul := 1.0 + float(spec.get("radius_add", 0.0))
	var effect := String(card.get("effect", ""))
	var explosion := false
	match effect:
		"electro_probe":
			damage_mul *= 0.3
		"electro_bomb", "electro_matrix":
			explosion = true
		"electro_fission":
			damage_mul *= 1.15
	var payload := {
		"skill": "electro_pierce",
		"paralyze": 0.3,
		"explosion": explosion,
		"explosion_damage": 55.0 * _card_mul(card) * float(chain_multiplier),
		"radius": 95.0 * radius_mul,
		"effect": effect
	}
	_fire_projectile(
		"electro_pierce",
		Vector2(540.0 + offset, WALL_Y - 70.0),
		target,
		1100.0,
		90.0 * damage_mul * _card_mul(card) * float(chain_multiplier),
		1,
		Color(0.75, 0.62, 1.0),
		payload
	)


func _fire_projectile(
	kind: String, origin: Vector2, target: Dictionary, speed: float, damage: float, pierce: int, color: Color, payload: Dictionary
) -> void:
	projectiles.append(
		{
			"id": _next_projectile_id,
			"kind": kind,
			"pos": origin,
			"target_id": int(target.get("id", -1)),
			"speed": speed,
			"damage": damage,
			"pierce": pierce,
			"color": color,
			"payload": payload
		}
	)
	_next_projectile_id += 1


func _resolve_projectile_hit(projectile: Dictionary, target: Dictionary) -> void:
	var kind := String(projectile.get("kind", ""))
	var payload := projectile.get("payload", {}) as Dictionary
	var hit_pos := target.get("pos", Vector2.ZERO) as Vector2
	_deal_damage(target, float(projectile.get("damage", 0.0)), kind)
	match kind:
		"bullet":
			if "bullet_explosion" in _gun_on_hit:
				_area_damage(hit_pos, 80.0, 26.0 * _gun_damage_mul, "bullet_explosion", Color(1.0, 0.78, 0.24))
		"thermobaric":
			var hit_count := _area_damage(
				hit_pos,
				float(payload.get("radius", 105.0)),
				float(payload.get("explosion", 70.0)),
				"thermobaric",
				Color(1.0, 0.26, 0.08),
				float(payload.get("knockback", 70.0))
			)
			if String(payload.get("effect", "")) == "thermo_probe" and hit_count > 0:
				_next_modifiers["thermobaric"] = {"explosion_add": 0.2}
			if String(payload.get("effect", "")) == "thermo_burn" or String(payload.get("effect", "")) == "thermo_probe":
				for enemy in _enemies_in_radius(hit_pos, float(payload.get("radius", 105.0))):
					_add_dot(enemy, "burn", 6.0, float(payload.get("explosion", 70.0)) * 0.1)
		"dry_ice":
			_apply_knockback(target, 30.0)
			if String(payload.get("effect", "")) == "dry_probe":
				_next_modifiers["dry_ice"] = {"damage_add": 0.15}
			if String(payload.get("effect", "")) == "dry_freeze":
				target["frozen"] = maxf(float(target.get("frozen", 0.0)), 2.0 * float(target.get("freeze_mul", 1.0)))
			if int(projectile.get("pierce", 1)) > 1:
				_chain_pierce(projectile, target)
		"electro_pierce":
			target["paralyzed"] = maxf(
				float(target.get("paralyzed", 0.0)), float(payload.get("paralyze", 0.3)) * float(target.get("paralyze_mul", 1.0))
			)
			if String(payload.get("effect", "")) == "electro_probe":
				_next_modifiers["electro_pierce"] = {"damage_add": 0.2}
			if bool(payload.get("explosion", false)):
				_area_damage(
					hit_pos,
					float(payload.get("radius", 95.0)),
					float(payload.get("explosion_damage", 55.0)),
					"electro",
					Color(0.58, 0.42, 1.0)
				)
			if String(payload.get("effect", "")) == "electro_matrix":
				_add_effect("matrix", hit_pos, float(payload.get("radius", 95.0)) + 30.0, 4.0, Color(0.48, 0.35, 1.0))
			if String(payload.get("effect", "")) == "electro_fission":
				_area_damage(hit_pos, 170.0, float(projectile.get("damage", 0.0)) * 0.35, "electro_particle", Color(0.82, 0.72, 1.0))


func _chain_pierce(projectile: Dictionary, first_target: Dictionary) -> void:
	var hits := 1
	var max_hits := int(projectile.get("pierce", 1))
	var sorted := enemies.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("pos", Vector2.ZERO).y) > float(b.get("pos", Vector2.ZERO).y)
	)
	for enemy in sorted:
		if hits >= max_hits:
			return
		if int(enemy.get("id", -1)) == int(first_target.get("id", -1)):
			continue
		if abs((enemy.get("pos", Vector2.ZERO) as Vector2).x - (first_target.get("pos", Vector2.ZERO) as Vector2).x) <= 115.0:
			_deal_damage(enemy, float(projectile.get("damage", 0.0)) * 0.82, String(projectile.get("kind", "")))
			_apply_knockback(enemy, 24.0)
			hits += 1


func _deal_damage(enemy: Dictionary, amount: float, source: String, show_text: bool = true) -> void:
	if enemy.is_empty() or amount <= 0.0:
		return
	enemy["hp"] = float(enemy.get("hp", 0.0)) - amount
	if show_text:
		_add_floater("%d" % int(amount), enemy.get("pos", Vector2.ZERO), _source_color(source))
	if float(enemy.get("hp", 0.0)) <= 0.0:
		_kill_enemy(enemy)


func _kill_enemy(enemy: Dictionary) -> void:
	var id := int(enemy.get("id", -1))
	for i in range(enemies.size() - 1, -1, -1):
		if int(enemies[i].get("id", -2)) == id:
			enemies.remove_at(i)
			break
	kills += 1
	score += 10 + int(enemy.get("exp", 1)) * 5
	_gain_exp(float(enemy.get("exp", 1)))
	_add_effect(
		"burst", enemy.get("pos", Vector2.ZERO), float(enemy.get("radius", 28.0)) * 1.6, 0.28, _source_color(String(enemy.get("kind", "")))
	)
	if String(enemy.get("kind", "")) == "boss":
		phase = Phase.WON
		last_event = "Boss 已击破，防线胜利"
		ProgressStore.record_score(score)
		ProgressStore.mark_completed("boss_v1")


func _gain_exp(amount: float) -> void:
	if level >= MAX_LEVEL:
		return
	exp_value += amount
	while level < MAX_LEVEL and exp_value >= exp_to_next:
		exp_value -= exp_to_next
		level += 1
		exp_to_next = 10.0 + float(level - 1) * 4.0
		max_energy = _energy_cap_by_level(level)
		current_energy = minf(float(max_energy), current_energy + 1.0)
		_generate_upgrade_choices()
		phase = Phase.UPGRADE
		last_event = "升级到 Lv.%d：选择一个强化" % level
		return


func _generate_upgrade_choices() -> void:
	upgrade_choices.clear()
	var pool: Array[Dictionary] = []
	for upgrade in upgrades:
		if int(upgrade.get("unlock", 1)) <= level:
			pool.append(upgrade)
	pool.shuffle()
	for upgrade in pool:
		if upgrade_choices.size() >= 3:
			break
		upgrade_choices.append(upgrade)


func _apply_upgrade(upgrade: Dictionary) -> void:
	match String(upgrade.get("type", "")):
		"gun":
			match String(upgrade.get("id", "")):
				"U_GUN_DMG":
					_gun_damage_mul += 0.6
				"U_GUN_RATE":
					_gun_interval_mul *= 0.9
				"U_GUN_EXPLODE":
					if "bullet_explosion" not in _gun_on_hit:
						_gun_on_hit.append("bullet_explosion")
				"U_GUN_BURST":
					_gun_burst_count += 1
		"survival":
			wall_hp = minf(WALL_MAX_HP, wall_hp + WALL_MAX_HP * 0.2)
		"energy":
			if String(upgrade.get("id", "")) == "U_REFILL":
				refill_timer *= 0.85
			else:
				energy_regen *= 1.15
		"core":
			var skill := String(upgrade.get("skill", ""))
			if skill == "electro_pierce":
				_core_release_add[skill] = int(_core_release_add.get(skill, 0)) + 1
			else:
				_core_projectile_add[skill] = int(_core_projectile_add.get(skill, 0)) + 1
		"card_upgrade":
			if not deck.is_empty():
				var card := deck[_rng.randi_range(0, deck.size() - 1)]
				var id := String(card.get("id", ""))
				_card_power_mul[id] = float(_card_power_mul.get(id, 1.0)) + 0.2
		"card_add":
			var candidates := cards.filter(func(card: Dictionary) -> bool: return int(card.get("unlock", 1)) <= level)
			if not candidates.is_empty():
				deck.append(candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate(true))


func _area_damage(pos: Vector2, radius: float, damage: float, source: String, color: Color, knockback: float = 0.0) -> int:
	var targets := _enemies_in_radius(pos, radius)
	for enemy in targets:
		_deal_damage(enemy, damage, source)
		if knockback > 0.0:
			_apply_knockback(enemy, knockback)
	_add_effect(source, pos, radius, 0.32, color)
	return targets.size()


func _apply_knockback(enemy: Dictionary, amount: float) -> void:
	var pos := enemy.get("pos", Vector2.ZERO) as Vector2
	pos.y = maxf(-40.0, pos.y - amount)
	enemy["pos"] = pos


func _add_dot(enemy: Dictionary, key: String, duration: float, damage_per_second: float) -> void:
	var stacks: Array = enemy.get(key, [])
	if stacks.size() >= 5:
		stacks.pop_front()
	stacks.append({"remaining": duration, "damage": damage_per_second, "tick": 1.0})
	enemy[key] = stacks


func _add_effect(kind: String, pos: Vector2, radius: float, ttl: float, color: Color) -> void:
	effects.append(
		{"id": _next_effect_id, "kind": kind, "pos": pos, "radius": radius, "ttl": ttl, "max_ttl": ttl, "color": color, "tick": 0.5}
	)
	_next_effect_id += 1


func _add_floater(text: String, pos: Vector2, color: Color) -> void:
	floaters.append({"text": text, "pos": pos + Vector2(_rng.randf_range(-18.0, 18.0), -28.0), "ttl": 0.7, "color": color})


func _find_nearest_to_wall_enemy(offset_index: int = 0) -> Dictionary:
	if enemies.is_empty():
		return {}
	var sorted := enemies.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (a.get("pos", Vector2.ZERO) as Vector2).y > (b.get("pos", Vector2.ZERO) as Vector2).y
	)
	return sorted[mini(offset_index, sorted.size() - 1)]


func _enemy_by_id(id: int) -> Dictionary:
	for enemy in enemies:
		if int(enemy.get("id", -1)) == id:
			return enemy
	return {}


func _enemies_in_radius(pos: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in enemies:
		if (enemy.get("pos", Vector2.ZERO) as Vector2).distance_to(pos) <= radius + float(enemy.get("radius", 24.0)):
			result.append(enemy)
	return result


func _update_chain(cost: int) -> void:
	if cost <= 0:
		return
	if last_positive_cost != -1 and cost > last_positive_cost:
		chain_multiplier = mini(chain_multiplier + 1, 999)
	last_positive_cost = cost


func _break_chain() -> void:
	chain_multiplier = 1
	last_positive_cost = -1


func _update_same_name(same: String) -> void:
	if _same_name_streak_key != same or battle_time - _same_name_streak_start > SAME_NAME_WINDOW:
		_same_name_streak_key = same
		_same_name_streak_count = 1
		_same_name_streak_start = battle_time
		return
	_same_name_streak_count += 1
	if _same_name_streak_count >= SAME_NAME_TRIGGER_COUNT:
		_same_name_cooldown_until[same] = battle_time + SAME_NAME_COOLDOWN
		_same_name_streak_key = ""
		_same_name_streak_count = 0
		last_event = "%s 连续释放过热，冷却 10 秒" % same


func _draw_to_full() -> void:
	while hand.size() < HAND_LIMIT:
		if not _draw_one():
			break


func _draw_one() -> bool:
	if deck.is_empty():
		if discard_pile.is_empty():
			return false
		deck = discard_pile.duplicate(true)
		discard_pile.clear()
		_shuffle_deck()
	if deck.is_empty():
		return false
	hand.append(deck.pop_back())
	return true


func _shuffle_deck() -> void:
	deck.shuffle()


func _card_by_id(id: String) -> Dictionary:
	for card in cards:
		if String(card.get("id", "")) == id:
			return card.duplicate(true)
	return cards[0].duplicate(true)


func _consume_next_modifier(skill: String) -> Dictionary:
	var result := (_next_modifiers.get(skill, {}) as Dictionary).duplicate(true)
	_next_modifiers[skill] = {}
	return result


func _card_mul(card: Dictionary) -> float:
	return float(_card_power_mul.get(String(card.get("id", "")), 1.0))


func _energy_cap_by_level(value: int) -> int:
	if value >= 20:
		return 11
	if value >= 15:
		return 9
	if value >= 10:
		return 7
	if value >= 5:
		return 5
	return 3


func _monster_spec(monster_id: String) -> Dictionary:
	return ContentUnits.get_monster_spec(monster_id)


func _source_color(source: String) -> Color:
	if source.contains("thermobaric") or source.contains("burn") or source == "elite":
		return Color(1.0, 0.35, 0.12)
	if source.contains("dry") or source.contains("frost"):
		return Color(0.45, 0.85, 1.0)
	if source.contains("electro") or source.contains("matrix"):
		return Color(0.75, 0.62, 1.0)
	if source == "boss":
		return Color(1.0, 0.16, 0.1)
	return Color(1.0, 0.92, 0.44)


func _check_end_state() -> void:
	if phase != Phase.PLAYING:
		return
	if wall_hp <= 0.0:
		phase = Phase.LOST
		last_event = "城墙被突破，战斗失败"
		ProgressStore.record_score(score)


func _emit_feedback(kind: String, payload: Dictionary) -> void:
	feedback_requested.emit(kind, payload)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.FEEDBACK_REQUESTED, {"event_id": &"battle_feedback", "kind": kind, "payload": payload})
		GameEvents.emit_event(GameEvents.AUDIO_REQUESTED, {"event_id": &"battle_feedback", "kind": kind})


func _emit_all() -> void:
	status_text = last_event
	phase_changed.emit(phase)
	status_changed.emit(status_text)
	score_changed.emit(score)
	hp_changed.emit(int(wall_hp))
	time_changed.emit(battle_time)
	state_changed.emit(get_snapshot())
