extends CanvasLayer
class_name Hud

signal main_menu_requested

const MESSAGE_WIDTH_RATIO := 0.86
const COMPACT_WIDTH := 340.0
const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const MENU_OVERLAY_Z_INDEX := 900
const CARD_FEEL_CONFIG := {
	"drag_detection_threshold": 16.0,
	"dragged_follow_speed": 20.0,
	"dragged_rotation_velocity_multiplier": 0.00008,
	"dragged_rotation_amount": 0.20,
	"drag_height_offset": 58.0,
	"drag_x_offset_from_hover": 0.0,
	"hover_move_speed": 18.0,
	"hover_scale": 1.38,
	"hover_height_offset": 78.0,
	"hover_spread_min_offset": 96.0,
	"hover_spread_step_offset": 54.0,
	"hover_spread_max_offset": 190.0,
	"hover_press_tilt_degrees": 7.4,
	"hover_press_offset": 7.0,
	"hover_press_down_offset": 15.0,
	"hover_press_scale": 1.012,
	"card_play_zone_height_offset": 72.0,
	"card_long_press_clear_time": 0.22,
	"tilt_degrees": 5.0,
	"invalid_scale": 1.05,
	"invalid_height_offset": 20.0,
	"invalid_shake_amplitude": 13.0,
	"invalid_shake_time": 0.24,
	"invalid_shake_vibrato": 8.0,
	"playable_position_scale_multiplier": 1.48,
	"playable_position_scale_duration": 0.14,
	"card_reorder_delay": 0.12,
}
const CARD_FRAME_PATH := "res://assets/ui/cards/card_frame_v1.png"
const CARD_ART_FALLBACK_PATH := "res://assets/ui/cards/card_art_fallback_v1.png"
const LIMIT_LOCK_ICON_PATH := "res://assets/ui/icons/limit_lock.png"
const ULTIMATE_LIMIT_SEGMENTS := 10
const HAND_AREA_Z_INDEX := 180
const DEFAULT_STAGE := "1-1 教堂广场"
const HUD_DEFAULTS := preload("res://src/ui/HudDefaults.gd")
const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")
const HUD_DRAW_CARD_FX := preload("res://src/ui/HudDrawCardFx.gd")
const HUD_PLAY_CARD_FX := preload("res://src/ui/HudPlayCardFx.gd")
const HUD_DISCARD_HAND_FX := preload("res://src/ui/HudDiscardHandFx.gd")
const HUD_CHAIN_FLASH_FX := preload("res://src/ui/HudChainFlashFx.gd")
const HUD_RESULT_OVERLAY := preload("res://src/ui/HudResultOverlay.gd")
const HUD_UI_HELPERS := preload("res://src/ui/HudUiHelpers.gd")
const HUD_PILE_OVERLAY_CONTROLLER := preload("res://src/ui/HudPileOverlayController.gd")
const HUD_CARD_INTERACTION := preload("res://src/ui/HudCardInteraction.gd")
const HUD_LAYOUT_STYLER := preload("res://src/ui/HudLayoutStyler.gd")
const HUD_CARD_VISUALS := preload("res://src/ui/HudCardVisuals.gd")
const HUD_SNAPSHOT_PRESENTER := preload("res://src/ui/HudSnapshotPresenter.gd")
const HUD_CARD_SNAPSHOT_PRESENTER := preload("res://src/ui/HudCardSnapshotPresenter.gd")
const HUD_SETUP_COORDINATOR := preload("res://src/ui/HudSetupCoordinator.gd")
const HUD_BATTLE_UI_FLOW := preload("res://src/ui/HudBattleUiFlow.gd")
const HUD_DISCARD_HAND_FLOW := preload("res://src/ui/HudDiscardHandFlow.gd")
const HUD_HAND_QUERIES := preload("res://src/ui/HudHandQueries.gd")

@onready var root: Control = $Root
@onready var safe_margin: MarginContainer = $Root/SafeMargin
@onready var top_bar: GridContainer = %TopBar
@onready var pause_button: Button = %PauseButton
@onready var time_label: Label = %TimeLabel
@onready var stage_label: Label = %StageLabel
@onready var wave_label: Label = %WaveLabel
@onready var level_title_label: Label = %LevelTitleLabel
@onready var level_value_label: Label = %LevelValueLabel
@onready var exp_value_label: Label = %ExpValueLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var objective_panel: PanelContainer = %ObjectivePanel
@onready var objective_label: Label = %ObjectiveLabel
@onready var battlefield_frame: Control = %BattlefieldFrame
@onready var ammo_value_label: Label = %AmmoValueLabel
@onready var wall_hp_bar: ProgressBar = %WallHpBar
@onready var shield_row: HBoxContainer = %ShieldRow
@onready var shield_icon_label: Label = %ShieldIconLabel
@onready var shield_value_label: Label = %ShieldValueLabel
@onready var wall_hp_icon_label: Label = %WallHpIconLabel
@onready var wall_hp_value_label: Label = %WallHpValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var hero_name_label: Label = %HeroNameLabel
@onready var small_hero_icon: Control = (
	get_node_or_null("Root/SafeMargin/MainLayout/HeroStatusPanel/HeroStatusLayout/HeroCenter/HeroPortraitPanel/SmallHeroIcon") as Control
)
@onready var ultimate_layout: HBoxContainer = %UltimateLayout
@onready var ultimate_cost_badge: PanelContainer = %UltimateCostBadge
@onready var ultimate_cost_label: Label = %UltimateCostLabel
@onready var ultimate_bar: ProgressBar = %UltimateBar
@onready var hint_label: Label = %HintLabel
@onready var discard_hand_button: Button = %DiscardHandButton
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var draw_pile_button: Button = %DrawPileButton
@onready var bottom_toast_label: Label = %BottomToastLabel
@onready var hand_area: PanelContainer = %HandArea
@onready var hand_layer: Control = $Root/SafeMargin/MainLayout/HandArea/HandAreaRoot/HandLayer
@onready var main_menu_overlay: Control = %MainMenuOverlay
@onready var main_menu_panel: PanelContainer = %MainMenuPanel
@onready var main_menu_title_label: Label = %MainMenuTitleLabel
@onready var main_menu_summary_label: Label = %MainMenuSummaryLabel
@onready var start_game_button: Button = %StartGameButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_panel: Control = %PausePanel
@onready var pause_title_label: Label = %PauseTitleLabel
@onready var pause_summary_label: Label = %PauseSummaryLabel
@onready var pause_reward_spacer: Control = %PauseRewardSpacer
@onready var pause_actions: HBoxContainer = %PauseActions
@onready var continue_button: Button = %ContinueButton
@onready var exit_button: Button = %ExitButton
@onready var result_overlay_root: Control = %ResultOverlay
@onready var result_panel: Control = %ResultPanel
@onready var result_title_label: Label = %ResultTitleLabel
@onready var result_summary_label: Label = %ResultSummaryLabel
@onready var result_stats_label: Label = %ResultStatsLabel
@onready var result_reward_spacer: Control = %ResultRewardSpacer
@onready var result_return_button: Button = %ResultReturnButton
@onready var result_retry_button: Button = %ResultRetryButton
@onready var card_widgets: Array = HUD_CARD_WIDGETS.card_widgets_from_panels([%Card1, %Card2, %Card3, %Card4, %Card5])

var _snapshot: Dictionary = {}
var _layout_width := 0.0
var _gameplay_mode := true
var _gameplay_active := false
var card_interaction: HudCardInteraction = HUD_CARD_INTERACTION.new()
var layout_styler: HudLayoutStyler = HUD_LAYOUT_STYLER.new()
var card_visuals: HudCardVisuals = HUD_CARD_VISUALS.new()
var snapshot_presenter: HudSnapshotPresenter = HUD_SNAPSHOT_PRESENTER.new()
var card_snapshot_presenter: HudCardSnapshotPresenter = HUD_CARD_SNAPSHOT_PRESENTER.new()
var draw_card_fx := HUD_DRAW_CARD_FX.new()
var acquire_card_fx := preload("res://src/ui/HudAcquireCardFx.gd").new()
var play_card_fx := HUD_PLAY_CARD_FX.new()
var discard_hand_fx := HUD_DISCARD_HAND_FX.new()
var chain_flash_fx := HUD_CHAIN_FLASH_FX.new()
var ultimate_lock_icons: Array[TextureRect] = []
var reward_overlay: HudRewardOverlay = HudRewardOverlay.new()
var result_overlay: HudResultOverlay = HUD_RESULT_OVERLAY.new()
var pile_overlay_controller: HudPileOverlayController = HUD_PILE_OVERLAY_CONTROLLER.new()


func _ready() -> void:
	HUD_SETUP_COORDINATOR.setup(self, _setup_config())
	if not PrototypeState.state_changed.is_connected(set_battle_snapshot):
		PrototypeState.state_changed.connect(set_battle_snapshot)
	set_battle_snapshot(PrototypeState.get_snapshot())
	stop_battle_ui()


func _setup_config() -> Dictionary:
	return {
		"message_width_ratio": MESSAGE_WIDTH_RATIO,
		"compact_width": COMPACT_WIDTH,
		"ultimate_limit_segments": ULTIMATE_LIMIT_SEGMENTS,
		"limit_lock_icon_path": LIMIT_LOCK_ICON_PATH,
		"hand_area_z_index": HAND_AREA_Z_INDEX,
		"menu_overlay_z_index": MENU_OVERLAY_Z_INDEX,
		"card_frame_path": CARD_FRAME_PATH,
		"card_feel_config": CARD_FEEL_CONFIG,
		"hand_card_size": HAND_CARD_SIZE,
		"default_stage": DEFAULT_STAGE,
		"default_cards": HUD_DEFAULTS.DEFAULT_CARDS,
		"hud_theme": HUD_THEME,
		"card_art_fallback_path": CARD_ART_FALLBACK_PATH,
	}


func _process(delta: float) -> void:
	card_interaction.tick_feedback(delta)
	chain_flash_fx.update(delta)
	draw_card_fx.update(delta)
	acquire_card_fx.update(delta)
	play_card_fx.update(delta)
	discard_hand_fx.update(delta)
	if discard_hand_fx.consume_completed():
		_finish_discard_hand_animation()
	card_interaction.clamp_indices_to_hand()
	if _gameplay_active:
		card_interaction.recover_released_card_pointer()
		card_interaction.refresh_hover_from_pointer()
	else:
		card_interaction.cancel_card_interaction()
	_update_card_visuals(delta)


func _input(event: InputEvent) -> void:
	if pile_overlay_controller.handle_visible_pile_input(event):
		get_viewport().set_input_as_handled()
		return
	if pile_overlay_controller.handle_reward_pile_button_input(event):
		get_viewport().set_input_as_handled()
		return
	if reward_overlay.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not card_interaction.has_active_card_pointer():
		return
	if not _can_handle_card_input():
		card_interaction.cancel_card_interaction()
		return
	if event is InputEventMouseMotion:
		if card_interaction.handle_mouse_motion(event as InputEventMouseMotion):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			if card_interaction.handle_mouse_button(mouse_button):
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if card_interaction.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if main_menu_overlay.visible:
		return
	if reward_overlay.is_visible():
		return
	if result_overlay.is_visible():
		return
	if pile_overlay_controller.handle_cancel():
		get_viewport().set_input_as_handled()
		return
	if pause_overlay.visible:
		_close_pause_overlay()
	else:
		_open_pause_overlay()
	get_viewport().set_input_as_handled()


func _request_card_play(index: int, source: String) -> void:
	if not _is_valid_hand_index(index):
		_trigger_invalid_feedback(index, "卡牌已经离开手牌")
		card_interaction.cancel_card_interaction()
		return
	if _is_card_cooling_down(index):
		_trigger_invalid_feedback(index, _card_cooldown_message(index))
		card_interaction.cancel_card_interaction()
		return
	if _is_card_play_locked():
		_trigger_invalid_feedback(index, "上一张卡还在结算")
		card_interaction.cancel_card_interaction()
		return
	var card_name := _card_name_for_index(index)
	var captured_play_fx := play_card_fx.capture(index)
	var was_played := PrototypeState.try_play_hand_card(index, source)
	if was_played:
		play_card_fx.commit(captured_play_fx)
		_show_card_toast("%s 已释放" % card_name)
		card_interaction.selected_card_index = -1
		card_interaction.release_card_interaction()
		return
	play_card_fx.cancel(captured_play_fx)
	_trigger_invalid_feedback(index, _card_play_failure_message())
	card_interaction.cancel_card_interaction()


func _request_card_reorder(from_index: int, to_index: int) -> bool:
	if not _is_valid_hand_index(from_index) or not _is_valid_hand_index(to_index):
		return false
	if from_index == to_index:
		return false
	var moved := PrototypeState.reorder_hand_card(from_index, to_index)
	if moved:
		_show_card_toast("手牌已换位")
	return moved


func _can_handle_card_input() -> bool:
	return _gameplay_active and not _is_blocking_overlay_visible() and not discard_hand_fx.is_active() and _current_hand_count() > 0


func _release_card_interaction() -> void:
	card_interaction.release_card_interaction()


func _cancel_card_interaction() -> void:
	card_interaction.cancel_card_interaction()


func _on_card_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	card_interaction.on_card_gui_input(event, panel)


func _on_card_mouse_entered(panel: PanelContainer) -> void:
	card_interaction.on_card_mouse_entered(panel)


func _on_card_mouse_exited(panel: PanelContainer) -> void:
	card_interaction.on_card_mouse_exited(panel)


func set_battle_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	var status_values := snapshot_presenter.apply(snapshot)
	var energy := int(status_values.get("energy", 3))
	var energy_max := int(status_values.get("energy_max", ULTIMATE_LIMIT_SEGMENTS))
	_update_ultimate_limit_lock(energy_max)
	_update_buff_hint(snapshot)
	_update_cards(snapshot, energy)
	reward_overlay.update(snapshot, _gameplay_active, main_menu_overlay.visible, get_viewport().get_visible_rect().size, COMPACT_WIDTH)
	_update_piles(snapshot)
	chain_flash_fx.sync(snapshot, _gameplay_active)
	acquire_card_fx.sync_from_snapshot(snapshot, reward_overlay.selected_choice_global_center(), _gameplay_active)
	_update_result_overlay(snapshot)
	_apply_gameplay_mode()


func set_gameplay_mode(enabled: bool) -> void:
	_gameplay_mode = enabled
	_apply_gameplay_mode()


func _apply_styles() -> void:
	layout_styler.apply_styles()


func _apply_responsive_layout() -> void:
	layout_styler.apply_responsive_layout()


func _apply_gameplay_mode() -> void:
	hint_label.visible = _gameplay_active and not hint_label.text.is_empty()
	_sync_card_toast_visibility()


func _sync_card_toast_visibility() -> void:
	bottom_toast_label.visible = card_interaction.card_toast_timer > 0.0 and _gameplay_active


func _update_buff_hint(snapshot: Dictionary) -> void:
	hint_label.text = ""


func _update_result_overlay(snapshot: Dictionary) -> void:
	if not result_overlay.update(snapshot, PrototypeState.Phase.LOST, PrototypeState.Phase.WON):
		return
	_gameplay_active = false
	_cancel_card_interaction()
	_reset_card_fx()
	main_menu_overlay.visible = false
	pause_overlay.visible = false
	reward_overlay.hide()
	pile_overlay_controller.hide()
	pause_button.disabled = true


func _update_cards(snapshot: Dictionary, energy: int) -> void:
	var cards := card_snapshot_presenter.cards_from_snapshot(snapshot)
	_ensure_card_widget_count(cards.size())
	card_snapshot_presenter.apply(cards, snapshot, energy, _gameplay_active)
	_layout_hand_cards(cards.size())
	draw_card_fx.sync_after_layout(cards, _gameplay_active, acquire_card_fx.should_suppress_draw_fx(snapshot))


func _update_piles(snapshot: Dictionary) -> void:
	var draw_count := pile_overlay_controller.update(snapshot)
	discard_hand_button.text = _discard_hand_button_text(snapshot)
	discard_hand_button.disabled = not _can_discard_hand(snapshot)
	draw_card_fx.set_draw_count(draw_count, _gameplay_active)


func _discard_hand_button_text(snapshot: Dictionary) -> String:
	var discard_cooldown := maxf(0.0, float(snapshot.get("discard_cooldown", 0.0)))
	if discard_hand_fx.is_active():
		return "弃牌中"
	if discard_cooldown > 0.0:
		return "弃牌 %ds" % ceili(discard_cooldown)
	return "弃牌"


func _can_discard_hand(snapshot: Dictionary) -> bool:
	if not _gameplay_active or _is_blocking_overlay_visible():
		return false
	if discard_hand_fx.is_active():
		return false
	if float(snapshot.get("discard_cooldown", 0.0)) > 0.0:
		return false
	var cards_variant: Variant = snapshot.get("hand_cards", [])
	return cards_variant is Array and (cards_variant as Array).size() > 0


func _card_index_at_point(point: Vector2) -> int:
	return HUD_HAND_QUERIES.card_index_at_point(card_widgets, _current_hand_count(), point)


func _card_index_for_panel(panel: PanelContainer) -> int:
	return HUD_HAND_QUERIES.card_index_for_panel(card_widgets, panel)


func _is_valid_hand_index(index: int) -> bool:
	return HUD_HAND_QUERIES.is_valid_hand_index(index, _current_hand_count())


func _is_card_cooling_down(index: int) -> bool:
	if not _is_valid_hand_index(index):
		return false
	return _card_cooldown_remaining(index) > 0.0


func _card_cooldown_remaining(index: int) -> float:
	return HUD_HAND_QUERIES.card_cooldown_remaining(card_widgets, index)


func _card_cooldown_message(index: int) -> String:
	return HUD_HAND_QUERIES.card_cooldown_message(card_widgets, index)


func _is_card_play_locked() -> bool:
	return bool(_snapshot.get("card_play_locked", false)) or not bool(_snapshot.get("can_play_cards", true))


func _is_pointer_in_play_zone(point: Vector2) -> bool:
	var hand_rect := hand_layer.get_global_rect()
	return point.y < hand_rect.position.y + _feel_value("card_play_zone_height_offset")


func _card_reorder_index_at_point(point: Vector2, dragged_index: int) -> int:
	return HUD_HAND_QUERIES.card_reorder_index_at_point(
		card_widgets, hand_layer, HAND_CARD_SIZE, _current_hand_count(), point, dragged_index
	)


func _card_name_for_index(index: int) -> String:
	return HUD_HAND_QUERIES.card_name_for_index(_snapshot, HUD_DEFAULTS.DEFAULT_CARDS, index)


func _card_play_failure_message() -> String:
	return HUD_HAND_QUERIES.card_play_failure_message(_snapshot, HUD_DEFAULTS.CARD_PLAY_FAILURE_MESSAGES)


func _trigger_invalid_feedback(index: int, message: String) -> void:
	card_interaction.invalid_feedback_index = index
	card_interaction.invalid_feedback_timer = _feel_value("invalid_shake_time")
	_show_card_toast(message)
	_show_card_float_text(index, message)


func _show_card_toast(message: String) -> void:
	bottom_toast_label.text = message
	bottom_toast_label.visible = _gameplay_active
	card_interaction.card_toast_timer = 1.1


func _show_card_float_text(index: int, message: String) -> void:
	if index < 0 or index >= card_widgets.size():
		return
	HUD_CARD_WIDGETS.show_invalid_float_text(hand_layer, card_widgets[index], message)


func _update_card_visuals(delta: float) -> void:
	card_visuals.update(delta, _current_hand_count())


func _feel_value(key: String) -> float:
	return float(CARD_FEEL_CONFIG.get(key, 0.0))


func _lock_ultimate_meter_layout() -> void:
	layout_styler.lock_ultimate_meter_layout()


func _on_reward_button_pressed(index: int) -> void:
	if PrototypeState.choose_level_reward(index):
		reward_overlay.hide()
		_show_card_toast("词条已生效")


func _ensure_ultimate_lock_icons() -> void:
	layout_styler.ensure_ultimate_lock_icons()


func _update_ultimate_limit_lock(unlocked_segments: int) -> void:
	layout_styler.update_ultimate_limit_lock(unlocked_segments)


func _on_pause_pressed() -> void:
	HUD_BATTLE_UI_FLOW.on_pause_pressed(self)


func _open_pause_overlay() -> void:
	HUD_BATTLE_UI_FLOW.open_pause_overlay(self)


func _close_pause_overlay() -> void:
	HUD_BATTLE_UI_FLOW.close_pause_overlay(self)


func _on_exit_pressed() -> void:
	HUD_BATTLE_UI_FLOW.exit_to_result(self, PrototypeState.Phase.LOST, PrototypeState.Phase.WON)


func _on_start_game_pressed() -> void:
	HUD_BATTLE_UI_FLOW.on_start_game_pressed(self)


func start_battle_ui() -> void:
	HUD_BATTLE_UI_FLOW.start_battle_ui(self)


func stop_battle_ui() -> void:
	HUD_BATTLE_UI_FLOW.stop_battle_ui(self)


func _on_result_return_pressed() -> void:
	main_menu_requested.emit()


func is_gameplay_active() -> bool:
	return _gameplay_active


func _on_discard_hand_pressed() -> void:
	HUD_DISCARD_HAND_FLOW.on_discard_hand_pressed(self)


func _finish_discard_hand_animation() -> void:
	HUD_DISCARD_HAND_FLOW.finish_discard_hand_animation(self)


func _discard_hand_block_message() -> String:
	return HUD_DISCARD_HAND_FLOW.discard_hand_block_message(self)


func _is_blocking_overlay_visible() -> bool:
	return HUD_BATTLE_UI_FLOW.is_blocking_overlay_visible(self)


func _reset_card_fx() -> void:
	HUD_BATTLE_UI_FLOW.reset_card_fx(self)


func _style_cards() -> void:
	HUD_CARD_WIDGETS.ensure_card_texture_widgets(card_widgets, CARD_FRAME_PATH)
	HUD_CARD_WIDGETS.ensure_card_state_widgets(card_widgets)
	for widget in card_widgets:
		_style_card_widget(widget)


func _style_card_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	HUD_CARD_WIDGETS.bind_card_input_signals(panel, self)
	HUD_CARD_WIDGETS.style_card_widget(widget, HUD_THEME, HAND_CARD_SIZE)


func _ensure_card_widget_count(count: int) -> void:
	while card_widgets.size() < count:
		var source_panel: PanelContainer = card_widgets[0]["panel"] as PanelContainer
		var panel := source_panel.duplicate() as PanelContainer
		HUD_CARD_WIDGETS.clear_unique_names(panel)
		panel.name = "Card%d" % (card_widgets.size() + 1)
		hand_layer.add_child(panel)
		var widget: Dictionary = HUD_CARD_WIDGETS.card_widget_from_panel(panel)
		card_widgets.append(widget)
		_style_card_widget(widget)


func _layout_hand_cards(visible_count: int) -> void:
	var should_snap_cards := (
		card_interaction.interaction_owner_index == -1
		and card_interaction.hover_index == -1
		and card_interaction.selected_card_index == -1
		and card_interaction.invalid_feedback_index == -1
		and card_interaction.card_reorder_lock_timer <= 0.0
	)
	HUD_CARD_WIDGETS.layout_hand_cards(card_widgets, visible_count, hand_layer.size.x, HAND_CARD_SIZE, should_snap_cards)
	if visible_count <= 0:
		card_interaction.cancel_card_interaction()


func _current_hand_count() -> int:
	return HUD_HAND_QUERIES.current_hand_count(_snapshot, HUD_DEFAULTS.DEFAULT_CARDS)


func _all_labels() -> Array:
	return HUD_UI_HELPERS.all_labels(self)
