extends RefCounted
class_name HudRewardChoiceBadges

const HUD_REWARD_CHOICE_COST_BADGE := preload("res://src/ui/HudRewardChoiceCostBadge.gd")
const HUD_REWARD_CHOICE_ENTRY_TYPE_BADGE := preload("res://src/ui/HudRewardChoiceEntryTypeBadge.gd")
const HUD_REWARD_CHOICE_SCHOOL_BADGE := preload("res://src/ui/HudRewardChoiceSchoolBadge.gd")


static func build_entry_type_badge(text: String) -> Control:
	return HUD_REWARD_CHOICE_ENTRY_TYPE_BADGE.build(text)


static func build_card_cost_badge(text: String) -> Control:
	return HUD_REWARD_CHOICE_COST_BADGE.build_card_cost_badge(text)


static func build_cost_count_label(text: String) -> Control:
	return HUD_REWARD_CHOICE_COST_BADGE.build_cost_count_label(text)


static func build_school_badge_row(school: String, count_text: String) -> Control:
	return HUD_REWARD_CHOICE_SCHOOL_BADGE.build_school_badge_row(school, count_text)


static func build_school_count_label(text: String) -> Control:
	return HUD_REWARD_CHOICE_SCHOOL_BADGE.build_school_count_label(text)


static func build_school_badge(school: String) -> Control:
	return HUD_REWARD_CHOICE_SCHOOL_BADGE.build_school_badge(school)
