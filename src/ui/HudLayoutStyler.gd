extends RefCounted
class_name HudLayoutStyler

const HUD_CARD_WIDGETS := preload("res://src/ui/HudCardWidgets.gd")
const HUD_LAYOUT_STYLE_APPLIER := preload("res://src/ui/HudLayoutStyleApplier.gd")

var hud: Node = null
var message_width_ratio := 0.86
var compact_width := 340.0
var ultimate_limit_segments := 10
var limit_lock_icon_path := ""


func setup(owner: Node, width_ratio: float, compact_threshold: float, lock_segments: int, lock_icon_path: String) -> void:
	hud = owner
	message_width_ratio = width_ratio
	compact_width = compact_threshold
	ultimate_limit_segments = lock_segments
	limit_lock_icon_path = lock_icon_path


func apply_styles() -> void:
	HUD_LAYOUT_STYLE_APPLIER.apply(hud)


func apply_responsive_layout() -> void:
	var viewport_size := hud.get_viewport().get_visible_rect().size
	var layout_width := viewport_size.x
	hud.set("_layout_width", layout_width)
	var compact := layout_width <= compact_width
	(_prop("hand_area") as PanelContainer).custom_minimum_size.y = 420.0
	(_prop("top_bar") as GridContainer).columns = 1 if compact else 4
	(_prop("safe_margin") as MarginContainer).add_theme_constant_override("margin_left", 8 if compact else 10)
	(_prop("safe_margin") as MarginContainer).add_theme_constant_override("margin_right", 8 if compact else 10)
	(_prop("main_menu_panel") as PanelContainer).custom_minimum_size.x = minf(520.0, layout_width * message_width_ratio)
	_layout_pause_overlay(viewport_size)
	var wall_hp_bar := _prop("wall_hp_bar") as ProgressBar
	var wall_hp_row := wall_hp_bar.get_parent() as HBoxContainer
	wall_hp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wall_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wall_hp_bar.custom_minimum_size.x = clampf(layout_width * 0.46, 360.0, 520.0)
	(_prop("result_overlay") as HudResultOverlay).layout(viewport_size)
	(_prop("reward_overlay") as HudRewardOverlay).layout(viewport_size, compact_width)
	(_prop("pile_overlay_controller") as HudPileOverlayController).layout(viewport_size)
	hud.call("_style_cards")
	lock_ultimate_meter_layout()
	hud.call("_layout_hand_cards", hud.call("_current_hand_count"))
	var snapshot := hud.get("_snapshot") as Dictionary
	if not snapshot.is_empty():
		update_ultimate_limit_lock(maxi(1, int(snapshot.get("energy_max", 3))))


func _layout_pause_overlay(viewport_size: Vector2) -> void:
	var pause_panel := _prop("pause_panel") as Control
	var title_label := _prop("pause_title_label") as Label
	var summary_label := _prop("pause_summary_label") as Label
	var reward_spacer := _prop("pause_reward_spacer") as Control
	var actions := _prop("pause_actions") as HBoxContainer
	var exit_button := _prop("exit_button") as Button
	var continue_button := _prop("continue_button") as Button
	pause_panel.custom_minimum_size = Vector2.ZERO
	pause_panel.position = Vector2.ZERO
	_place_full_width_control(title_label, viewport_size.y * 0.172, viewport_size, 72.0)
	_place_full_width_control(summary_label, viewport_size.y * 0.232, viewport_size, 48.0)
	_place_full_width_control(reward_spacer, viewport_size.y * 0.290, viewport_size, viewport_size.y * 0.205)
	var button_height := clampf(viewport_size.y * 0.041, 58.0, 78.0)
	var button_width := clampf(viewport_size.x * 0.296, 148.0, 320.0)
	var button_gap := clampf(viewport_size.x * 0.083, 30.0, 96.0)
	var total_width := button_width * 2.0 + button_gap
	var button_size := Vector2(button_width, button_height)
	actions.custom_minimum_size = Vector2(total_width, button_height)
	actions.size = Vector2(total_width, button_height)
	actions.position = Vector2((viewport_size.x - total_width) * 0.5, viewport_size.y * 0.630)
	actions.add_theme_constant_override("separation", int(button_gap))
	exit_button.custom_minimum_size = button_size
	continue_button.custom_minimum_size = button_size


func _place_full_width_control(control: Control, y: float, viewport_size: Vector2, height: float) -> void:
	control.position = Vector2(0.0, y)
	control.size = Vector2(viewport_size.x, height)


func lock_ultimate_meter_layout() -> void:
	var ultimate_layout := _prop("ultimate_layout") as HBoxContainer
	var ultimate_cost_badge := _prop("ultimate_cost_badge") as PanelContainer
	var ultimate_bar := _prop("ultimate_bar") as ProgressBar
	ultimate_layout.anchor_left = 0.0
	ultimate_layout.anchor_right = 0.0
	ultimate_layout.offset_left = 55.0
	ultimate_layout.offset_top = 4.0
	ultimate_layout.offset_right = 1048.0
	ultimate_layout.offset_bottom = 62.0
	ultimate_layout.custom_minimum_size = Vector2(0.0, 58.0)
	ultimate_cost_badge.custom_minimum_size = Vector2(58.0, 58.0)
	ultimate_cost_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ultimate_cost_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ultimate_cost_badge.size = Vector2(58.0, 58.0)
	ultimate_cost_badge.pivot_offset = Vector2(29.0, 29.0)
	ultimate_bar.custom_minimum_size.y = 30.0
	ultimate_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func ensure_ultimate_lock_icons() -> void:
	var icons: Array = hud.get("ultimate_lock_icons") as Array
	if icons.size() >= ultimate_limit_segments:
		return
	var ultimate_bar := _prop("ultimate_bar") as ProgressBar
	var lock_texture: Texture2D = HUD_CARD_WIDGETS.load_card_texture(limit_lock_icon_path)
	while icons.size() < ultimate_limit_segments:
		var index := icons.size()
		var lock_icon := TextureRect.new()
		lock_icon.name = "UltimateLimitLockIcon%d" % (index + 1)
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.texture = lock_texture
		lock_icon.z_index = 30
		lock_icon.visible = false
		ultimate_bar.add_child(lock_icon)
		icons.append(lock_icon)
	hud.set("ultimate_lock_icons", icons)


func update_ultimate_limit_lock(unlocked_segments: int) -> void:
	ensure_ultimate_lock_icons()
	var icons: Array = hud.get("ultimate_lock_icons") as Array
	var unlocked := mini(ultimate_limit_segments, maxi(0, unlocked_segments))
	var ultimate_bar := _prop("ultimate_bar") as ProgressBar
	var bar_size := ultimate_bar.size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		for lock_icon in icons:
			(lock_icon as TextureRect).visible = false
		return
	var icon_size := clampf(bar_size.y * 0.70, 14.0, 22.0)
	for index in range(icons.size()):
		var lock_icon := icons[index] as TextureRect
		var is_locked := index >= unlocked and index < ultimate_limit_segments
		lock_icon.visible = is_locked
		if not is_locked:
			continue
		var segment_center_x := bar_size.x * ((float(index) + 0.5) / float(ultimate_limit_segments))
		lock_icon.size = Vector2(icon_size, icon_size)
		lock_icon.position = Vector2(segment_center_x - icon_size * 0.5, (bar_size.y - icon_size) * 0.5)


func _prop(property_name: String) -> Variant:
	return hud.get(property_name)
