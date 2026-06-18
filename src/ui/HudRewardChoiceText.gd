extends RefCounted
class_name HudRewardChoiceText


static func title(choice: Dictionary) -> String:
	return String(choice.get("title", "奖励")).strip_edges()


static func school(choice: Dictionary) -> String:
	return String(choice.get("school", choice.get("kind", "词条"))).strip_edges()


static func choices_signature(choices: Array) -> String:
	var parts := PackedStringArray()
	for choice_variant in choices:
		if choice_variant is Dictionary:
			var choice := choice_variant as Dictionary
			parts.append(
				(
					"%s|%s|%s|%s|%s"
					% [
						choice.get("title", ""),
						choice.get("kind", ""),
						description(choice),
						cost_count_text(choice),
						school_count_text(choice)
					]
				)
			)
	return ";".join(parts)


static func card_cost_text(choice: Dictionary) -> String:
	if not is_card_choice(choice) or not choice.has("cost"):
		return ""
	if choice.has("cost_display"):
		return String(choice.get("cost_display", "")).strip_edges()
	return str(int(choice.get("cost", 0)))


static func school_count_text(choice: Dictionary) -> String:
	if not is_card_choice(choice):
		return ""
	if choice.has("school_owned_count_text"):
		return String(choice.get("school_owned_count_text", "")).strip_edges()
	if choice.has("school_owned_count"):
		return "X%d" % int(choice.get("school_owned_count", 0))
	return ""


static func cost_count_text(choice: Dictionary) -> String:
	if not is_card_choice(choice):
		return ""
	if choice.has("cost_owned_count_text"):
		return String(choice.get("cost_owned_count_text", "")).strip_edges()
	if choice.has("cost_owned_count"):
		return "X%d" % int(choice.get("cost_owned_count", 0))
	return ""


static func description(choice: Dictionary) -> String:
	var direct_text := String(choice.get("description", choice.get("effect", choice.get("desc", "")))).strip_edges()
	var fallback := "立即生效"
	if direct_text.is_empty():
		var kind := String(choice.get("kind", ""))
		match kind:
			"new_card":
				fallback = "将该卡加入牌库"
			"gun_upgrade":
				fallback = "修改枪械战斗数值"
			"survival":
				fallback = "修改城墙生存数值"
			"energy":
				fallback = "修改能量或补牌节奏"
			"core_skill":
				fallback = "修改流派战斗参数"
		return fallback
	return direct_text


static func visible_description(choice: Dictionary) -> String:
	var text := description(choice).strip_edges()
	var kind := String(choice.get("kind", "")).strip_edges()
	var entry_type := String(choice.get("entry_type", "")).strip_edges()
	if entry_type == "card" or kind == "new_card":
		text = text.replace("加入牌库\\n", "")
		text = text.replace("加入牌库\n", "")
		if text == "加入牌库" or text == "将该卡加入牌库":
			return ""
	return text


static func entry_type_badge_text(choice: Dictionary) -> String:
	if is_card_choice(choice):
		return "卡牌"
	return ""


static func is_card_choice(choice: Dictionary) -> bool:
	return String(choice.get("entry_type", "")).strip_edges() == "card" or String(choice.get("kind", "")).strip_edges() == "new_card"
