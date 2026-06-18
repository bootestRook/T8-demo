extends Node2D

const WORLD_SIZE := Vector2(1080.0, 1920.0)
const GAME_BATTLEFIELD_DRAWER := preload("res://src/game/GameBattlefieldDrawer.gd")
const GAME_COMBAT_EFFECT_DRAWER := preload("res://src/game/GameCombatEffectDrawer.gd")
const GAME_DAMAGE_FLOAT_DRAWER := preload("res://src/game/GameDamageFloatDrawer.gd")
const GAME_PROJECTILE_DRAWER := preload("res://src/game/GameProjectileDrawer.gd")
const PLAYER_AIM_PRESENTER := preload("res://src/game/PlayerAimPresenter.gd")
const MONSTER_PRESENTER := preload("res://src/game/MonsterPresenter.gd")

@onready var hud: Hud = $Hud
@onready var main_menu: MainMenuScreen = $MainMenuScreen
@onready var runtime_animation_player: AnimationPlayer = $RuntimeAnimationPlayer

var _snapshot: Dictionary = {}
var _screen_feedback_offset := Vector2.ZERO
var _damage_font: Font = null
var _recorded_win_level_id := ""
var _ui_background_texture: Texture2D = null
var _battlefield_texture: Texture2D = null
var _defense_wall_staging_texture: Texture2D = null
var _player_aim_presenter: PlayerAimPresenter = PLAYER_AIM_PRESENTER.new()
var _monster_presenter: MonsterPresenter = MONSTER_PRESENTER.new()


func _ready() -> void:
	add_to_group("playable_game")
	runtime_animation_player.playback_active = true
	_damage_font = ThemeDB.get_default_theme().get_default_font()
	_ui_background_texture = AssetRegistry.load_texture(&"image", &"ui_background_v2")
	_battlefield_texture = AssetRegistry.load_texture(&"sprite", &"battlefield_v1")
	_defense_wall_staging_texture = AssetRegistry.load_texture(&"sprite", &"defense_wall_staging_v1")
	_player_aim_presenter.setup()
	get_viewport().size_changed.connect(queue_redraw)
	PrototypeState.state_changed.connect(_on_state_changed)
	main_menu.start_requested.connect(_on_main_menu_start_requested)
	hud.main_menu_requested.connect(_show_main_menu)
	PrototypeState.reset()
	_show_main_menu()
	queue_redraw()


func _process(delta: float) -> void:
	if hud.has_method("is_gameplay_active") and not bool(hud.call("is_gameplay_active")):
		_player_aim_presenter.update(_snapshot, delta)
		queue_redraw()
		return
	PrototypeState.tick(delta)
	_player_aim_presenter.update(_snapshot, delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if hud.has_method("is_gameplay_active") and not bool(hud.call("is_gameplay_active")):
		return
	if event.is_action_pressed("ui_accept"):
		PrototypeState.reset()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R:
			PrototypeState.reset()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_set_transform(_screen_feedback_offset, 0.0, Vector2.ONE)
	_draw_starter_canvas()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if hud.has_method("set_battle_snapshot"):
		hud.call("set_battle_snapshot", snapshot)
	_record_level_progress(snapshot)


func set_screen_feedback_offset(offset: Vector2) -> void:
	_screen_feedback_offset = offset
	queue_redraw()


func _on_main_menu_start_requested(level_id: String) -> void:
	ContentUnits.load_combat_configs(level_id)
	_recorded_win_level_id = ""
	PrototypeState.reset()
	main_menu.visible = false
	hud.visible = true
	if hud.has_method("start_battle_ui"):
		hud.call("start_battle_ui")
	queue_redraw()


func _show_main_menu() -> void:
	if hud.has_method("stop_battle_ui"):
		hud.call("stop_battle_ui")
	hud.visible = false
	main_menu.show_menu()
	queue_redraw()


func _record_level_progress(snapshot: Dictionary) -> void:
	if int(snapshot.get("phase", -1)) != PrototypeState.Phase.WON:
		return
	var level_id := ContentUnits.active_level_id
	if level_id == _recorded_win_level_id:
		return
	_recorded_win_level_id = level_id
	ProgressStore.record_level_result(
		level_id, int(snapshot.get("wall_hp", snapshot.get("hp", 0))), int(snapshot.get("wall_hp_max", 1)), int(snapshot.get("score", 0))
	)


func _draw_starter_canvas() -> void:
	GAME_BATTLEFIELD_DRAWER.draw_base(self, WORLD_SIZE, _ui_background_texture, _battlefield_texture, _defense_wall_staging_texture)
	GAME_BATTLEFIELD_DRAWER.draw_combat_areas(self, _snapshot)
	_monster_presenter.draw_monsters(self, _snapshot)
	_draw_player()
	_draw_projectiles()
	_draw_combat_effects()
	_monster_presenter.draw_hp_bars(self, _snapshot)
	_draw_combat_damage_floats()


func _draw_projectiles() -> void:
	GAME_PROJECTILE_DRAWER.draw_projectiles(self, _snapshot)


func _draw_player() -> void:
	_player_aim_presenter.draw(self, _screen_feedback_offset)


func _draw_combat_effects() -> void:
	GAME_COMBAT_EFFECT_DRAWER.draw_effect_rings(self, _snapshot)


func _draw_combat_damage_floats() -> void:
	GAME_DAMAGE_FLOAT_DRAWER.draw_damage_floats(self, _snapshot, _damage_font)
