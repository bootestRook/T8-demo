extends Node
class_name QuestStore

signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName, quest: Dictionary)
signal quest_completed(quest_id: StringName)

var quests: Dictionary = {}


func register_quest(quest_id: StringName, title: String, objectives: Dictionary) -> void:
	quests[quest_id] = {
		"title": title,
		"objectives": objectives.duplicate(true),
		"progress": {},
		"started": false,
		"completed": false,
	}


func start_quest(quest_id: StringName) -> bool:
	if not quests.has(quest_id):
		return false
	quests[quest_id]["started"] = true
	quest_started.emit(quest_id)
	_emit_update(quest_id)
	return true


func add_progress(quest_id: StringName, objective_id: StringName, amount: int = 1) -> bool:
	if not quests.has(quest_id):
		return false
	var quest: Dictionary = quests[quest_id]
	if bool(quest.get("completed", false)):
		return false
	var progress: Dictionary = quest.get("progress", {})
	progress[objective_id] = int(progress.get(objective_id, 0)) + amount
	quest["progress"] = progress
	quests[quest_id] = quest
	if _is_complete(quest):
		quest["completed"] = true
		quests[quest_id] = quest
		quest_completed.emit(quest_id)
	_emit_update(quest_id)
	return true


func serialize() -> Dictionary:
	return quests.duplicate(true)


func deserialize(data: Dictionary) -> void:
	quests = data.duplicate(true)


func _is_complete(quest: Dictionary) -> bool:
	var objectives: Dictionary = quest.get("objectives", {})
	var progress: Dictionary = quest.get("progress", {})
	for objective_id in objectives:
		if int(progress.get(objective_id, 0)) < int(objectives[objective_id]):
			return false
	return true


func _emit_update(quest_id: StringName) -> void:
	var quest: Dictionary = quests.get(quest_id, {})
	quest_updated.emit(quest_id, quest.duplicate(true))
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.QUEST_UPDATED, {"quest_id": quest_id, "quest": quest})
