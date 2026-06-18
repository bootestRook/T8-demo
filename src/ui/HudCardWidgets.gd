extends RefCounted
class_name HudCardWidgets

const HUD_CARD_PRESS_FX := preload("res://src/ui/HudCardPressFx.gd")
const HUD_CARD_READABILITY_REGIONS := preload("res://src/ui/HudCardReadabilityRegions.gd")
const HUD_CARD_CHAIN_HINT_WIDGET := preload("res://src/ui/HudCardChainHintWidget.gd")
const HUD_CARD_LABEL_STYLER := preload("res://src/ui/HudCardLabelStyler.gd")
const HUD_CARD_NODE_FINDER := preload("res://src/ui/HudCardNodeFinder.gd")
const HUD_CARD_ART_BINDER := preload("res://src/ui/HudCardArtBinder.gd")
const HUD_CARD_DESCRIPTION_TEXT := preload("res://src/ui/HudCardDescriptionText.gd")
const HUD_CARD_HAND_LAYOUT := preload("res://src/ui/HudCardHandLayout.gd")

const DESC_FONT_SCALE := 0.8
const DESC_RICH_TEXT_FONT_SCALE := 1.0


static func ensure_card_texture_widgets(card_widgets: Array, card_frame_path: String) -> void:
	HUD_CARD_ART_BINDER.ensure_card_texture_widgets(card_widgets, card_frame_path)


static func card_widgets_from_panels(panels: Array) -> Array:
	var widgets: Array = []
	for panel in panels:
		widgets.append(card_widget_from_panel(panel as PanelContainer))
	return widgets


static func ensure_card_state_widgets(card_widgets: Array) -> void:
	for widget in card_widgets:
		_hide_legacy_card_charge_widget(widget)
		ensure_card_disabled_widget(widget)
		ensure_card_chain_hint_widget(widget)
		ensure_card_press_widget(widget)


static func _hide_legacy_card_charge_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	var charge_backdrop := widget.get("charge_backdrop", null) as ColorRect
	if charge_backdrop == null:
		charge_backdrop = HUD_CARD_NODE_FINDER.find_color_rect_by_suffix(panel, "ChargeBackdrop")
	if charge_backdrop != null:
		charge_backdrop.visible = false
		widget["charge_backdrop"] = charge_backdrop

	var charge_fill := widget.get("charge_fill", null) as ColorRect
	if charge_fill == null:
		charge_fill = HUD_CARD_NODE_FINDER.find_color_rect_by_suffix(panel, "ChargeFill")
	if charge_fill != null:
		charge_fill.visible = false
		widget["charge_fill"] = charge_fill


static func ensure_card_disabled_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	var cost_label: Label = widget["cost"] as Label
	var parent := cost_label.get_parent() as Control
	var disabled_overlay := HUD_CARD_NODE_FINDER.find_color_rect_by_suffix(panel, "DisabledOverlay")
	if disabled_overlay == null:
		disabled_overlay = ColorRect.new()
		disabled_overlay.name = "%sDisabledOverlay" % String(panel.name)
		disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(disabled_overlay)
	disabled_overlay.color = Color(0.03, 0.03, 0.04, 0.58)
	disabled_overlay.visible = false
	widget["disabled_overlay"] = disabled_overlay

	var disabled_icon := HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "DisabledIcon")
	if disabled_icon == null:
		disabled_icon = Label.new()
		disabled_icon.name = "%sDisabledIcon" % String(panel.name)
		disabled_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(disabled_icon)
	disabled_icon.text = "X"
	disabled_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disabled_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disabled_icon.add_theme_font_size_override("font_size", 62)
	disabled_icon.add_theme_color_override("font_color", Color(1.0, 0.26, 0.30, 0.95))
	disabled_icon.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0, 0.96))
	disabled_icon.add_theme_constant_override("outline_size", 4)
	disabled_icon.visible = false
	widget["disabled_icon"] = disabled_icon


static func ensure_card_chain_hint_widget(widget: Dictionary) -> void:
	HUD_CARD_CHAIN_HINT_WIDGET.ensure_widget(widget)


static func ensure_card_press_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	var cost_label: Label = widget["cost"] as Label
	var parent := cost_label.get_parent() as Control
	var press_fx := HUD_CARD_NODE_FINDER.find_card_press_fx_by_suffix(panel, "PressFx")
	if press_fx == null:
		press_fx = HUD_CARD_PRESS_FX.new()
		press_fx.name = "%sPressFx" % String(panel.name)
		press_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(press_fx)
	press_fx.visible = false
	widget["press_fx"] = press_fx


static func update_card_disabled(widget: Dictionary, disabled: bool) -> void:
	ensure_card_disabled_widget(widget)
	var disabled_overlay: ColorRect = widget["disabled_overlay"] as ColorRect
	var disabled_icon: Label = widget["disabled_icon"] as Label
	disabled_overlay.visible = disabled
	disabled_icon.visible = disabled


static func update_card_chain_hint(widget: Dictionary, active: bool, time: float) -> void:
	HUD_CARD_CHAIN_HINT_WIDGET.update_widget(widget, active, time)


static func card_display_cost_text(card: Dictionary, energy_cost: int) -> String:
	var cost_text := str(card.get("display_cost_text", card.get("display_cost", energy_cost)))
	return str(energy_cost) if cost_text.is_empty() else cost_text


static func card_cost_color(_card: Dictionary, usable: bool, disabled: bool) -> Color:
	if disabled or not usable:
		return Color(0.48, 0.48, 0.50, 0.94)
	return Color(1.0, 1.0, 1.0)


static func show_invalid_float_text(parent: Control, widget: Dictionary, message: String) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	if not panel.visible:
		return
	var label := Label.new()
	label.text = message
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(220.0, 40.0)
	label.position = panel.position + Vector2((panel.size.x - label.size.x) * 0.5, -42.0)
	label.z_index = 720
	label.modulate = Color(1.0, 0.26, 0.32, 1.0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 44.0, 0.46)
	tween.tween_property(label, "modulate:a", 0.0, 0.22)
	tween.tween_callback(Callable(label, "queue_free"))


static func apply_card_art(widget: Dictionary, card: Dictionary, fallback_path: String) -> void:
	HUD_CARD_ART_BINDER.apply_card_art(widget, card, fallback_path)


static func school_icon_path(card: Dictionary) -> String:
	return HUD_CARD_ART_BINDER.school_icon_path(card)


static func style_card_widget(widget: Dictionary, theme: Variant, hand_card_size: Vector2) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	widget["card_text_scale"] = HUD_CARD_LABEL_STYLER.card_text_scale(hand_card_size)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", theme.card_frame_style())
	_hide_legacy_card_charge_widget(widget)
	ensure_card_disabled_widget(widget)
	ensure_card_chain_hint_widget(widget)
	ensure_card_press_widget(widget)
	ensure_card_desc_rich_text_widget(widget)
	set_card_descendants_mouse_filter(panel)
	for key in ["cost", "art", "name", "type", "school"]:
		var label: Label = widget[key] as Label
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.60))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.clip_text = true
	var desc_control := widget["desc"] as Control
	desc_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_card_readability_regions(widget, hand_card_size)
	HUD_CARD_LABEL_STYLER.style_card_labels(widget, theme)


static func apply_card_text(widget: Dictionary, card: Dictionary, index: int, theme: Variant) -> void:
	var name_text: String = String(card.get("name", "Card")).strip_edges()
	var effect_text: String = theme.format_card_effect_text(String(card.get("effect", card.get("desc", "Play effect"))))
	var effect_rich_text: String = theme.format_card_effect_text(
		String(card.get("effect_rich_text", card.get("desc_rich_text", effect_text)))
	)
	var school_text: String = String(card.get("school", theme.school_name(index))).strip_edges()
	var text_scale := float(widget.get("card_text_scale", 1.0))
	var base_desc_font_size := float(theme.card_effect_text_size(effect_text)) * text_scale
	var desc_font_size := maxi(6, int(base_desc_font_size * DESC_FONT_SCALE + 0.5))
	var rich_text_font_size := maxi(6, int(base_desc_font_size * DESC_RICH_TEXT_FONT_SCALE + 0.5))
	(widget["name"] as Label).text = name_text
	_apply_desc_text(widget["desc"] as Control, effect_text, effect_rich_text, rich_text_font_size)
	(widget["school"] as Label).text = school_text
	(widget["name"] as Label).add_theme_font_size_override(
		"font_size", HUD_CARD_LABEL_STYLER.scaled_font_size(theme.card_text_size(name_text, 14, 13, 12, 11), text_scale)
	)
	HUD_CARD_DESCRIPTION_TEXT.apply_font_size(widget["desc"] as Control, desc_font_size)
	(widget["school"] as Label).add_theme_font_size_override(
		"font_size", HUD_CARD_LABEL_STYLER.scaled_font_size(theme.card_text_size(school_text, 14, 13, 12, 11), text_scale)
	)


static func bind_card_input_signals(panel: PanelContainer, target: Object) -> void:
	var gui_callable := Callable(target, "_on_card_gui_input").bind(panel)
	if not panel.gui_input.is_connected(gui_callable):
		panel.gui_input.connect(gui_callable)
	var entered_callable := Callable(target, "_on_card_mouse_entered").bind(panel)
	if not panel.mouse_entered.is_connected(entered_callable):
		panel.mouse_entered.connect(entered_callable)
	var exited_callable := Callable(target, "_on_card_mouse_exited").bind(panel)
	if not panel.mouse_exited.is_connected(exited_callable):
		panel.mouse_exited.connect(exited_callable)


static func load_card_texture(path: String) -> Texture2D:
	return HUD_CARD_ART_BINDER.load_card_texture(path)


static func set_card_descendants_mouse_filter(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_card_descendants_mouse_filter(child)


static func layout_card_readability_regions(widget: Dictionary, hand_card_size: Vector2) -> void:
	HUD_CARD_READABILITY_REGIONS.layout_card_readability_regions(widget, hand_card_size)


static func layout_hand_cards(
	card_widgets: Array, visible_count: int, hand_width: float, hand_card_size: Vector2, should_snap: bool
) -> void:
	HUD_CARD_HAND_LAYOUT.layout(card_widgets, visible_count, hand_width, hand_card_size, should_snap)


static func snap_card_widget_to_base(widget: Dictionary) -> void:
	HUD_CARD_HAND_LAYOUT.snap(widget)


static func card_widget_from_panel(panel: PanelContainer) -> Dictionary:
	return {
		"panel": panel,
		"cost": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "CostLabel"),
		"art": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "ArtLabel"),
		"name": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "NameLabel"),
		"type": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "TypeLabel"),
		"desc": ensure_card_desc_rich_text_label(panel),
		"school": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "SchoolIconLabel"),
		"frame_texture": HUD_CARD_NODE_FINDER.find_texture_rect_by_suffix(panel, "FrameTexture"),
		"art_texture": HUD_CARD_NODE_FINDER.find_texture_rect_by_suffix(panel, "ArtTexture"),
		"disabled_overlay": HUD_CARD_NODE_FINDER.find_color_rect_by_suffix(panel, "DisabledOverlay"),
		"disabled_icon": HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "DisabledIcon"),
		"chain_cost_glow": HUD_CARD_NODE_FINDER.find_panel_by_suffix(panel, "ChainCostGlowPanel"),
		"press_fx": HUD_CARD_NODE_FINDER.find_card_press_fx_by_suffix(panel, "PressFx"),
	}


static func ensure_card_desc_rich_text_widget(widget: Dictionary) -> void:
	HUD_CARD_DESCRIPTION_TEXT.ensure_widget(widget)


static func ensure_card_desc_rich_text_label(panel: PanelContainer) -> Control:
	return HUD_CARD_DESCRIPTION_TEXT.ensure_label(panel)


static func _apply_desc_text(desc_control: Control, plain_text: String, rich_text: String, rich_text_font_size: int) -> void:
	HUD_CARD_DESCRIPTION_TEXT.apply_text(desc_control, plain_text, rich_text, rich_text_font_size)


static func clear_unique_names(node: Node) -> void:
	HUD_CARD_NODE_FINDER.clear_unique_names(node)
