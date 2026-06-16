extends Node

# 空脚手架不预置关卡、波次或系统阶段。新游戏 init 后再写入当前项目内容。

var units: Array[Dictionary] = []
var content_units: Array[Dictionary] = units
var wave_configs: Array[Dictionary] = []
var card_configs: Array[Dictionary] = []
var upgrade_configs: Array[Dictionary] = []
var monster_specs: Dictionary = {}


func list_content_units() -> Array[Dictionary]:
	return units.duplicate(true)


func get_monster_spec(monster_id: String) -> Dictionary:
	return (monster_specs.get(monster_id, {}) as Dictionary).duplicate(true)


func reset_for_new_game() -> void:
	units.clear()
	wave_configs.clear()
	card_configs.clear()
	upgrade_configs.clear()
	monster_specs.clear()
