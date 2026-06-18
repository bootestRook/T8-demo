extends RefCounted
class_name HudCardReadabilityTextApplier


static func apply(widget: Dictionary, frames: Dictionary) -> void:
	_layout_primary_labels(widget, frames)
	_layout_art(widget, frames)
	_layout_description(widget, frames)
	_layout_school(widget, frames)


static func _layout_primary_labels(widget: Dictionary, frames: Dictionary) -> void:
	var cost: Label = widget["cost"] as Label
	_apply_rect(cost, frames["cost"])
	cost.z_index = 5
	cost.rotation = 0.0
	cost.scale = Vector2.ONE
	cost.pivot_offset = cost.size * 0.5
	cost.clip_text = false
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var name: Label = widget["name"] as Label
	name.visible = true
	_apply_rect(name, frames["name"])
	name.z_index = 5
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var type_label: Label = widget["type"] as Label
	type_label.visible = false
	_apply_rect(type_label, frames["type"])
	type_label.z_index = 5
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func _layout_art(widget: Dictionary, frames: Dictionary) -> void:
	var art: Label = widget["art"] as Label
	_apply_rect(art, frames["art"])
	art.z_index = 5
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if widget.has("art_texture"):
		var art_texture: TextureRect = widget["art_texture"] as TextureRect
		art_texture.position = art.position
		art_texture.size = art.size
		art_texture.z_index = 1


static func _layout_description(widget: Dictionary, frames: Dictionary) -> void:
	var desc := widget["desc"] as Control
	_apply_rect(desc, frames["desc"])
	desc.z_index = 5
	if desc is Label:
		(desc as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(desc as Label).vertical_alignment = VERTICAL_ALIGNMENT_TOP
		(desc as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if desc is RichTextLabel:
		var rich_desc := desc as RichTextLabel
		rich_desc.bbcode_enabled = true
		rich_desc.fit_content = false
		rich_desc.scroll_active = false
		rich_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rich_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		rich_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _layout_school(widget: Dictionary, frames: Dictionary) -> void:
	var school: Label = widget["school"] as Label
	school.visible = false
	_apply_rect(school, frames["school"])
	school.z_index = 5
	school.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	school.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	school.autowrap_mode = TextServer.AUTOWRAP_OFF
	school.clip_text = true


static func _apply_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
