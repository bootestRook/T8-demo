extends Node

enum Phase { READY, PLAYING, WON, LOST }

const CONCEPT_ID := "starter-template"
const STARTER_CONCEPT_ID := CONCEPT_ID
const DEFAULT_WALL_HP := 3000

signal phase_changed(new_phase: Phase)
signal status_changed(new_status: String)
signal score_changed(new_score: int)
signal hp_changed(new_hp: int)
signal time_changed(new_time: float)
signal state_changed(snapshot: Dictionary)
signal feedback_requested(kind: String, payload: Dictionary)

var phase: Phase = Phase.READY
var concept_id := CONCEPT_ID
var status_text := "敌人从上方推进，手牌从下方释放。"
var elapsed_time := 0.0
var score := 0
var hp := DEFAULT_WALL_HP


func _ready() -> void:
	reset()


func reset() -> void:
	phase = Phase.READY
	elapsed_time = 0.0
	score = 0
	hp = DEFAULT_WALL_HP
	status_text = "敌人从上方推进，手牌从下方释放。"
	_emit_all()


func tick(delta: float) -> void:
	elapsed_time += delta
	_emit_all()


func get_snapshot() -> Dictionary:
	return {
		"concept_id": concept_id,
		"phase": phase,
		"status_text": status_text,
		"elapsed_time": elapsed_time,
		"score": score,
		"hp": hp,
		"objective": "目标：守住城墙",
		"hint": "点击或拖拽手牌释放技能",
		"stage_name": "5-1 教堂广场",
		"wave_current": 1,
		"wave_total": 20,
		"level": 1,
		"exp": 60,
		"exp_max": 60,
		"wall_hp": hp,
		"wall_hp_max": DEFAULT_WALL_HP,
		"energy": 3,
		"energy_max": 3,
		"ultimate_energy": 45.0,
		"ammo": 75,
		"ammo_max": 75,
		"hero_name": "艾琳",
		"targeting_hint": "推荐落雷点",
		"draw_count": 18,
		"discard_count": 8,
		"hand_cards":
		[
			{
				"cost": 1,
				"name": "冰霜弹",
				"type": "攻击",
				"desc": "造成伤害并冻结。",
				"art": "冰",
			},
			{
				"cost": 2,
				"name": "穿透弹",
				"type": "攻击",
				"desc": "对直线敌人穿透。",
				"art": "弹",
			},
			{
				"cost": 1,
				"name": "维修机",
				"type": "技能",
				"desc": "修复城墙耐久。",
				"art": "+",
			},
			{
				"cost": 3,
				"name": "落雷",
				"type": "范围",
				"desc": "指定区域高额伤害。",
				"art": "雷",
			},
			{
				"cost": 2,
				"name": "防线护盾",
				"type": "防御",
				"desc": "生成临时护盾。",
				"art": "盾",
			},
		],
	}


func _emit_all() -> void:
	phase_changed.emit(phase)
	status_changed.emit(status_text)
	score_changed.emit(score)
	hp_changed.emit(hp)
	time_changed.emit(elapsed_time)
	state_changed.emit(get_snapshot())
