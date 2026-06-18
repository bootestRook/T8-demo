extends RefCounted
class_name HudPileOverlayController

const HUD_PILE_OVERLAY := preload("res://src/ui/HudPileOverlay.gd")
const DISCARD_PILE_TITLE := "弃牌"
const DRAW_PILE_TITLE := "牌堆"

var hud: Node = null
var pile_overlay: HudPileOverlay = HUD_PILE_OVERLAY.new()
var reward_overlay: HudRewardOverlay = null
var result_overlay: HudResultOverlay = null
var main_menu_overlay: Control = null
var pause_overlay: Control = null
var discard_pile_button: Button = null
var draw_pile_button: Button = null
var pause_button: Button = null
var menu_overlay_z_index := 0


func setup(owner: Node, root: Control, card_panel: PanelContainer, menu_z: int) -> void:
	hud = owner
	_bind_hud_refs()
	menu_overlay_z_index = menu_z
	pile_overlay.setup(root, card_panel, Callable(self, "close"))
	discard_pile_button.pressed.connect(Callable(self, "open").bind("discard_pile_cards", DISCARD_PILE_TITLE))
	draw_pile_button.pressed.connect(Callable(self, "open").bind("draw_pile_cards", DRAW_PILE_TITLE))


func update(snapshot: Dictionary) -> int:
	var discard_count := int(snapshot.get("discard_count", 8))
	var draw_count := int(snapshot.get("draw_count", 18))
	discard_pile_button.text = str(discard_count)
	draw_pile_button.text = str(draw_count)
	var z := _button_z()
	discard_pile_button.z_index = z
	draw_pile_button.z_index = z
	return draw_count


func open(snapshot_key: String, title: String) -> void:
	if not _can_open():
		return
	if not reward_overlay.is_visible():
		hud.set("_gameplay_active", false)
	hud.call("_cancel_card_interaction")
	hud.call("_reset_card_fx")
	show_cards(_pile_cards(snapshot_key), title)


func show_cards(cards: Array, title: String) -> void:
	if hud == null:
		return
	pile_overlay.show_cards(cards, hud.get_viewport().get_visible_rect().size, title)


func layout(viewport_size: Vector2) -> void:
	pile_overlay.layout(viewport_size)


func hide() -> void:
	pile_overlay.hide()


func close() -> void:
	hide()
	if _is_blocking_overlay_visible():
		return
	hud.set("_gameplay_active", true)
	if pause_button != null:
		pause_button.grab_focus()


func is_visible() -> bool:
	return pile_overlay.is_visible()


func handle_cancel() -> bool:
	return pile_overlay.handle_cancel()


func handle_visible_pile_input(event: InputEvent) -> bool:
	if pile_overlay == null or not pile_overlay.is_visible():
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
		return false
	var point := mouse_button.global_position
	if pile_overlay.close_button != null and pile_overlay.close_button.get_global_rect().has_point(point):
		close()
		return true
	if pile_overlay.panel != null and not pile_overlay.panel.get_global_rect().has_point(point):
		close()
		return true
	return false


func handle_reward_pile_button_input(event: InputEvent) -> bool:
	if reward_overlay == null or not reward_overlay.is_visible() or pile_overlay.is_visible():
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
		return false
	var point := mouse_button.global_position
	if draw_pile_button != null and draw_pile_button.get_global_rect().has_point(point):
		open("draw_pile_cards", DRAW_PILE_TITLE)
		return true
	if discard_pile_button != null and discard_pile_button.get_global_rect().has_point(point):
		open("discard_pile_cards", DISCARD_PILE_TITLE)
		return true
	return false


func _bind_hud_refs() -> void:
	reward_overlay = hud.get("reward_overlay") as HudRewardOverlay
	result_overlay = hud.get("result_overlay") as HudResultOverlay
	main_menu_overlay = hud.get("main_menu_overlay") as Control
	pause_overlay = hud.get("pause_overlay") as Control
	discard_pile_button = hud.get("discard_pile_button") as Button
	draw_pile_button = hud.get("draw_pile_button") as Button
	pause_button = hud.get("pause_button") as Button


func _button_z() -> int:
	if reward_overlay != null and pile_overlay != null and reward_overlay.is_visible() and not pile_overlay.is_visible():
		return menu_overlay_z_index + 10
	return 0


func _can_open() -> bool:
	if hud == null or pile_overlay == null or reward_overlay == null or result_overlay == null:
		return false
	if main_menu_overlay == null or pause_overlay == null:
		return false
	var gameplay_active := bool(hud.get("_gameplay_active"))
	return (
		(gameplay_active or reward_overlay.is_visible())
		and not (main_menu_overlay.visible or pause_overlay.visible or result_overlay.is_visible() or pile_overlay.is_visible())
	)


func _is_blocking_overlay_visible() -> bool:
	return (
		main_menu_overlay.visible
		or pause_overlay.visible
		or result_overlay.is_visible()
		or reward_overlay.is_visible()
		or pile_overlay.is_visible()
	)


func _pile_cards(snapshot_key: String) -> Array:
	var snapshot := hud.get("_snapshot") as Dictionary
	var cards_variant: Variant = snapshot.get(snapshot_key, [])
	return cards_variant as Array if cards_variant is Array else []
