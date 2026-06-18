extends RefCounted
class_name HudPileOverlayContentView


static func build(column: VBoxContainer) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.name = "DrawPileScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.name = "DrawPileGridMargin"
	grid_margin.add_theme_constant_override("margin_left", 18)
	grid_margin.add_theme_constant_override("margin_top", 28)
	grid_margin.add_theme_constant_override("margin_right", 18)
	grid_margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.name = "DrawPileGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_margin.add_child(grid)

	var empty_label := _build_empty_label()
	column.add_child(empty_label)

	return {
		"scroll": scroll,
		"grid_margin": grid_margin,
		"grid": grid,
		"empty_label": empty_label,
	}


static func _build_empty_label() -> Label:
	var empty_label := Label.new()
	empty_label.name = "DrawPileEmptyLabel"
	empty_label.text = "牌堆为空"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 28)
	empty_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	empty_label.visible = false
	return empty_label
