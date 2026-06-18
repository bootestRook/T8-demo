extends RefCounted
class_name HudCardLabelStyler

const HUD_CARD_LABEL_STYLE_GROUPS := preload("res://src/ui/HudCardLabelStyleGroups.gd")


static func card_text_scale(hand_card_size: Vector2) -> float:
	return HUD_CARD_LABEL_STYLE_GROUPS.card_text_scale(hand_card_size)


static func scaled_font_size(base_size: int, scale: float) -> int:
	return HUD_CARD_LABEL_STYLE_GROUPS.scaled_font_size(base_size, scale)


static func scaled_constant(base_value: int, scale: float) -> int:
	return HUD_CARD_LABEL_STYLE_GROUPS.scaled_constant(base_value, scale)


static func style_card_labels(widget: Dictionary, theme: Variant) -> void:
	HUD_CARD_LABEL_STYLE_GROUPS.style_card_labels(widget, theme)
