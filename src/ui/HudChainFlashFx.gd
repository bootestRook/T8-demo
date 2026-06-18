extends RefCounted
class_name HudChainFlashFx

const STATUS_Z_INDEX := 260
const PULSE_DURATION := 0.26
const STATUS_SIZE := Vector2(260.0, 58.0)
const PI_VALUE := 3.1415927

var _battlefield_frame: Control = null
var _label: Label = null
var _timer := 0.0
var _last_card_play_signature := ""


func setup(battlefield_frame: Control) -> void:
	_battlefield_frame = battlefield_frame
	_label = Label.new()
	_label.name = "ChainStatusLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size = STATUS_SIZE
	_label.size = STATUS_SIZE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.z_index = STATUS_Z_INDEX
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.34))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	_label.add_theme_constant_override("shadow_offset_x", 3)
	_label.add_theme_constant_override("shadow_offset_y", 4)
	_battlefield_frame.add_child(_label)


func sync(snapshot: Dictionary, gameplay_active: bool) -> void:
	if _label == null:
		return
	var chain_active := bool(snapshot.get("chain_active", int(snapshot.get("last_chain_cost", -1)) >= 0))
	_label.visible = gameplay_active and chain_active
	if not _label.visible:
		return
	_apply_layout()
	_label.text = _status_text(snapshot)

	var log_variant: Variant = snapshot.get("pending_effect_log", [])
	if not (log_variant is Array):
		return
	var pending_log: Array = log_variant as Array
	if pending_log.is_empty():
		_last_card_play_signature = ""
		return
	var latest_variant: Variant = pending_log[pending_log.size() - 1]
	if not (latest_variant is Dictionary):
		return
	var latest: Dictionary = latest_variant as Dictionary
	var signature := (
		"%s|%s|%s|%s"
		% [
			str(latest.get("time", "")),
			String(latest.get("card_id", "")),
			str(latest.get("chain_multiplier", "")),
			String(latest.get("play_source", "")),
		]
	)
	if signature == _last_card_play_signature:
		return
	_last_card_play_signature = signature
	_timer = PULSE_DURATION


func _status_text(snapshot: Dictionary) -> String:
	var multiplier := maxi(1, int(snapshot.get("chain_multiplier", 1)))
	var chain_active := bool(snapshot.get("chain_active", int(snapshot.get("last_chain_cost", -1)) >= 0))
	if not chain_active:
		return ""
	return "连锁X%d" % multiplier


func _apply_layout() -> void:
	if _label == null or _battlefield_frame == null:
		return
	var frame_size := _battlefield_frame.size
	var x := maxf(14.0, frame_size.x * 0.018)
	var y := maxf(70.0, frame_size.y - 150.0)
	_label.position = Vector2(x, y)
	_label.pivot_offset = STATUS_SIZE * 0.5
	_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func update(delta: float) -> void:
	if _label == null or not _label.visible:
		return
	if _timer <= 0.0:
		_label.scale = Vector2.ONE
		_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	_timer = maxf(0.0, _timer - delta)
	var t := 1.0 - (_timer / PULSE_DURATION)
	var pulse := 0.10 * sin(t * PI_VALUE)
	var scale_value := 1.0 + pulse
	_label.scale = Vector2(scale_value, scale_value)
	_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func reset() -> void:
	_timer = 0.0
	_last_card_play_signature = ""
	if _label != null:
		_label.visible = false
		_label.scale = Vector2.ONE
