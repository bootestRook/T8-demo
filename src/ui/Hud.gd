extends CanvasLayer

const CARD_MIN_HEIGHT := 148.0
const UPGRADE_CARD_WIDTH := 260.0
const UPGRADE_CARD_HEIGHT := 360.0

@onready var root: Control = $Root
@onready var safe_margin: MarginContainer = $Root/SafeMargin
@onready var top_bar: GridContainer = %TopBar
@onready var message_panel: PanelContainer = %MessagePanel
@onready var message_margin: MarginContainer = %MessageMargin
@onready var objective_label: Label = %ObjectiveLabel
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel
@onready var message_label: Label = %MessageLabel
@onready var bottom_hint_label: Label = %BottomHintLabel

var _snapshot: Dictionary = {}
var _top_hud: VBoxContainer
var _wall_bar: ProgressBar
var _energy_bar: ProgressBar
var _exp_bar: ProgressBar
var _resource_label: Label
var _deck_label: Label
var _discard_label: Label
var _hand_panel: PanelContainer
var _hand_row: HBoxContainer
var _discard_button: Button
var _upgrade_overlay: ColorRect
var _upgrade_row: HBoxContainer
var _restart_button: Button
var _hand_signature := ""
var _upgrade_signature := ""


func _ready() -> void:
	_hide_template_nodes()
	_build_top_hud()
	_build_hand_area()
	_build_upgrade_overlay()
	_build_restart_button()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	PrototypeState.status_changed.connect(_on_status_changed)
	_apply_responsive_layout.call_deferred()


func set_battle_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	_refresh_top_hud()
	_refresh_hand_area()
	_refresh_upgrade_overlay()
	_refresh_restart()
	_apply_responsive_layout()


func set_gameplay_mode(_enabled: bool) -> void:
	_apply_responsive_layout()


func set_hud_text(_objective: String, _status: String, _hint: String, _message: String = "", _bottom: String = "") -> void:
	_refresh_top_hud()


func _hide_template_nodes() -> void:
	message_panel.visible = false
	objective_label.visible = false
	status_label.visible = false
	hint_label.visible = false
	bottom_hint_label.visible = false


func _build_top_hud() -> void:
	_top_hud = VBoxContainer.new()
	_top_hud.name = "BattleTopHud"
	_top_hud.anchor_left = 0.0
	_top_hud.anchor_top = 0.0
	_top_hud.anchor_right = 1.0
	_top_hud.anchor_bottom = 0.0
	_top_hud.offset_left = 16.0
	_top_hud.offset_top = 12.0
	_top_hud.offset_right = -16.0
	_top_hud.offset_bottom = 176.0
	_top_hud.add_theme_constant_override("separation", 8)
	root.add_child(_top_hud)

	_resource_label = _make_label(20, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_top_hud.add_child(_resource_label)

	_wall_bar = _make_bar(Color(0.22, 0.92, 0.48), "城墙")
	_energy_bar = _make_bar(Color(0.28, 0.66, 1.0), "能量")
	_exp_bar = _make_bar(Color(0.92, 0.62, 1.0), "经验")
	_top_hud.add_child(_wall_bar)
	_top_hud.add_child(_energy_bar)
	_top_hud.add_child(_exp_bar)

	var pile_row := HBoxContainer.new()
	pile_row.add_theme_constant_override("separation", 10)
	_top_hud.add_child(pile_row)
	_deck_label = _make_pile_badge("牌库 0")
	_discard_label = _make_pile_badge("弃牌 0")
	pile_row.add_child(_deck_label)
	pile_row.add_child(_discard_label)


func _build_hand_area() -> void:
	_hand_panel = PanelContainer.new()
	_hand_panel.name = "CardHandPanel"
	_hand_panel.anchor_left = 0.0
	_hand_panel.anchor_top = 1.0
	_hand_panel.anchor_right = 1.0
	_hand_panel.anchor_bottom = 1.0
	_hand_panel.offset_left = 12.0
	_hand_panel.offset_right = -12.0
	_hand_panel.offset_top = -265.0
	_hand_panel.offset_bottom = -12.0
	_hand_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.058, 0.076, 0.92), Color(0.34, 0.58, 0.70, 0.76), 18))
	root.add_child(_hand_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_hand_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := _make_label(18, Color(0.86, 0.95, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
	title.text = "手牌区"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_discard_button = Button.new()
	_discard_button.custom_minimum_size = Vector2(132.0, 48.0)
	_discard_button.pressed.connect(func(): PrototypeState.discard_hand())
	_style_button(_discard_button, Color(0.18, 0.25, 0.31), 16)
	title_row.add_child(_discard_button)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 10)
	layout.add_child(_hand_row)


func _build_upgrade_overlay() -> void:
	_upgrade_overlay = ColorRect.new()
	_upgrade_overlay.name = "UpgradeChoiceOverlay"
	_upgrade_overlay.anchor_right = 1.0
	_upgrade_overlay.anchor_bottom = 1.0
	_upgrade_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_upgrade_overlay)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_upgrade_overlay.add_child(center)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	center.add_child(layout)

	var title := _make_label(32, Color(1.0, 0.92, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "升级三选一"
	layout.add_child(title)

	_upgrade_row = HBoxContainer.new()
	_upgrade_row.add_theme_constant_override("separation", 18)
	layout.add_child(_upgrade_row)
	_upgrade_overlay.visible = false


func _build_restart_button() -> void:
	_restart_button = Button.new()
	_restart_button.anchor_left = 0.5
	_restart_button.anchor_top = 0.5
	_restart_button.anchor_right = 0.5
	_restart_button.anchor_bottom = 0.5
	_restart_button.offset_left = -120.0
	_restart_button.offset_top = 110.0
	_restart_button.offset_right = 120.0
	_restart_button.offset_bottom = 176.0
	_restart_button.text = "重新开始"
	_restart_button.pressed.connect(func(): PrototypeState.reset())
	_style_button(_restart_button, Color(0.34, 0.16, 0.12), 22)
	root.add_child(_restart_button)
	_restart_button.visible = false


func _refresh_top_hud() -> void:
	var time_left := int(_snapshot.get("remaining_time", 0.0))
	var compact := _get_display_width() <= 700.0
	if compact:
		_resource_label.text = (
			"防线 %02d:%02d  Lv.%d  %dx  K%d"
			% [
				time_left / 60,
				time_left % 60,
				int(_snapshot.get("level", 1)),
				int(_snapshot.get("chain", 1)),
				int(_snapshot.get("kills", 0))
			]
		)
	else:
		_resource_label.text = (
			"守住防线  %02d:%02d    Lv.%d    连锁 %dx    击杀 %d"
			% [
				time_left / 60,
				time_left % 60,
				int(_snapshot.get("level", 1)),
				int(_snapshot.get("chain", 1)),
				int(_snapshot.get("kills", 0)),
			]
		)
	_set_bar(_wall_bar, float(_snapshot.get("wall_hp", 0.0)), float(_snapshot.get("wall_max_hp", 1000.0)), "城墙")
	_set_bar(_energy_bar, float(_snapshot.get("energy", 0.0)), float(_snapshot.get("max_energy", 3)), "主角能量")
	_set_bar(_exp_bar, float(_snapshot.get("exp", 0.0)), float(_snapshot.get("exp_to_next", 10.0)), "经验")
	_deck_label.text = "牌库 %d" % int(_snapshot.get("deck_count", 0))
	_discard_label.text = "弃牌堆 %d" % int(_snapshot.get("discard_count", 0))


func _refresh_hand_area() -> void:
	var phase := int(_snapshot.get("phase", PrototypeState.Phase.PLAYING))
	var hand: Array = _snapshot.get("hand", [])
	var signature := _cards_signature(hand)
	if signature != _hand_signature:
		_hand_signature = signature
		for child in _hand_row.get_children():
			child.queue_free()
		for i in hand.size():
			var card: Dictionary = hand[i]
			var button := Button.new()
			button.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.text = "%s\n%d 费\n%s" % [String(card.get("name", "卡牌")), int(card.get("cost", 0)), String(card.get("text", ""))]
			button.pressed.connect(func(index := i): PrototypeState.try_play_hand(index))
			_style_button(button, _skill_color(String(card.get("skill", ""))), 15)
			_hand_row.add_child(button)
	for i in mini(hand.size(), _hand_row.get_child_count()):
		var card: Dictionary = hand[i]
		var button := _hand_row.get_child(i) as Button
		button.disabled = phase != PrototypeState.Phase.PLAYING or float(_snapshot.get("energy", 0.0)) + 0.001 < float(card.get("cost", 0))
	var discard_cd := float(_snapshot.get("discard_cd", 0.0))
	_discard_button.disabled = phase != PrototypeState.Phase.PLAYING or discard_cd > 0.0
	_discard_button.text = "弃牌 %.0fs" % discard_cd if discard_cd > 0.0 else "弃牌重抽"
	_hand_panel.visible = phase == PrototypeState.Phase.PLAYING


func _refresh_upgrade_overlay() -> void:
	var phase := int(_snapshot.get("phase", PrototypeState.Phase.PLAYING))
	_upgrade_overlay.visible = phase == PrototypeState.Phase.UPGRADE
	if not _upgrade_overlay.visible:
		_upgrade_signature = ""
		return
	var choices: Array = _snapshot.get("upgrade_choices", [])
	var signature := _cards_signature(choices)
	if signature == _upgrade_signature:
		return
	_upgrade_signature = signature
	for child in _upgrade_row.get_children():
		child.queue_free()
	for i in choices.size():
		var upgrade: Dictionary = choices[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(UPGRADE_CARD_WIDTH, UPGRADE_CARD_HEIGHT)
		card.text = "%s\n\n%s\n\n点击选择" % [String(upgrade.get("name", "强化")), String(upgrade.get("text", ""))]
		card.pressed.connect(func(index := i): PrototypeState.choose_upgrade(index))
		_style_button(card, Color(0.20, 0.16, 0.42), 22)
		_upgrade_row.add_child(card)
	if _upgrade_row.get_child_count() > 0:
		(_upgrade_row.get_child(0) as Button).grab_focus()


func _refresh_restart() -> void:
	var phase := int(_snapshot.get("phase", PrototypeState.Phase.PLAYING))
	_restart_button.visible = phase in [PrototypeState.Phase.WON, PrototypeState.Phase.LOST]
	if phase == PrototypeState.Phase.WON:
		_restart_button.text = "胜利！重新开始"
	elif phase == PrototypeState.Phase.LOST:
		_restart_button.text = "失败，重新开始"


func _make_bar(fill_color: Color, title: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 28.0)
	bar.show_percentage = false
	bar.tooltip_text = title
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.02, 0.025, 0.032, 0.95), Color(0.18, 0.26, 0.30), 8))
	bar.add_theme_stylebox_override("fill", _panel_style(fill_color, fill_color.lightened(0.25), 8))
	return bar


func _set_bar(bar: ProgressBar, value: float, max_value: float, title: String) -> void:
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.tooltip_text = "%s %.0f/%.0f" % [title, value, max_value]


func _make_label(font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _make_pile_badge(text: String) -> Label:
	var label := _make_label(18, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _cards_signature(items: Array) -> String:
	var parts: Array[String] = []
	for item in items:
		if item is Dictionary:
			parts.append(String(item.get("id", item.get("name", ""))))
	return "|".join(parts)


func _style_button(button: Button, color: Color, font_size: int) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(color.r, color.g, color.b, 0.96), color.lightened(0.45), 16))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), Color(1.0, 0.95, 0.72), 16))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.1), Color(1.0, 0.86, 0.35), 16))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.10, 0.11, 0.12, 0.82), Color(0.20, 0.22, 0.24), 16))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.56))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	button.add_theme_constant_override("outline_size", 3)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style


func _on_status_changed(_status: String) -> void:
	_refresh_top_hud()


func _apply_responsive_layout() -> void:
	var width := _get_display_width()
	var compact := width <= 700.0
	if top_bar != null:
		top_bar.columns = 1 if compact else 2
	if _hand_panel != null:
		_hand_panel.offset_top = -310.0 if compact else -265.0
	if _upgrade_row != null:
		_upgrade_row.add_theme_constant_override("separation", 10 if compact else 18)
		for child in _upgrade_row.get_children():
			(child as Control).custom_minimum_size = Vector2(210.0 if compact else UPGRADE_CARD_WIDTH, UPGRADE_CARD_HEIGHT)


func _get_display_width() -> float:
	var visible_width := get_viewport().get_visible_rect().size.x
	var window_width := float(get_window().size.x)
	return minf(visible_width, window_width) if window_width > 0.0 else visible_width


func _skill_color(skill: String) -> Color:
	match skill:
		"thermobaric":
			return Color(0.48, 0.14, 0.08)
		"dry_ice":
			return Color(0.06, 0.26, 0.42)
		"electro_pierce":
			return Color(0.22, 0.12, 0.46)
	return Color(0.16, 0.20, 0.25)
