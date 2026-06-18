extends RefCounted
class_name HudBattleUiFlow


static func on_pause_pressed(hud) -> void:
	if not hud.is_gameplay_active():
		return
	if hud.reward_overlay.is_visible():
		return
	if hud.result_overlay.is_visible():
		return
	if hud.pile_overlay_controller.is_visible():
		return
	open_pause_overlay(hud)


static func open_pause_overlay(hud) -> void:
	hud.set("_gameplay_active", false)
	hud.pause_overlay.visible = true
	hud.continue_button.grab_focus()


static func close_pause_overlay(hud) -> void:
	hud.pause_overlay.visible = false
	hud.set("_gameplay_active", true)
	hud.pause_button.grab_focus()


static func exit_to_result(hud, lost_phase: int, won_phase: int) -> void:
	hud.pause_overlay.visible = false
	hud.reward_overlay.hide()
	hud.pile_overlay_controller.hide()
	hud.set("_gameplay_active", false)
	hud._cancel_card_interaction()
	reset_card_fx(hud)
	hud.pause_button.disabled = true
	var exit_snapshot: Dictionary = hud.get("_snapshot").duplicate(true)
	exit_snapshot["phase"] = lost_phase
	hud.result_overlay.update(exit_snapshot, lost_phase, won_phase)


static func on_start_game_pressed(hud) -> void:
	start_battle_ui(hud)
	PrototypeState.reset()


static func start_battle_ui(hud) -> void:
	hud.main_menu_overlay.visible = false
	hud.pause_overlay.visible = false
	hud.result_overlay.hide()
	hud.reward_overlay.hide()
	hud.pile_overlay_controller.hide()
	hud.set("_gameplay_active", true)
	reset_card_fx(hud)
	hud.pause_button.disabled = false
	hud.pause_button.grab_focus()


static func stop_battle_ui(hud) -> void:
	hud.set("_gameplay_active", false)
	reset_card_fx(hud)
	hud.main_menu_overlay.visible = false
	hud.pause_overlay.visible = false
	hud.result_overlay.hide()
	hud.reward_overlay.hide()
	hud.pile_overlay_controller.hide()
	hud.pause_button.disabled = true


static func is_blocking_overlay_visible(hud) -> bool:
	return (
		hud.main_menu_overlay.visible
		or hud.pause_overlay.visible
		or hud.result_overlay.is_visible()
		or hud.reward_overlay.is_visible()
		or hud.pile_overlay_controller.is_visible()
	)


static func reset_card_fx(hud) -> void:
	hud.draw_card_fx.reset()
	hud.acquire_card_fx.reset()
	hud.play_card_fx.reset()
	hud.discard_hand_fx.reset()
	hud.chain_flash_fx.reset()
