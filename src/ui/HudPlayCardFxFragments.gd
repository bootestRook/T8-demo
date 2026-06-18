extends RefCounted
class_name HudPlayCardFxFragments

const HAND_CARD_SIZE := Vector2(150.0, 266.667)
const DISPLAY_SCALE := 1.18
const FRAGMENT_COLUMNS := 5
const FRAGMENT_ROWS := 7
const FRAGMENT_SPREAD_X := 132.0
const FRAGMENT_SPREAD_Y := 166.0
const FRAGMENT_END_SCALE := 0.18


static func spawn(parent: Control, display_position: Vector2, parent_z_index: int, serial: int) -> Dictionary:
	var shards: Array = []
	var next_serial := serial
	var cell_size := Vector2(HAND_CARD_SIZE.x / float(FRAGMENT_COLUMNS), HAND_CARD_SIZE.y / float(FRAGMENT_ROWS))
	for row in range(FRAGMENT_ROWS):
		for column in range(FRAGMENT_COLUMNS):
			next_serial += 1
			var fragment := _create_fragment(next_serial, parent_z_index, row, column, cell_size)
			parent.add_child(fragment)
			var local_center := Vector2((float(column) + 0.5) * cell_size.x, (float(row) + 0.5) * cell_size.y)
			var start_position := display_position + local_center * DISPLAY_SCALE - fragment.size * 0.5
			fragment.position = start_position
			(
				shards
				. append(
					{
						"node": fragment,
						"start_position": start_position,
						"end_position": start_position + _fragment_end_offset(row, column),
						"rotation_end": _fragment_rotation_end(row, column),
						"delay": float((row + column) % 4) * 0.018,
						"start_scale": 1.0 + float((row * 2 + column) % 3) * 0.08,
					}
				)
			)
	return {"shards": shards, "serial": next_serial}


static func apply(shards: Array, raw_t: float) -> void:
	for item in shards:
		if not (item is Dictionary):
			continue
		var shard_data: Dictionary = item as Dictionary
		var shard: ColorRect = shard_data.get("node", null) as ColorRect
		if shard == null:
			continue
		var local_t := clampf(
			(raw_t - float(shard_data.get("delay", 0.0))) / maxf(0.01, 1.0 - float(shard_data.get("delay", 0.0))), 0.0, 1.0
		)
		var fragment_t := _ease_out(local_t)
		var start_position: Vector2 = shard_data["start_position"]
		var end_position: Vector2 = shard_data["end_position"]
		shard.position = start_position + (end_position - start_position) * fragment_t
		var scale := lerpf(float(shard_data.get("start_scale", 1.0)), FRAGMENT_END_SCALE, fragment_t)
		shard.scale = Vector2(scale, scale)
		shard.rotation = lerpf(0.0, float(shard_data["rotation_end"]), fragment_t)
		shard.modulate = Color(1.0, 0.92, 0.62, 1.0 - fragment_t)


static func free_shards(shards: Array) -> void:
	for item in shards:
		if not (item is Dictionary):
			continue
		var shard_data: Dictionary = item as Dictionary
		var shard: Node = shard_data.get("node", null) as Node
		if shard != null:
			shard.queue_free()


static func _create_fragment(serial: int, parent_z_index: int, row: int, column: int, cell_size: Vector2) -> ColorRect:
	var fragment := ColorRect.new()
	var size_multiplier := _fragment_size_multiplier(row, column)
	var scaled_cell_size := cell_size * DISPLAY_SCALE
	fragment.name = "PlayCardFragment%d" % serial
	fragment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fragment.size = Vector2(scaled_cell_size.x * size_multiplier.x, scaled_cell_size.y * size_multiplier.y)
	fragment.pivot_offset = fragment.size * 0.5
	fragment.z_index = parent_z_index + 1 + row * FRAGMENT_COLUMNS + column
	fragment.color = _fragment_color(row, column)
	return fragment


static func _fragment_size_multiplier(row: int, column: int) -> Vector2:
	var width_scale := 0.62 + float((row + column) % 3) * 0.11
	var height_scale := 0.46 + float((row * 2 + column) % 4) * 0.09
	return Vector2(width_scale, height_scale)


static func _fragment_end_offset(row: int, column: int) -> Vector2:
	var x_ratio := (float(column) / float(FRAGMENT_COLUMNS - 1)) * 2.0 - 1.0
	var y_ratio := (float(row) / float(FRAGMENT_ROWS - 1)) * 2.0 - 1.0
	var stagger := float((row * 3 + column * 5) % 7) - 3.0
	return Vector2(x_ratio * FRAGMENT_SPREAD_X + stagger * 10.0, y_ratio * FRAGMENT_SPREAD_Y - 28.0 + stagger * 4.0)


static func _fragment_rotation_end(row: int, column: int) -> float:
	var direction := -1.0 if (row + column) % 2 == 0 else 1.0
	return direction * (0.45 + float((row * 5 + column) % 5) * 0.12)


static func _fragment_color(row: int, column: int) -> Color:
	var palette := [
		Color(1.0, 0.92, 0.58, 0.92),
		Color(1.0, 0.68, 0.30, 0.88),
		Color(0.78, 0.48, 0.18, 0.84),
		Color(1.0, 0.98, 0.82, 0.90),
	]
	return palette[(row * FRAGMENT_COLUMNS + column) % palette.size()]


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
