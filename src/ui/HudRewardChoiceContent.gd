extends RefCounted
class_name HudRewardChoiceContent

const HUD_REWARD_CHOICE_CONTENT_NODES := preload("res://src/ui/HudRewardChoiceContentNodes.gd")
const HUD_REWARD_CHOICE_TEXT := preload("res://src/ui/HudRewardChoiceText.gd")


static func build(choice: Dictionary) -> Control:
	return HUD_REWARD_CHOICE_CONTENT_NODES.build(choice)


static func choices_signature(choices: Array) -> String:
	return HUD_REWARD_CHOICE_TEXT.choices_signature(choices)


static func card_cost_text(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.card_cost_text(choice)


static func school_count_text(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.school_count_text(choice)


static func cost_count_text(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.cost_count_text(choice)


static func description(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.description(choice)


static func visible_description(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.visible_description(choice)


static func entry_type_badge_text(choice: Dictionary) -> String:
	return HUD_REWARD_CHOICE_TEXT.entry_type_badge_text(choice)


static func is_card_choice(choice: Dictionary) -> bool:
	return HUD_REWARD_CHOICE_TEXT.is_card_choice(choice)
