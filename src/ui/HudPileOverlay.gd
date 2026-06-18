extends RefCounted
class_name HudPileOverlay

const HUD_THEME := preload("res://src/ui/HudTheme.gd")
const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")
const HUD_PILE_OVERLAY_VIEW := preload("res://src/ui/HudPileOverlayView.gd")
const CARD_FRAME_PATH := "res://assets/ui/cards/card_frame_v1.png"
const CARD_ART_FALLBACK_PATH := "res://assets/ui/cards/card_art_fallback_v1.png"
const BASE_CARD_SIZE := Vector2(150.0, 266.667)
const CARD_MIN_WIDTH := 220.0
const CARD_TARGET_WIDTH_RATIO := 0.24
const CARD_MAX_WIDTH := 270.0
const PANEL_WIDTH_RATIO := 0.92
const PANEL_HEIGHT_RATIO := 0.72
const PANEL_MAX_HEIGHT_RATIO := 0.84
const PANEL_HORIZONTAL_PADDING := 104.0

var overlay: Control = null
var panel: PanelContainer = null
var title_label: Label = null
var close_button: Button = null
var scroll: ScrollContainer = null
var grid_margin: MarginContainer = null
var grid: GridContainer = null
var empty_label: Label = null
var source_card_panel: PanelContainer = null
var close_pressed: Callable = Callable()
var current_card_size := BASE_CARD_SIZE


func setup(root: Control, card_panel: PanelContainer, close_callable: Callable) -> void:
	source_card_panel = card_panel
	close_pressed = close_callable
	_ensure_overlay(root)


func is_visible() -> bool:
	return overlay != null and overlay.visible


func show_cards(cards: Array, viewport_size: Vector2, title := "牌堆") -> void:
	if overlay == null:
		return
	title_label.text = title
	empty_label.text = "%s为空" % title
	overlay.visible = true
	_apply_card_metrics(viewport_size)
	_rebuild_cards(cards)
	layout(viewport_size)
	close_button.grab_focus()


func hide() -> void:
	if overlay != null:
		overlay.visible = false


func layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	_apply_card_metrics(viewport_size)
	var card_gap := int(clampf(viewport_size.x * 0.035, 28.0, 44.0))
	var content_width := current_card_size.x * 2.0 + float(card_gap)
	var max_panel_width := viewport_size.x * PANEL_WIDTH_RATIO
	var panel_width := minf(max_panel_width, content_width + PANEL_HORIZONTAL_PADDING)
	var max_panel_height := viewport_size.y * PANEL_MAX_HEIGHT_RATIO
	var panel_height := minf(clampf(viewport_size.y * PANEL_HEIGHT_RATIO, 560.0, 1280.0), max_panel_height)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", card_gap)
	grid.add_theme_constant_override("v_separation", 30)
	var scroll_width := maxf(0.0, panel_width - 52.0)
	var side_margin := int(maxf(0.0, (scroll_width - content_width) * 0.5))
	grid_margin.add_theme_constant_override("margin_left", side_margin)
	grid_margin.add_theme_constant_override("margin_right", side_margin)


func handle_cancel() -> bool:
	if not is_visible():
		return false
	_request_close()
	return true


func _ensure_overlay(root: Control) -> void:
	var nodes := HUD_PILE_OVERLAY_VIEW.build(root, Callable(self, "_request_close"), Callable(self, "_on_shade_gui_input"))
	overlay = nodes["overlay"] as Control
	panel = nodes["panel"] as PanelContainer
	title_label = nodes["title_label"] as Label
	close_button = nodes["close_button"] as Button
	scroll = nodes["scroll"] as ScrollContainer
	grid_margin = nodes["grid_margin"] as MarginContainer
	grid = nodes["grid"] as GridContainer
	empty_label = nodes["empty_label"] as Label


func _rebuild_cards(cards: Array) -> void:
	while grid.get_child_count() > 0:
		var child := grid.get_child(0)
		grid.remove_child(child)
		child.queue_free()
	empty_label.visible = cards.is_empty()
	scroll.visible = not cards.is_empty()
	for index in range(cards.size()):
		if not (cards[index] is Dictionary):
			continue
		var panel_node := _build_card(cards[index] as Dictionary, index)
		grid.add_child(panel_node)


func _build_card(card: Dictionary, index: int) -> Control:
	var cell := Control.new()
	cell.name = "DrawPileCardCell%d" % (index + 1)
	cell.custom_minimum_size = current_card_size
	cell.size = current_card_size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_node := source_card_panel.duplicate(0) as PanelContainer
	HUD_CARD_WIDGETS.clear_unique_names(panel_node)
	panel_node.name = "DrawPileCard%d" % (index + 1)
	panel_node.custom_minimum_size = current_card_size
	panel_node.position = Vector2.ZERO
	panel_node.size = current_card_size
	panel_node.scale = Vector2.ONE
	panel_node.rotation = 0.0
	panel_node.pivot_offset = Vector2.ZERO
	cell.add_child(panel_node)
	_populate_card_panel(panel_node, card, index, current_card_size)
	return cell


func _populate_card_panel(panel_node: PanelContainer, card: Dictionary, index: int, card_size: Vector2) -> void:
	panel_node.custom_minimum_size = card_size
	panel_node.size = card_size
	var widget := HUD_CARD_WIDGETS.card_widget_from_panel(panel_node)
	HUD_CARD_WIDGETS.style_card_widget(widget, HUD_THEME, card_size)
	HUD_CARD_WIDGETS.ensure_card_texture_widgets([widget], CARD_FRAME_PATH)
	HUD_CARD_WIDGETS.apply_card_art(widget, card, CARD_ART_FALLBACK_PATH)
	var energy_cost := int(card.get("energy_cost", card.get("cost", 0)))
	(widget["cost"] as Label).text = HUD_CARD_WIDGETS.card_display_cost_text(card, energy_cost)
	(widget["cost"] as Label).add_theme_color_override("font_color", HUD_CARD_WIDGETS.card_cost_color(card, true, false))
	(widget["type"] as Label).text = ""
	HUD_CARD_WIDGETS.apply_card_text(widget, card, index, HUD_THEME)
	HUD_CARD_WIDGETS.update_card_disabled(widget, false)
	HUD_CARD_WIDGETS.set_card_descendants_mouse_filter(panel_node)
	panel_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_card_metrics(viewport_size: Vector2) -> void:
	var card_gap := clampf(viewport_size.x * 0.035, 28.0, 44.0)
	var max_panel_width := viewport_size.x * PANEL_WIDTH_RATIO
	var max_card_width := (max_panel_width - PANEL_HORIZONTAL_PADDING - card_gap) * 0.5
	var card_width := minf(clampf(viewport_size.x * CARD_TARGET_WIDTH_RATIO, CARD_MIN_WIDTH, CARD_MAX_WIDTH), max_card_width)
	current_card_size = Vector2(card_width, card_width * BASE_CARD_SIZE.y / BASE_CARD_SIZE.x)


func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			_request_close()


func _request_close() -> void:
	if close_pressed.is_valid():
		close_pressed.call()
