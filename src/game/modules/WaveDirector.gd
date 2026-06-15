extends Node
class_name WaveDirector

signal wave_started(index: int, wave: Dictionary)
signal spawn_requested(request: Dictionary)
signal wave_finished(index: int, wave: Dictionary)
signal sequence_finished

@export var auto_process := false
@export var auto_advance := true

var waves: Array[Dictionary] = []
var current_wave_index := -1
var elapsed := 0.0
var running := false
var _spawn_cursor := 0


func configure(new_waves: Array[Dictionary]) -> void:
	waves = new_waves.duplicate(true)
	current_wave_index = -1
	elapsed = 0.0
	_spawn_cursor = 0
	running = false


func start(index: int = 0) -> bool:
	if index < 0 or index >= waves.size():
		return false
	current_wave_index = index
	elapsed = 0.0
	_spawn_cursor = 0
	running = true
	var wave := waves[current_wave_index]
	wave_started.emit(current_wave_index, wave.duplicate(true))
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.WAVE_STARTED, {"index": current_wave_index, "wave": wave})
	return true


func tick(delta: float) -> void:
	if not running or current_wave_index < 0:
		return
	elapsed += delta
	var wave := waves[current_wave_index]
	var spawns: Array = wave.get("spawns", [])
	while _spawn_cursor < spawns.size():
		var request: Dictionary = spawns[_spawn_cursor]
		if float(request.get("time", 0.0)) > elapsed:
			break
		_spawn_cursor += 1
		spawn_requested.emit(request.duplicate(true))
		if has_node("/root/GameEvents"):
			GameEvents.emit_event(GameEvents.WAVE_SPAWN_REQUESTED, request)
	var duration := float(wave.get("duration", 0.0))
	if _should_finish_wave(duration, spawns.size()):
		_finish_wave(wave)


func _process(delta: float) -> void:
	if auto_process:
		tick(delta)


func _finish_wave(wave: Dictionary) -> void:
	var finished_index := current_wave_index
	wave_finished.emit(finished_index, wave.duplicate(true))
	if auto_advance and finished_index + 1 < waves.size():
		start(finished_index + 1)
	else:
		running = false
		sequence_finished.emit()


func _should_finish_wave(duration: float, spawn_count: int) -> bool:
	if _spawn_cursor < spawn_count:
		return false
	if duration > 0.0:
		return elapsed >= duration
	return true
