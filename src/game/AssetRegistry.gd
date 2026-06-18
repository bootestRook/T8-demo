extends Node

# 运行时素材清单。AI 接入真实素材时优先登记到这里，避免路径散落。

const GENERATED_DIR := "res://assets/generated"
const SPRITES_DIR := "res://assets/sprites"
const UI_DIR := "res://assets/ui"
const AUDIO_DIR := "res://assets/audio"

var images: Dictionary = {}
var sprites: Dictionary = {}
var ui: Dictionary = {}
var audio: Dictionary = {}
var _resource_cache: Dictionary = {}


func _ready() -> void:
	register_image(&"ui_background_v2", "res://assets/generated/runtime/ui_background_v2/ui_background_v2_candidate.png")
	register_ui(&"card_frame_v1", UI_DIR + "/cards/card_frame_v1.png")
	register_ui(&"card_art_fallback_v1", UI_DIR + "/cards/card_art_fallback_v1.png")
	register_ui(&"limit_lock", UI_DIR + "/icons/limit_lock.png")
	register_ui(&"draw_pile_icon_v1", "res://assets/ui/hud/draw_pile_icon_v1.png")
	register_ui(&"discard_pile_icon_v1", "res://assets/ui/hud/discard_pile_icon_v1.png")
	register_ui(&"discard_hand_icon_v1", "res://assets/ui/hud/discard_hand_icon_v1.png")
	register_ui(&"pause_icon_v1", "res://assets/ui/hud/pause_icon_v1.png")
	register_ui(&"school_icon_thermobaric", UI_DIR + "/icons_Skill/icon_keji_wenyadan.png")
	register_ui(&"school_icon_electro_pierce", UI_DIR + "/icons_Skill/icon_keji_diancichuanci.png")
	register_ui(&"school_icon_dry_ice", UI_DIR + "/icons_Skill/icon_keji_ganbingdan.png")
	register_ui(&"school_icon_gun", UI_DIR + "/icons_Skill/icon_keji_qiang.png")
	register_ui(&"school_icon_common", UI_DIR + "/icons_Skill/icon_keji_tongyong.png")
	register_sprite(&"defense_wall_v1", "res://assets/sprites/environment/defense_wall_v1.png")
	register_sprite(&"defense_wall_staging_v1", "res://assets/sprites/environment/defense_wall_staging_v1.png")
	register_sprite(&"battlefield_v1", "res://assets/sprites/environment/battlefield_v1.png")
	register_sprite(&"player_hero_v1", "res://assets/sprites/characters/player_hero_v1.png")
	register_sprite(&"monster_grunt", "res://assets/sprites/monsters/monster_grunt.png")
	register_sprite(&"monster_runner", "res://assets/sprites/monsters/monster_runner.png")
	register_sprite(&"monster_tank", "res://assets/sprites/monsters/monster_tank.png")
	register_sprite(&"monster_elite", "res://assets/sprites/monsters/monster_elite.png")
	register_sprite(&"monster_boss_cathedral", "res://assets/sprites/monsters/monster_boss_cathedral.png")


func register_image(id: StringName, path: String) -> void:
	_register_path(images, id, path)


func register_sprite(id: StringName, path: String) -> void:
	_register_path(sprites, id, path)


func register_ui(id: StringName, path: String) -> void:
	_register_path(ui, id, path)


func register_audio(id: StringName, path: String) -> void:
	_register_path(audio, id, path)


func get_image(id: StringName) -> String:
	return String(images.get(id, ""))


func get_sprite(id: StringName) -> String:
	return String(sprites.get(id, ""))


func get_ui(id: StringName) -> String:
	return String(ui.get(id, ""))


func get_audio(id: StringName) -> String:
	return String(audio.get(id, ""))


func has_asset(group_name: StringName, id: StringName) -> bool:
	return _group(group_name).has(id)


func get_asset_path(group_name: StringName, id: StringName) -> String:
	return String(_group(group_name).get(id, ""))


func load_texture(group_name: StringName, id: StringName) -> Texture2D:
	var path := get_asset_path(group_name, id)
	if path.is_empty():
		return null
	return _load_cached(path) as Texture2D


func load_audio(id: StringName) -> AudioStream:
	var path := get_audio(id)
	if path.is_empty():
		return null
	return _load_cached(path) as AudioStream


func ids(group_name: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in _group(group_name):
		result.append(id)
	return result


func clear_cache() -> void:
	_resource_cache.clear()


func validate_runtime_paths() -> Array[String]:
	var problems: Array[String] = []
	for group in [images, sprites, ui, audio]:
		for id in group:
			var path := String(group[id])
			if path.begins_with("res://references") or path.contains("/references/"):
				problems.append("%s -> %s" % [String(id), path])
	return problems


func _register_path(target: Dictionary, id: StringName, path: String) -> void:
	if path.begins_with("res://references") or path.contains("/references/"):
		push_error("运行时素材不能引用 references/: %s" % path)
		return
	if not ResourceLoader.exists(path):
		push_warning("运行时素材路径不存在: %s" % path)
	target[id] = path


func _group(group_name: StringName) -> Dictionary:
	match group_name:
		&"image", &"images":
			return images
		&"sprite", &"sprites":
			return sprites
		&"ui":
			return ui
		&"audio":
			return audio
	return {}


func _load_cached(path: String) -> Resource:
	if _resource_cache.has(path):
		return _resource_cache[path] as Resource
	if not ResourceLoader.exists(path):
		push_warning("运行时素材路径不存在: %s" % path)
		return null
	var resource := ResourceLoader.load(path)
	if resource != null:
		_resource_cache[path] = resource
	return resource
