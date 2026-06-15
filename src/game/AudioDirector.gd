extends Node

# 轻量程序化音效入口。新游戏可以继续通过 GameEvents 解耦触发音频。

var muted := false
var _player: AudioStreamPlayer
var _mix_rate := 22050


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = _mix_rate
	stream.buffer_length = 0.12
	_player.stream = stream
	add_child(_player)
	_player.play()
	if has_node("/root/GameEvents"):
		GameEvents.subscribe(GameEvents.AUDIO_REQUESTED, Callable(self, "_on_audio_requested"))
		GameEvents.subscribe(GameEvents.ACHIEVEMENT_UNLOCKED, Callable(self, "_on_achievement_unlocked"))


func play_event(event_id: StringName, _context: Dictionary = {}) -> void:
	match event_id:
		GameEvents.ACHIEVEMENT_UNLOCKED:
			play_achievement()
		_:
			play_ping()


func play_ping() -> void:
	_play_tone(660.0, 0.05, 0.14)


func play_achievement() -> void:
	_play_tone(1040.0, 0.06, 0.12)


func _play_tone(freq: float, duration: float, volume: float) -> void:
	if muted or _player == null:
		return
	if not _player.playing:
		_player.play()
	var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(float(_mix_rate) * duration)
	for i in frames:
		if playback.get_frames_available() <= 0:
			break
		var progress := float(i) / maxf(1.0, float(frames))
		var envelope := 1.0 - progress
		var sample := sin(TAU * freq * float(i) / float(_mix_rate)) * volume * envelope
		playback.push_frame(Vector2(sample, sample))


func _on_audio_requested(payload: Dictionary) -> void:
	play_event(payload.get("event_id", &""), payload)


func _on_achievement_unlocked(payload: Dictionary) -> void:
	play_event(GameEvents.ACHIEVEMENT_UNLOCKED, payload)
