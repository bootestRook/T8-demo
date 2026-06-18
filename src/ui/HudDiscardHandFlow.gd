extends RefCounted
class_name HudDiscardHandFlow

const HUD_UI_HELPERS := preload("res://src/ui/HudUiHelpers.gd")


static func on_discard_hand_pressed(hud) -> void:
	var snapshot: Dictionary = hud.get("_snapshot")
	if not hud._can_discard_hand(snapshot):
		hud._show_card_toast(discard_hand_block_message(hud))
		return
	hud._cancel_card_interaction()
	if hud.discard_hand_fx.start(hud._current_hand_count()):
		hud.discard_hand_button.disabled = true
		hud._show_card_toast("正在弃牌")
		return
	finish_discard_hand_animation(hud)


static func finish_discard_hand_animation(hud) -> void:
	if PrototypeState.discard_hand():
		hud._show_card_toast("已丢掉手牌")
		return
	hud._show_card_toast(discard_hand_block_message(hud))


static func discard_hand_block_message(hud) -> String:
	var snapshot: Dictionary = hud.get("_snapshot")
	return HUD_UI_HELPERS.discard_hand_block_message(
		hud.is_gameplay_active(),
		hud._is_blocking_overlay_visible(),
		hud.discard_hand_fx.is_active(),
		float(snapshot.get("discard_cooldown", 0.0)),
		hud._current_hand_count()
	)
