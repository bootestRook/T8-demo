extends Node
class_name SceneRouter

signal scene_change_requested(path: String)
signal scene_changed(path: String)
signal scene_change_failed(path: String, error_code: int)


func change_to(path: String) -> int:
	scene_change_requested.emit(path)
	if has_node("/root/GameEvents"):
		GameEvents.emit_event(GameEvents.SCENE_CHANGE_REQUESTED, {"path": path})
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		scene_changed.emit(path)
	else:
		scene_change_failed.emit(path, error)
	return error


func reload_current() -> int:
	var current_scene_file := get_tree().current_scene.scene_file_path
	if current_scene_file.is_empty():
		return ERR_UNCONFIGURED
	return change_to(current_scene_file)
