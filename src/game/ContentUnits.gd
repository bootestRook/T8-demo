extends Node

var units: Array[Dictionary] = [
	{
		"id": "unit_01_bootstrap",
		"name": "1: 基础防线",
		"goal": "验证自动枪械、能量回复、4 手牌和基础温压/干冰/电磁出牌。",
		"difference": "小怪和快怪间隔出现，压力低，玩家能理解近墙优先目标。",
		"pressure": "18 秒出现快怪，38 秒开始数量增加。",
	},
	{
		"id": "unit_02_elite",
		"name": "2: 精英压迫",
		"goal": "验证升级三选一、枪械强化和控制卡对精英的价值。",
		"difference": "重甲怪加入，180 秒出现精英，需要通过构筑缓解城墙压力。",
		"pressure": "高血量单位逼迫玩家选择爆发、穿透或控制流派。",
	},
	{
		"id": "unit_03_boss",
		"name": "3: Boss 检定",
		"goal": "验证至少一个流派成型后能否在 Boss 战中输出、控制并保住城墙。",
		"difference": "300 秒 Boss 出现，Boss 死亡即胜利。",
		"pressure": "Boss 高血量与高城墙伤害检验连锁倍率、核心技能强化和自动枪械保底。",
	},
]

var card_configs: Array[Dictionary] = [
	_card("T0", "试射温压弹", "thermobaric", 0, 1, "低伤温压弹；下张温压爆炸+20%", "thermo_probe"),
	_card("T1", "温压弹连发", "thermobaric", 2, 1, "额外释放 1 枚，伤害 -20%", "thermo_release"),
	_card("T2", "热能爆炸", "thermobaric", 2, 1, "爆炸伤害 +80%", "thermo_boom"),
	_card("T3", "热能爆发", "thermobaric", 3, 3, "爆炸范围 +80%", "thermo_radius", "rare"),
	_card("T4", "热能引燃", "thermobaric", 2, 4, "爆炸燃烧 6 秒", "thermo_burn", "rare"),
	_card("D0", "试射干冰弹", "dry_ice", 0, 1, "低伤穿透；下张干冰伤害+15%", "dry_probe"),
	_card("D1", "低温贯穿", "dry_ice", 2, 1, "伤害 +30%，穿透 +2", "dry_pierce"),
	_card("D2", "急冻寒冰", "dry_ice", 3, 3, "伤害 +30%，冻结 2 秒", "dry_freeze", "rare"),
	_card("D3", "干冰弹齐射", "dry_ice", 4, 5, "干冰弹数量 +1", "dry_volley", "rare"),
	_card("E0", "电容试放", "electro_pierce", 0, 1, "低伤穿刺；下张电磁伤害+20%", "electro_probe"),
	_card("E1", "电磁爆炸", "electro_pierce", 1, 1, "穿刺命中附带小爆炸", "electro_bomb"),
	_card("E2", "电磁矩阵", "electro_pierce", 3, 4, "爆炸处生成减速矩阵", "electro_matrix", "rare"),
	_card("E3", "电磁裂变", "electro_pierce", 4, 6, "命中后释放 6 个粒子", "electro_fission", "epic"),
]

var upgrade_configs: Array[Dictionary] = [
	_upgrade("U_GUN_DMG", "子弹增伤", "gun", "自动枪械伤害 +60%", 1, 100),
	_upgrade("U_GUN_RATE", "射速提升", "gun", "自动枪械射击间隔 -10%", 1, 90),
	_upgrade("U_GUN_EXPLODE", "子弹爆炸", "gun", "子弹命中后小范围爆炸", 2, 85),
	_upgrade("U_GUN_BURST", "连发射击", "gun", "每次射击连发 +1，单发伤害 -20%", 3, 80),
	_upgrade("U_WALL_HP", "加固城墙", "survival", "城墙回复 20%", 1, 85),
	_upgrade("U_ENERGY_REGEN", "能量回路", "energy", "能量回复 +15%", 1, 90),
	_upgrade("U_REFILL", "快速补牌", "energy", "补牌间隔 -15%", 2, 75),
	_upgrade("U_THERMO_COUNT", "温压弹数量+1", "core", "温压弹卡牌每次多发 1 枚", 3, 70, "thermobaric"),
	_upgrade("U_DRY_COUNT", "干冰弹数量+1", "core", "干冰弹卡牌每次多发 1 枚", 3, 70, "dry_ice"),
	_upgrade("U_ELECTRO_RELEASE", "电磁穿刺额外释放", "core", "电磁穿刺卡牌额外释放 1 次", 4, 70, "electro_pierce"),
	_upgrade("U_CARD_POWER", "强化已有卡牌", "card_upgrade", "随机一张已拥有卡牌伤害 +20%", 2, 95),
	_upgrade("U_CARD_ADD", "获得新卡牌", "card_add", "把一张当前等级可用卡加入牌库", 1, 100),
]

var wave_configs: Array[Dictionary] = [
	_wave(0.1, "normal", 8, 0.25, 1.0, 1.0),
	_wave(7.0, "fast", 8, 0.25, 1.0, 1.0),
	_wave(18.0, "normal", 14, 0.24, 1.25, 1.0),
	_wave(68.0, "tank", 6, 0.55, 1.0, 1.0),
	_wave(100.0, "fast", 14, 0.28, 1.2, 1.1),
	_wave(135.0, "normal", 18, 0.25, 1.65, 1.0),
	_wave(180.0, "elite", 1, 0.0, 1.0, 1.0),
	_wave(205.0, "tank", 10, 0.35, 1.55, 1.0),
	_wave(245.0, "fast", 20, 0.22, 1.45, 1.15),
	_wave(300.0, "boss", 1, 0.0, 1.0, 1.0),
]

var monster_configs := {
	"normal": _monster("基础怪", 95.0, 72.0, 22.0, 1.45, 3, 28.0, 1.0, 1.0),
	"fast": _monster("迅捷怪", 70.0, 115.0, 14.0, 1.0, 2, 24.0, 1.0, 1.0),
	"tank": _monster("重甲怪", 210.0, 46.0, 34.0, 1.8, 5, 34.0, 0.8, 0.8),
	"elite": _monster("精英突击体", 1300.0, 56.0, 58.0, 1.35, 24, 54.0, 0.5, 0.5),
	"boss": _monster("熔核攻城体", 5200.0, 34.0, 95.0, 1.2, 80, 78.0, 0.25, 0.25),
}


func get_unit(index: int) -> Dictionary:
	if units.is_empty() or index < 0 or index >= units.size():
		return {}
	return units[index]


func get_unit_by_id(unit_id: String) -> Dictionary:
	for unit in units:
		if String(unit.get("id", "")) == unit_id:
			return unit
	return {}


func count() -> int:
	return units.size()


func get_monster_spec(monster_id: String) -> Dictionary:
	return (monster_configs.get(monster_id, monster_configs["normal"]) as Dictionary).duplicate(true)


func _card(
	id: String, name: String, skill: String, cost: int, unlock: int, text: String, effect: String, rarity: String = "normal"
) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"same": name,
		"skill": skill,
		"cost": cost,
		"rarity": rarity,
		"unlock": unlock,
		"text": text,
		"effect": effect,
	}


func _upgrade(id: String, name: String, type: String, text: String, unlock: int, weight: int, skill: String = "") -> Dictionary:
	var result := {"id": id, "name": name, "type": type, "text": text, "unlock": unlock, "weight": weight}
	if not skill.is_empty():
		result["skill"] = skill
	return result


func _wave(time: float, monster: String, count_value: int, interval: float, hp_mul: float, speed_mul: float) -> Dictionary:
	return {
		"time": time,
		"monster": monster,
		"count": count_value,
		"interval": interval,
		"hp_mul": hp_mul,
		"speed_mul": speed_mul,
	}


func _monster(
	name: String,
	hp: float,
	speed: float,
	attack: float,
	attack_interval: float,
	exp: int,
	radius: float,
	freeze_mul: float,
	paralyze_mul: float
) -> Dictionary:
	return {
		"name": name,
		"hp": hp,
		"speed": speed,
		"attack": attack,
		"attack_interval": attack_interval,
		"exp": exp,
		"radius": radius,
		"freeze_mul": freeze_mul,
		"paralyze_mul": paralyze_mul,
	}
