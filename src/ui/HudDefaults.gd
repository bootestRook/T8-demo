extends RefCounted
class_name HudDefaults

const CARD_PLAY_FAILURE_MESSAGES := {
	"not_enough_energy": "能量不足",
	"play_locked": "上一张卡还在结算",
	"card_not_in_hand": "卡牌已经离开手牌",
	"not_player_turn": "当前不能出牌",
	"missing_card_config": "卡牌配置缺失",
}
const DEFAULT_CARDS := [
	{
		"cost": 0,
		"name": "试射温压弹",
		"type": "试射",
		"desc": "本次连锁爆炸伤害+20%",
		"art": "温",
		"effect": "本次连锁爆炸伤害+20%",
		"school": "温压弹",
	},
	{
		"cost": 0,
		"name": "试射干冰弹",
		"type": "试射",
		"desc": "本次连锁伤害+15%",
		"art": "冰",
		"effect": "本次连锁伤害+15%",
		"school": "干冰弹",
	},
	{
		"cost": 0,
		"name": "电容试放",
		"type": "试放",
		"desc": "本次连锁伤害+20%",
		"art": "电",
		"effect": "本次连锁伤害+20%",
		"school": "电磁穿刺",
	},
	{
		"cost": 0,
		"name": "压力校准弹",
		"type": "校准",
		"desc": "本次连锁爆炸范围+20%",
		"art": "温",
		"effect": "本次连锁爆炸范围+20%",
		"school": "温压弹",
	},
	{
		"cost": 0,
		"name": "冷凝校准弹",
		"type": "校准",
		"desc": "本次连锁穿透+1",
		"art": "冰",
		"effect": "本次连锁穿透+1",
		"school": "干冰弹",
	},
]
