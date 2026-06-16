extends CanvasLayer

const MESSAGE_WIDTH_RATIO := 0.86
const COMPACT_WIDTH := 340.0
const HAND_CARD_SIZE := Vector2(150.0, 255.0)
const HAND_CARD_SAFE_SIDE := 82.0
const HAND_CARD_TOP := 122.0
const HAND_CARD_EDGE_DROP := 24.0
const HAND_CARD_MAX_ROTATION := 0.19
const HAND_CARD_MIN_ROTATION := 0.045
const HAND_CARD_BASE_SCALE := 1.15
const HAND_CARD_DENSE_SCALE := 0.96
const HAND_CARD_OVERFLOW_SCALE := 0.86
const DEFAULT_STAGE := "5-1 教堂广场"
const DEFAULT_CARDS := [
	{
		"cost": 1,
		"name": "冰霜弹",
		"type": "攻击",
		"desc": "造成伤害并冻结。",
		"art": "?",
	},
	{
		"cost": 2,
		"name": "穿透弹",
		"type": "攻击",
		"desc": "对直线敌人穿透。",
		"art": "?",
	},
	{
		"cost": 1,
		"name": "维修机",
		"type": "技能",
		"desc": "修复城墙耐久。",
		"art": "+",
	},
	{
		"cost": 3,
		"name": "落雷",
		"type": "范围",
		"desc": "指定区域高频伤害。",
		"art": "?",
	},
	{
		"cost": 2,
		"name": "防线护盾",
		"type": "防御",
		"desc": "生成临时护盾。",
		"art": "?",
	},
]

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
@onready var status_label: Label = %StatusLabel
@onready var targeting_hint_label: Label = %TargetingHintLabel
@onready var ammo_value_label: Label = %AmmoValueLabel
@onready var wall_hp_bar: ProgressBar = %WallHpBar
@onready var wall_hp_icon_label: Label = %WallHpIconLabel
@onready var wall_hp_value_label: Label = %WallHpValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var hero_name_label: Label = %HeroNameLabel
@onready var ultimate_cost_label: Label = %UltimateCostLabel
@onready var ultimate_bar: ProgressBar = %UltimateBar
@onready var hint_label: Label = %HintLabel
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var draw_pile_button: Button = %DrawPileButton
@onready var bottom_toast_label: Label = %BottomToastLabel
@onready var hand_layer: Control = $Root/SafeMargin/MainLayout/HandArea/HandAreaRoot/HandLayer
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_panel: PanelContainer = %PausePanel
@onready var pause_title_label: Label = %PauseTitleLabel
@onready var pause_summary_label: Label = %PauseSummaryLabel
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var card_widgets := [
	{
		"panel": %Card1,
		"cost": %Card1CostLabel,
		"art": %Card1ArtLabel,
		"name": %Card1NameLabel,
		"type": %Card1TypeLabel,
		"desc": %Card1DescLabel,
		"school": %Card1SchoolIconLabel,
	},
	{
		"panel": %Card2,
		"cost": %Card2CostLabel,
		"art": %Card2ArtLabel,
		"name": %Card2NameLabel,
		"type": %Card2TypeLabel,
		"desc": %Card2DescLabel,
		"school": %Card2SchoolIconLabel,
	},
	{
		"panel": %Card3,
		"cost": %Card3CostLabel,
		"art": %Card3ArtLabel,
		"name": %Card3NameLabel,
		"type": %Card3TypeLabel,
		"desc": %Card3DescLabel,
		"school": %Card3SchoolIconLabel,
	},
	{
		"panel": %Card4,
		"cost": %Card4CostLabel,
		"art": %Card4ArtLabel,
		"name": %Card4NameLabel,
		"type": %Card4TypeLabel,
		"desc": %Card4DescLabel,
		"school": %Card4SchoolIconLabel,
	},
	{
		"panel": %Card5,
		"cost": %Card5CostLabel,
		"art": %Card5ArtLabel,
		"name": %Card5NameLabel,
		"type": %Card5TypeLabel,
		"desc": %Card5DescLabel,
		"school": %Card5SchoolIconLabel,
	},
]

var _snapshot: Dictionary = {}
var _layout_width := 0.0
var _gameplay_mode := true


func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.pressed.connect(_on_pause_pressed)
	continue_button.pressed.connect(_close_pause_overlay)
	restart_button.pressed.connect(_on_restart_pressed)
	discard_pile_button.pressed.connect(_on_discard_pile_pressed)
	draw_pile_button.pressed.connect(_on_draw_pile_pressed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_styles()
	_apply_responsive_layout()
	if not PrototypeState.state_changed.is_connected(set_battle_snapshot):
		PrototypeState.state_changed.connect(set_battle_snapshot)
	set_battle_snapshot(PrototypeState.get_snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if pause_overlay.visible:
		_close_pause_overlay()
	else:
		_open_pause_overlay()
	get_viewport().set_input_as_handled()


func set_battle_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	var elapsed: float = float(snapshot.get("elapsed_time", 21.0))
	var wave_current: int = int(snapshot.get("wave_current", 1))
	var wave_total: int = int(snapshot.get("wave_total", 20))
	var level: int = int(snapshot.get("level", 1))
	var exp: int = int(snapshot.get("exp", 60))
	var exp_max: int = maxi(1, int(snapshot.get("exp_max", 60)))
	var wall_hp: int = int(snapshot.get("wall_hp", snapshot.get("hp", 3000)))
	var wall_hp_max: int = maxi(1, int(snapshot.get("wall_hp_max", 3000)))
	var energy: int = int(snapshot.get("energy", 3))
	var energy_max: int = maxi(1, int(snapshot.get("energy_max", 3)))
	var ammo: int = int(snapshot.get("ammo", 75))
	var ammo_max: int = maxi(1, int(snapshot.get("ammo_max", 75)))

	time_label.text = _format_time(elapsed)
	stage_label.text = _fit_text(String(snapshot.get("stage_name", DEFAULT_STAGE)), 18)
	wave_label.text = "波次: %d/%d" % [wave_current, wave_total]
	level_value_label.text = "%d级" % level
	exp_value_label.text = "%d/%d" % [exp, exp_max]
	_set_progress(exp_bar, exp, exp_max)
	objective_label.text = _clean_label_prefix(_fit_text(String(snapshot.get("objective", "守住城墙")), 30))
	objective_panel.visible = false
	status_label.text = ""
	targeting_hint_label.text = _fit_text(String(snapshot.get("targeting_hint", "推荐落点")), 16)
	ammo_value_label.text = "%d/%d" % [ammo, ammo_max]
	wall_hp_value_label.text = "%d" % wall_hp
	_set_progress(wall_hp_bar, wall_hp, wall_hp_max)
	energy_value_label.text = "%d/%d" % [energy, energy_max]
	hero_name_label.text = _fit_text(String(snapshot.get("hero_name", "艾琳")), 14)
	ultimate_cost_label.text = str(energy)
	_set_progress(ultimate_bar, energy, 10.0)
	hint_label.text = ""
	_update_cards(snapshot, energy)
	_update_piles(snapshot)
	_apply_gameplay_mode()


func set_gameplay_mode(enabled: bool) -> void:
	_gameplay_mode = enabled
	_apply_gameplay_mode()


func _apply_styles() -> void:
	var metal_panel := Color(0.115, 0.105, 0.085, 0.94)
	var metal_border := Color(0.545, 0.440, 0.250, 0.86)
	var blue_text := Color(0.82, 0.93, 1.0)
	var warm_text := Color(1.0, 0.88, 0.58)
	var plain_text := Color(0.92, 0.90, 0.84)

	for panel in [
		%ObjectivePanel,
		%AmmoPanel,
		%DefenseWallPanel,
		%WallHpPanel,
		%HeroStatusPanel,
		%EnergyBadge,
		%HeroPortraitPanel,
		%UltimateCostBadge,
		%HandArea,
		pause_panel,
	]:
		(panel as PanelContainer).add_theme_stylebox_override("panel", _panel_style(metal_panel, metal_border, 8))

	for panel in [%TimePanel, %StagePanel, %WavePanel]:
		(panel as PanelContainer).add_theme_stylebox_override("panel", _plain_panel_style(Color(0.0, 0.0, 0.0, 0.16), 0))
	%ExpPanel.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.0, 0.0, 0.0, 0.22), 0))
	%AmmoPanel.add_theme_stylebox_override(
		"panel", _compact_panel_style(Color(0.055, 0.075, 0.080, 0.92), Color(0.74, 0.46, 0.20, 0.92), 3, 1)
	)
	%DefenseWallPanel.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))
	%WallHpPanel.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.04, 0.04, 0.035, 0.36), 0))
	%HeroStatusPanel.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))
	%HandArea.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.035, 0.032, 0.026, 0.82), 4))
	%EnergyBadge.add_theme_stylebox_override("panel", _panel_style(Color(0.050, 0.075, 0.090, 0.96), Color(0.36, 0.66, 0.92, 0.88), 32))
	%UltimateCostBadge.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.72, 0.08, 0.70, 0.98), Color(0.06, 0.03, 0.12, 0.98), 30, 3)
	)
	%HeroPortraitPanel.add_theme_stylebox_override("panel", _plain_panel_style(Color(0.0, 0.0, 0.0, 0.0), 0))

	for label in _all_labels():
		label.add_theme_color_override("font_color", plain_text)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.70))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_font_size_override("font_size", 23)

	for label in [stage_label, pause_title_label, energy_value_label]:
		label.add_theme_color_override("font_color", warm_text)
		label.add_theme_font_size_override("font_size", 34)

	for label in [time_label, stage_label, wave_label, level_value_label]:
		label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 3)
		label.add_theme_constant_override("shadow_offset_y", 3)
	time_label.add_theme_font_size_override("font_size", 25)
	stage_label.add_theme_font_size_override("font_size", 34)
	wave_label.add_theme_font_size_override("font_size", 25)
	level_title_label.add_theme_font_size_override("font_size", 22)
	level_value_label.add_theme_font_size_override("font_size", 20)
	exp_value_label.add_theme_font_size_override("font_size", 22)
	ammo_value_label.add_theme_font_size_override("font_size", 28)
	ammo_value_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	hero_name_label.add_theme_font_size_override("font_size", 29)
	ultimate_cost_label.add_theme_font_size_override("font_size", 32)
	ultimate_cost_label.add_theme_color_override("font_color", Color(0.98, 0.92, 1.0))
	hint_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_font_size_override("font_size", 19)
	targeting_hint_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.72))
	targeting_hint_label.add_theme_font_size_override("font_size", 20)
	bottom_toast_label.add_theme_font_size_override("font_size", 18)
	bottom_toast_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.96))
	energy_value_label.add_theme_color_override("font_color", Color(0.42, 0.84, 1.0))
	wall_hp_icon_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.32))
	wall_hp_icon_label.add_theme_font_size_override("font_size", 26)
	objective_label.add_theme_color_override("font_color", blue_text)

	_style_button(pause_button, "pause")
	_style_button(discard_pile_button, "pile")
	_style_button(draw_pile_button, "pile")
	_style_button(continue_button, "menu")
	_style_button(restart_button, "menu")
	_style_progress(exp_bar, Color(0.20, 0.55, 0.95), Color(0.05, 0.08, 0.12))
	_style_progress(wall_hp_bar, Color(0.08, 0.78, 0.16), Color(0.08, 0.13, 0.08))
	_style_progress(ultimate_bar, Color(0.95, 0.12, 0.82), Color(0.08, 0.10, 0.25))
	_style_cards()


func _apply_responsive_layout() -> void:
	var compact := _get_display_width() <= COMPACT_WIDTH
	top_bar.columns = 1 if compact else 4
	safe_margin.add_theme_constant_override("margin_left", 8 if compact else 10)
	safe_margin.add_theme_constant_override("margin_right", 8 if compact else 10)
	pause_panel.custom_minimum_size.x = minf(360.0, _get_display_width() * MESSAGE_WIDTH_RATIO)
	_layout_hand_cards(_current_hand_count())


func _apply_gameplay_mode() -> void:
	targeting_hint_label.visible = _gameplay_mode
	status_label.visible = false
	hint_label.visible = false
	bottom_toast_label.visible = false


func _update_cards(snapshot: Dictionary, energy: int) -> void:
	var cards_variant: Variant = snapshot.get("hand_cards", DEFAULT_CARDS)
	var cards: Array = cards_variant if cards_variant is Array else DEFAULT_CARDS
	_ensure_card_widget_count(cards.size())
	for index in range(card_widgets.size()):
		var widget: Dictionary = card_widgets[index]
		var is_visible := index < cards.size()
		(widget["panel"] as PanelContainer).visible = is_visible
		if not is_visible:
			continue
		var card: Dictionary = cards[index] if cards[index] is Dictionary else DEFAULT_CARDS[index % DEFAULT_CARDS.size()]
		var cost: int = int(card.get("cost", 0))
		var usable: bool = energy >= cost
		(widget["cost"] as Label).text = str(cost)
		(widget["art"] as Label).text = String(card.get("art_slot", "卡牌图片\n资源槽"))
		(widget["type"] as Label).text = _fit_text(String(card.get("name", "Card")), 7)
		(widget["name"] as Label).text = ""
		(widget["desc"] as Label).text = _fit_text(String(card.get("desc", "Ready.")), 22)
		(widget["school"] as Label).text = _fit_text(String(card.get("school", _school_name(index))), 5)
		(widget["panel"] as PanelContainer).modulate = Color(1, 1, 1, 1) if usable else Color(0.55, 0.58, 0.62, 0.86)
		(widget["cost"] as Label).add_theme_color_override("font_color", Color(0.48, 0.84, 1.0) if usable else Color(1.0, 0.34, 0.24))
	_layout_hand_cards(cards.size())


func _update_piles(snapshot: Dictionary) -> void:
	var discard_count := int(snapshot.get("discard_count", 8))
	var draw_count := int(snapshot.get("draw_count", 18))
	discard_pile_button.text = "弃牌\n%d" % discard_count
	draw_pile_button.text = "牌堆\n%d" % draw_count


func _set_progress(bar: ProgressBar, value: float, max_value: float) -> void:
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)


func _on_pause_pressed() -> void:
	_open_pause_overlay()


func _open_pause_overlay() -> void:
	pause_overlay.visible = true
	continue_button.grab_focus()


func _close_pause_overlay() -> void:
	pause_overlay.visible = false
	pause_button.grab_focus()


func _on_restart_pressed() -> void:
	_close_pause_overlay()
	PrototypeState.reset()


func _on_discard_pile_pressed() -> void:
	pass


func _on_draw_pile_pressed() -> void:
	pass


func _style_cards() -> void:
	for widget in card_widgets:
		_style_card_widget(widget)


func _style_card_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _card_frame_style())
	for key in ["cost", "art", "name", "type", "desc", "school"]:
		var label: Label = widget[key] as Label
		label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.60))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.clip_text = true
	_layout_card_readability_regions(widget)
	(widget["cost"] as Label).add_theme_font_size_override("font_size", 26)
	(widget["cost"] as Label).add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	(widget["cost"] as Label).add_theme_color_override("font_outline_color", Color(0.025, 0.05, 0.10, 0.95))
	(widget["cost"] as Label).add_theme_constant_override("outline_size", 2)
	(widget["cost"] as Label).add_theme_stylebox_override(
		"normal", _panel_style(Color(0.04, 0.24, 0.48, 0.99), Color(0.88, 0.75, 0.38, 0.98), 25, 3)
	)
	(widget["art"] as Label).add_theme_font_size_override("font_size", 15)
	(widget["art"] as Label).add_theme_color_override("font_color", Color(0.60, 0.76, 0.84, 0.82))
	(widget["art"] as Label).add_theme_constant_override("outline_size", 0)
	(widget["art"] as Label).add_theme_stylebox_override(
		"normal", _panel_style(Color(0.035, 0.095, 0.125, 0.96), Color(0.18, 0.36, 0.45, 0.78), 3, 1)
	)
	(widget["name"] as Label).add_theme_font_size_override("font_size", 15)
	(widget["name"] as Label).add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	(widget["type"] as Label).add_theme_font_size_override("font_size", 20)
	(widget["type"] as Label).add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	(widget["type"] as Label).add_theme_color_override("font_outline_color", Color(0.10, 0.025, 0.018, 0.96))
	(widget["type"] as Label).add_theme_constant_override("outline_size", 2)
	(widget["type"] as Label).add_theme_stylebox_override(
		"normal", _panel_style(Color(0.38, 0.055, 0.035, 0.98), Color(0.78, 0.58, 0.30, 0.95), 4, 2)
	)
	(widget["desc"] as Label).add_theme_font_size_override("font_size", 15)
	(widget["desc"] as Label).add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	(widget["desc"] as Label).add_theme_color_override("font_outline_color", Color(0.04, 0.035, 0.03, 0.94))
	(widget["desc"] as Label).add_theme_constant_override("outline_size", 1)
	(widget["desc"] as Label).add_theme_stylebox_override(
		"normal", _panel_style(Color(0.16, 0.15, 0.20, 0.95), Color(0.58, 0.46, 0.28, 0.82), 4, 1)
	)
	(widget["school"] as Label).add_theme_font_size_override("font_size", 13)
	(widget["school"] as Label).add_theme_color_override("font_color", Color(0.10, 0.075, 0.04))
	(widget["school"] as Label).add_theme_constant_override("outline_size", 0)
	(widget["school"] as Label).add_theme_stylebox_override(
		"normal", _panel_style(Color(0.86, 0.69, 0.40, 0.98), Color(0.32, 0.22, 0.12, 0.98), 8, 1)
	)


func _layout_card_readability_regions(widget: Dictionary) -> void:
	var cost: Label = widget["cost"] as Label
	cost.position = Vector2(4.0, 4.0)
	cost.size = Vector2(38.0, 38.0)
	cost.z_index = 0
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var name: Label = widget["name"] as Label
	name.visible = false
	name.position = Vector2(45.0, 42.0)
	name.size = Vector2(96.0, 18.0)
	name.z_index = 0
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var type_label: Label = widget["type"] as Label
	type_label.position = Vector2(25.0, 8.0)
	type_label.size = Vector2(119.0, 34.0)
	type_label.z_index = 0
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var art: Label = widget["art"] as Label
	art.position = Vector2(15.0, 58.0)
	art.size = Vector2(120.0, 84.0)
	art.z_index = 0
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var desc: Label = widget["desc"] as Label
	desc.position = Vector2(12.0, 154.0)
	desc.size = Vector2(126.0, 66.0)
	desc.z_index = 0
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var school: Label = widget["school"] as Label
	school.position = Vector2(38.0, 224.0)
	school.size = Vector2(74.0, 24.0)
	school.z_index = 0
	school.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	school.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _ensure_card_widget_count(count: int) -> void:
	while card_widgets.size() < count:
		var source_panel: PanelContainer = card_widgets[0]["panel"] as PanelContainer
		var panel := source_panel.duplicate() as PanelContainer
		_clear_unique_names(panel)
		panel.name = "Card%d" % (card_widgets.size() + 1)
		hand_layer.add_child(panel)
		var widget := _card_widget_from_panel(panel)
		card_widgets.append(widget)
		_style_card_widget(widget)


func _card_widget_from_panel(panel: PanelContainer) -> Dictionary:
	return {
		"panel": panel,
		"cost": _find_label_by_suffix(panel, "CostLabel"),
		"art": _find_label_by_suffix(panel, "ArtLabel"),
		"name": _find_label_by_suffix(panel, "NameLabel"),
		"type": _find_label_by_suffix(panel, "TypeLabel"),
		"desc": _find_label_by_suffix(panel, "DescLabel"),
		"school": _find_label_by_suffix(panel, "SchoolIconLabel"),
	}


func _find_label_by_suffix(node: Node, suffix: String) -> Label:
	for child in node.get_children():
		if child is Label and String(child.name).ends_with(suffix):
			return child as Label
		var found := _find_label_by_suffix(child, suffix)
		if found != null:
			return found
	return null


func _clear_unique_names(node: Node) -> void:
	node.unique_name_in_owner = false
	for child in node.get_children():
		_clear_unique_names(child)


func _layout_hand_cards(visible_count: int) -> void:
	if visible_count <= 0:
		return
	var hand_width := hand_layer.size.x
	if hand_width <= 0.0:
		hand_width = 1080.0
	var count_pressure := clampf(float(visible_count - 5) / 7.0, 0.0, 1.0)
	var overflow_pressure := clampf(float(visible_count - 10) / 4.0, 0.0, 1.0)
	var card_scale := lerpf(lerpf(HAND_CARD_BASE_SCALE, HAND_CARD_DENSE_SCALE, count_pressure), HAND_CARD_OVERFLOW_SCALE, overflow_pressure)
	var scaled_card_size := HAND_CARD_SIZE * card_scale
	var center_min := HAND_CARD_SAFE_SIDE + scaled_card_size.x * 0.5
	var center_max := maxf(center_min, hand_width - HAND_CARD_SAFE_SIDE - scaled_card_size.x * 0.5)
	var available_span := center_max - center_min
	var overlap_spacing_ratio := _hand_overlap_spacing_ratio(visible_count)
	var desired_span := scaled_card_size.x * overlap_spacing_ratio * float(maxi(0, visible_count - 1))
	var center_span := minf(available_span, desired_span)
	center_min = hand_width * 0.5 - center_span * 0.5
	var max_rotation := lerpf(HAND_CARD_MAX_ROTATION, HAND_CARD_MIN_ROTATION, count_pressure)
	var edge_drop := lerpf(HAND_CARD_EDGE_DROP, 12.0, count_pressure)
	var top_y := HAND_CARD_TOP + lerpf(0.0, 24.0, count_pressure)

	for index in range(card_widgets.size()):
		var panel: PanelContainer = card_widgets[index]["panel"] as PanelContainer
		if index >= visible_count:
			panel.visible = false
			continue
		var ratio := 0.5
		if visible_count > 1:
			ratio = float(index) / float(visible_count - 1)
		var signed := ratio * 2.0 - 1.0
		var center_x := center_min + center_span * ratio
		var top_offset := top_y + absf(signed) * edge_drop
		panel.visible = true
		panel.size = HAND_CARD_SIZE
		panel.scale = Vector2(card_scale, card_scale)
		panel.pivot_offset = HAND_CARD_SIZE * 0.5
		panel.position = Vector2(center_x - HAND_CARD_SIZE.x * 0.5, top_offset)
		panel.rotation = signed * max_rotation
		panel.z_index = 100 + index


func _hand_overlap_spacing_ratio(visible_count: int) -> float:
	if visible_count <= 1:
		return 0.0
	if visible_count <= 3:
		return 0.72
	if visible_count == 4:
		return 0.62
	if visible_count == 5:
		return 0.56
	return maxf(0.38, 0.48 - float(visible_count - 6) * 0.025)


func _current_hand_count() -> int:
	if _snapshot.is_empty():
		return DEFAULT_CARDS.size()
	var cards_variant: Variant = _snapshot.get("hand_cards", DEFAULT_CARDS)
	if cards_variant is Array:
		return (cards_variant as Array).size()
	return DEFAULT_CARDS.size()


func _school_name(index: int) -> String:
	var names := ["冰霜", "穿透", "维修", "落雷", "防线"]
	return names[index % names.size()]


func _style_button(button: Button, kind: String) -> void:
	var bg := Color(0.105, 0.095, 0.078, 0.96)
	var border := Color(0.56, 0.46, 0.27, 0.92)
	if kind == "pause":
		bg = Color(0.090, 0.082, 0.068, 0.98)
	if kind == "menu":
		bg = Color(0.145, 0.132, 0.102, 0.98)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, 7))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.10), border.lightened(0.12), 7))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), border, 7))
	button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
	button.add_theme_font_size_override("font_size", 24)


func _style_progress(bar: ProgressBar, fill: Color, background: Color) -> void:
	bar.add_theme_stylebox_override("background", _panel_style(background, Color(0.30, 0.26, 0.18, 0.92), 5, 1))
	bar.add_theme_stylebox_override("fill", _panel_style(fill, fill.lightened(0.10), 5, 1))


func _panel_style(bg: Color, border: Color, radius: int, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _card_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.064, 0.052, 0.99)
	style.border_color = Color(0.78, 0.60, 0.30, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0.0, 5.0)
	return style


func _plain_panel_style(bg: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _compact_panel_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := _panel_style(bg, border, radius, border_width)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


func _all_labels() -> Array:
	return [
		time_label,
		stage_label,
		wave_label,
		level_title_label,
		level_value_label,
		exp_value_label,
		objective_label,
		status_label,
		targeting_hint_label,
		ammo_value_label,
		%DefenseWallLabel,
		%WallHpTitleLabel,
		wall_hp_icon_label,
		wall_hp_value_label,
		%EnergyTitleLabel,
		energy_value_label,
		%HeroPortraitLabel,
		hero_name_label,
		ultimate_cost_label,
		%UltimateTitleLabel,
		hint_label,
		bottom_toast_label,
		pause_title_label,
		pause_summary_label,
	]


func _get_display_width() -> float:
	var visible_width := get_viewport().get_visible_rect().size.x
	_layout_width = visible_width
	return _layout_width


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [floori(float(total) / 60.0), total % 60]


func _fit_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.left(maxi(1, max_chars - 3)) + "..."


func _school_icon(index: int) -> String:
	var icons := ["❄", "✦", "⚙", "◇", "◆"]
	return icons[index % icons.size()]


func _clean_label_prefix(text: String) -> String:
	for prefix in ["目标：", "目标:"]:
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return text
