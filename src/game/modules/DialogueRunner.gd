extends Node
class_name DialogueRunner

signal line_started(line: Dictionary)
signal dialogue_finished

var lines: Array[Dictionary] = []
var index := -1


func start(new_lines: Array[Dictionary]) -> void:
	lines = new_lines.duplicate(true)
	index = -1
	next_line()


func next_line() -> Dictionary:
	index += 1
	if index >= lines.size():
		dialogue_finished.emit()
		return {}
	var line := current_line()
	line_started.emit(line.duplicate(true))
	return line


func current_line() -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	return lines[index].duplicate(true)


func is_finished() -> bool:
	return index >= lines.size()
