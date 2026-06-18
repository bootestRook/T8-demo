extends RefCounted
class_name HudSetupCoordinator

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")


static func setup(hud, config: Dictionary) -> void:
	_setup_controllers(hud, config)
	_setup_canvas_state(hud, config)
	_connect_signals(hud)
	_setup_card_fx(hud, config)
	_setup_overlays(hud, config)
	_setup_presenters(hud, config)
	_apply_initial_layout(hud)


static func _setup_controllers(hud, config: Dictionary) -> void:
	hud.card_interaction.setup(hud)
	hud.layout_styler.setup(
		hud,
		float(config["message_width_ratio"]),
		float(config["compact_width"]),
		int(config["ultimate_limit_segments"]),
		String(config["limit_lock_icon_path"])
	)


static func _setup_canvas_state(hud, config: Dictionary) -> void:
	hud.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.hand_area.z_index = int(config["hand_area_z_index"])
	hud.main_menu_overlay.z_index = int(config["menu_overlay_z_index"])
	hud.pause_overlay.z_index = int(config["menu_overlay_z_index"])
	hud.result_overlay_root.z_index = int(config["menu_overlay_z_index"])
	hud.main_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


static func _connect_signals(hud) -> void:
	hud.start_game_button.pressed.connect(Callable(hud, "_on_start_game_pressed"))
	hud.pause_button.pressed.connect(Callable(hud, "_on_pause_pressed"))
	hud.continue_button.pressed.connect(Callable(hud, "_close_pause_overlay"))
	hud.exit_button.pressed.connect(Callable(hud, "_on_exit_pressed"))
	hud.discard_hand_button.pressed.connect(Callable(hud, "_on_discard_hand_pressed"))
	hud.get_viewport().size_changed.connect(Callable(hud, "_apply_responsive_layout"))


static func _setup_card_fx(hud, config: Dictionary) -> void:
	hud.layout_styler.ensure_ultimate_lock_icons()
	HUD_CARD_WIDGETS.ensure_card_texture_widgets(hud.card_widgets, String(config["card_frame_path"]))
	hud.chain_flash_fx.setup(hud.battlefield_frame)
	hud.draw_card_fx.setup(hud.hand_layer, hud.draw_pile_button, hud.card_widgets)
	hud.acquire_card_fx.setup(hud.hand_layer, hud.draw_pile_button, hud.card_widgets)
	hud.play_card_fx.setup(hud.hand_layer, hud.card_widgets)
	hud.discard_hand_fx.setup(hud.hand_layer, hud.discard_pile_button, hud.card_widgets)
	hud.card_visuals.setup(
		hud.card_widgets,
		hud.hand_layer,
		hud.card_interaction,
		config["card_feel_config"],
		config["hand_card_size"],
		hud.draw_card_fx,
		hud.acquire_card_fx,
		hud.discard_hand_fx
	)


static func _setup_overlays(hud, config: Dictionary) -> void:
	hud.pile_overlay_controller.setup(hud, hud.root, hud.card_widgets[0]["panel"], int(config["menu_overlay_z_index"]))
	hud.reward_overlay.setup(hud.root)
	var reward_callable := Callable(hud, "_on_reward_button_pressed")
	if not hud.reward_overlay.choice_selected.is_connected(reward_callable):
		hud.reward_overlay.choice_selected.connect(reward_callable)
	hud.result_overlay.setup(
		hud.result_overlay_root,
		hud.result_panel,
		hud.result_title_label,
		hud.result_summary_label,
		hud.result_stats_label,
		hud.result_reward_spacer,
		hud.result_return_button,
		hud.result_retry_button,
		Callable(hud, "_on_result_return_pressed"),
		Callable(hud, "_on_start_game_pressed")
	)


static func _setup_presenters(hud, config: Dictionary) -> void:
	hud.snapshot_presenter.setup(_snapshot_nodes(hud), String(config["default_stage"]), int(config["ultimate_limit_segments"]))
	hud.card_snapshot_presenter.setup(
		hud.card_widgets, config["default_cards"], config["hud_theme"], String(config["card_art_fallback_path"])
	)


static func _snapshot_nodes(hud) -> Dictionary:
	return {
		"small_hero_icon": hud.small_hero_icon,
		"time_label": hud.time_label,
		"stage_label": hud.stage_label,
		"wave_label": hud.wave_label,
		"level_value_label": hud.level_value_label,
		"exp_value_label": hud.exp_value_label,
		"exp_bar": hud.exp_bar,
		"objective_panel": hud.objective_panel,
		"objective_label": hud.objective_label,
		"ammo_value_label": hud.ammo_value_label,
		"wall_hp_value_label": hud.wall_hp_value_label,
		"wall_hp_bar": hud.wall_hp_bar,
		"shield_row": hud.shield_row,
		"shield_value_label": hud.shield_value_label,
		"energy_value_label": hud.energy_value_label,
		"hero_name_label": hud.hero_name_label,
		"ultimate_cost_label": hud.ultimate_cost_label,
		"ultimate_bar": hud.ultimate_bar,
	}


static func _apply_initial_layout(hud) -> void:
	hud.layout_styler.apply_styles()
	hud.layout_styler.lock_ultimate_meter_layout()
	hud.layout_styler.apply_responsive_layout()
