extends RefCounted
class_name HudCardDescriptionText

const HUD_CARD_NODE_FINDER := preload("res://src/ui/HudCardNodeFinder.gd")


static func ensure_widget(widget: Dictionary) -> void:
	var panel: PanelContainer = widget["panel"] as PanelContainer
	widget["desc"] = ensure_label(panel)


static func ensure_label(panel: PanelContainer) -> Control:
	var rich_label := HUD_CARD_NODE_FINDER.find_rich_text_label_by_suffix(panel, "DescRichTextLabel")
	if rich_label != null:
		return rich_label
	var legacy_label := HUD_CARD_NODE_FINDER.find_label_by_suffix(panel, "DescLabel")
	if legacy_label == null:
		return null
	var parent := legacy_label.get_parent() as Control
	if parent == null:
		return legacy_label
	legacy_label.visible = false
	var desc_rich := RichTextLabel.new()
	desc_rich.name = String(legacy_label.name).replace("DescLabel", "DescRichTextLabel")
	desc_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rich.bbcode_enabled = true
	desc_rich.fit_content = false
	desc_rich.scroll_active = false
	desc_rich.horizontal_alignment = legacy_label.horizontal_alignment
	desc_rich.vertical_alignment = legacy_label.vertical_alignment
	desc_rich.autowrap_mode = legacy_label.autowrap_mode
	parent.add_child(desc_rich)
	return desc_rich


static func apply_text(desc_control: Control, plain_text: String, rich_text: String, rich_text_font_size: int) -> void:
	var display_rich_text := rich_text.replace("{chain_font_size}", str(rich_text_font_size))
	if desc_control is RichTextLabel:
		var rich_label := desc_control as RichTextLabel
		rich_label.bbcode_enabled = true
		rich_label.text = display_rich_text
		return
	if desc_control is Label:
		(desc_control as Label).text = plain_text


static func apply_font_size(desc_control: Control, font_size: int) -> void:
	if desc_control is RichTextLabel:
		for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
			desc_control.add_theme_font_size_override(key, font_size)
		return
	desc_control.add_theme_font_size_override("font_size", font_size)
