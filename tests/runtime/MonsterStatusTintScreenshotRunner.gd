extends Node2D

const MONSTER_PRESENTER := preload("res://src/game/MonsterPresenter.gd")

var _output_dir := ""
var _monster_presenter: MonsterPresenter = MONSTER_PRESENTER.new()
var _snapshot := {}


func _ready() -> void:
	_output_dir = _arg_value("--screenshot-dir")
	if _output_dir.is_empty():
		print("MonsterStatusTintScreenshotRunner loaded without --screenshot-dir; dry-load only.")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_snapshot = {"active_monsters": _sample_monsters()}
	queue_redraw()
	call_deferred("_capture")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.06, 0.07, 0.08), true)
	_monster_presenter.draw_monsters(self, _snapshot)
	_monster_presenter.draw_hp_bars(self, _snapshot)


func _capture() -> void:
	await _wait_frames(6)
	queue_redraw()
	await _wait_frames(2)
	_save_viewport("monster-status-tints")
	_snapshot.clear()
	_monster_presenter = null
	get_tree().quit(0)


func _sample_monsters() -> Array:
	return [
		_monster("grunt", "monster_grunt", Vector2(170.0, 360.0), 34.0, {"weakpoint": {"remaining": 4.0}}),
		_monster("runner", "monster_runner", Vector2(390.0, 360.0), 32.0, {"stun": {"remaining": 4.0}}),
		_monster("brute", "monster_tank", Vector2(610.0, 360.0), 38.0, {"burn": {"remaining": 4.0}}),
		_monster("elite", "monster_elite", Vector2(840.0, 360.0), 36.0, {"frostbite": {"remaining": 4.0}}),
		_monster("boss", "monster_boss_cathedral", Vector2(1010.0, 360.0), 42.0, {"freeze": {"remaining": 4.0}}),
	]


func _monster(monster_id: String, model: String, position: Vector2, radius: float, statuses: Dictionary) -> Dictionary:
	return {
		"id": monster_id,
		"monster_id": monster_id,
		"model": model,
		"position": position,
		"radius": radius,
		"hp": 80.0,
		"hp_max": 100.0,
		"statuses": statuses,
	}


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _save_viewport(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join("%s.png" % label)
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save screenshot %s: %s" % [path, error])
	else:
		print("screenshot:%s:%s" % [label, path])


func _arg_value(name: String, default_value := "") -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].substr(name.length() + 1)
	return default_value
