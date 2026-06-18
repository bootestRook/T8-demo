extends RefCounted
class_name HudUiHelpers


static func discard_hand_block_message(
	gameplay_active: bool, overlay_blocked: bool, discard_fx_active: bool, discard_cooldown: float, hand_count: int
) -> String:
	if not gameplay_active:
		return "战斗未开始"
	if overlay_blocked:
		return "当前不能弃牌"
	if discard_fx_active:
		return "正在弃牌"
	if discard_cooldown > 0.0:
		return "弃牌冷却中"
	if hand_count <= 0:
		return "没有可弃的手牌"
	return "暂时不能弃牌"


static func all_labels(hud: Node) -> Array:
	return [
		hud.get("time_label") as Label,
		hud.get("stage_label") as Label,
		hud.get("wave_label") as Label,
		hud.get("level_title_label") as Label,
		hud.get("level_value_label") as Label,
		hud.get("exp_value_label") as Label,
		hud.get("objective_label") as Label,
		hud.get("ammo_value_label") as Label,
		hud.get_node("%DefenseWallLabel") as Label,
		hud.get_node("%WallHpTitleLabel") as Label,
		hud.get("shield_icon_label") as Label,
		hud.get("shield_value_label") as Label,
		hud.get("wall_hp_icon_label") as Label,
		hud.get("wall_hp_value_label") as Label,
		hud.get_node("%EnergyTitleLabel") as Label,
		hud.get("energy_value_label") as Label,
		hud.get_node("%HeroPortraitLabel") as Label,
		hud.get("hero_name_label") as Label,
		hud.get("ultimate_cost_label") as Label,
		hud.get_node("%UltimateTitleLabel") as Label,
		hud.get("hint_label") as Label,
		hud.get("bottom_toast_label") as Label,
		hud.get("main_menu_title_label") as Label,
		hud.get("main_menu_summary_label") as Label,
		hud.get("pause_title_label") as Label,
		hud.get("pause_summary_label") as Label,
	]
