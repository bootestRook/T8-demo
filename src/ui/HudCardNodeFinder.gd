extends RefCounted
class_name HudCardNodeFinder


static func find_label_by_suffix(node: Node, suffix: String) -> Label:
	for child in node.get_children():
		if child is Label and String(child.name).ends_with(suffix):
			return child as Label
		var found := find_label_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func find_rich_text_label_by_suffix(node: Node, suffix: String) -> RichTextLabel:
	for child in node.get_children():
		if child is RichTextLabel and String(child.name).ends_with(suffix):
			return child as RichTextLabel
		var found := find_rich_text_label_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func find_texture_rect_by_suffix(node: Node, suffix: String) -> TextureRect:
	for child in node.get_children():
		if child is TextureRect and String(child.name).ends_with(suffix):
			return child as TextureRect
		var found := find_texture_rect_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func find_panel_by_suffix(node: Node, suffix: String) -> Panel:
	for child in node.get_children():
		if child is Panel and String(child.name).ends_with(suffix):
			return child as Panel
		var found := find_panel_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func find_color_rect_by_suffix(node: Node, suffix: String) -> ColorRect:
	for child in node.get_children():
		if child is ColorRect and String(child.name).ends_with(suffix):
			return child as ColorRect
		var found := find_color_rect_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func find_card_press_fx_by_suffix(node: Node, suffix: String) -> HudCardPressFx:
	for child in node.get_children():
		if child is HudCardPressFx and String(child.name).ends_with(suffix):
			return child as HudCardPressFx
		var found := find_card_press_fx_by_suffix(child, suffix)
		if found != null:
			return found
	return null


static func clear_unique_names(node: Node) -> void:
	node.unique_name_in_owner = false
	for child in node.get_children():
		clear_unique_names(child)
