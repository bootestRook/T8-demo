extends RefCounted
class_name HudSnapshotPresenter

const HUD_THEME := preload("res://src/ui/HudTheme.gd")

var _nodes: Dictionary = {}
var _default_stage := ""
var _ultimate_limit_segments := 10


func setup(nodes: Dictionary, default_stage: String, ultimate_limit_segments: int) -> void:
	_nodes = nodes
	_default_stage = default_stage
	_ultimate_limit_segments = ultimate_limit_segments


func apply(snapshot: Dictionary) -> Dictionary:
	var values := _snapshot_values(snapshot)
	_sync_small_hero(snapshot)
	_set_label("time_label", HUD_THEME.format_time(values["elapsed"]))
	_set_label("stage_label", HUD_THEME.fit_text(String(snapshot.get("stage_name", _default_stage)), 18))
	_set_label("wave_label", "波次: %d/%d" % [values["wave_current"], values["wave_total"]])
	_set_label("level_value_label", "%d级" % values["level"])
	_set_label("exp_value_label", "%d/%d" % [values["exp"], values["exp_max"]])
	_set_progress("exp_bar", values["exp"], values["exp_max"])
	_set_objective(snapshot)
	_set_label("ammo_value_label", "%d/%d" % [values["ammo"], values["ammo_max"]])
	_set_label("wall_hp_value_label", "%d" % values["wall_hp"])
	_set_progress("wall_hp_bar", values["wall_hp"], values["wall_hp_max"])
	_set_wall_shield(values["wall_shield"])
	_set_label("energy_value_label", "%d/%d" % [values["energy"], values["energy_max"]])
	_set_label("hero_name_label", HUD_THEME.fit_text(String(snapshot.get("hero_name", "艾琳")), 14))
	_set_label("ultimate_cost_label", str(values["energy"]))
	_set_progress("ultimate_bar", values["energy"], _ultimate_limit_segments)

	return {
		"energy": values["energy"],
		"energy_max": values["energy_max"],
	}


func _snapshot_values(snapshot: Dictionary) -> Dictionary:
	return {
		"elapsed": float(snapshot.get("elapsed_time", 0.0)),
		"wave_current": int(snapshot.get("wave_current", 1)),
		"wave_total": int(snapshot.get("wave_total", 20)),
		"level": int(snapshot.get("level", 1)),
		"exp": int(snapshot.get("exp", 60)),
		"exp_max": maxi(1, int(snapshot.get("exp_max", 60))),
		"wall_hp": int(snapshot.get("wall_hp", snapshot.get("hp", 3000))),
		"wall_hp_max": maxi(1, int(snapshot.get("wall_hp_max", 3000))),
		"wall_shield": int(snapshot.get("wall_shield", 0)),
		"energy": int(snapshot.get("energy", 3)),
		"energy_max": maxi(1, int(snapshot.get("energy_max", 3))),
		"ammo": int(snapshot.get("ammo", 30)),
		"ammo_max": maxi(1, int(snapshot.get("ammo_max", 30))),
	}


func _sync_small_hero(snapshot: Dictionary) -> void:
	var small_hero_icon := _control("small_hero_icon")
	if small_hero_icon != null and small_hero_icon.has_method("set_battle_snapshot"):
		small_hero_icon.call("set_battle_snapshot", snapshot)


func _set_objective(snapshot: Dictionary) -> void:
	_set_label("objective_label", HUD_THEME.clean_label_prefix(HUD_THEME.fit_text(String(snapshot.get("objective", "守住城墙")), 30)))
	var objective_panel := _control("objective_panel")
	if objective_panel != null:
		objective_panel.visible = false


func _set_wall_shield(wall_shield: int) -> void:
	var shield_row := _control("shield_row")
	if shield_row != null:
		shield_row.visible = true
	_set_label("shield_value_label", "%d" % wall_shield)


func _set_label(key: String, text: String) -> void:
	var label := _nodes.get(key, null) as Label
	if label != null:
		label.text = text


func _set_progress(key: String, value: float, max_value: float) -> void:
	var bar := _nodes.get(key, null) as ProgressBar
	if bar == null:
		return
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)


func _control(key: String) -> Control:
	return _nodes.get(key, null) as Control
