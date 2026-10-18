## Генератор звуков: синтезирует AudioStreamWAV прямо в игре, без внешних файлов.
class_name Sfx
extends RefCounted

const RATE := 22050

var streams := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261017
	streams["ak47"] = _gunshot(0.24, 3400.0, 26.0, 135.0, 34.0, 1.0, 0.55)
	streams["deagle"] = _gunshot(0.34, 4200.0, 19.0, 105.0, 24.0, 1.05, 0.85)
	streams["sniper"] = _gunshot(1.10, 3000.0, 11.0, 78.0, 14.0, 1.15, 1.25)
	streams["bot_shot"] = _gunshot(0.22, 2600.0, 24.0, 150.0, 32.0, 0.85, 0.40)
	streams["empty"] = _click(0.05, 1400.0, 90.0, 0.35)
	streams["reload"] = _click(0.09, 900.0, 42.0, 0.55)
	streams["reload_done"] = _click(0.11, 1500.0, 36.0, 0.5)
	streams["hit"] = _blip(0.07, 1500.0, 1900.0, 34.0, 0.5)
	streams["headshot"] = _blip(0.13, 1900.0, 2600.0, 22.0, 0.6)
	streams["kill"] = _blip(0.30, 700.0, 1500.0, 11.0, 0.55)
	streams["hurt"] = _hurt(0.35)
	streams["footstep"] = _footstep()
	streams["pickup"] = _blip(0.22, 600.0, 1300.0, 16.0, 0.5)
	streams["switch"] = _click(0.08, 700.0, 55.0, 0.4)
	streams["die"] = _blip(0.90, 500.0, 180.0, 5.0, 0.7)


func get_stream(id: String) -> AudioStreamWAV:
	if streams.has(id):
		return streams[id]
	return streams["hit"]


## Проигрывает звук на не-позиционном плеере (оружие игрока в руках).
func play(player: AudioStreamPlayer, id: String, volume_db := 0.0, pitch_variation := 0.04) -> void:
	if player == null:
		return
	player.stream = get_stream(id)
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	player.play()


## Проигрывает звук в точке мира.
func play_at(parent: Node, position: Vector3, id: String, volume_db := 0.0, max_distance := 80.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var voice := AudioStreamPlayer3D.new()
	parent.add_child(voice)
	voice.global_position = position
	voice.stream = get_stream(id)
	voice.volume_db = volume_db
	voice.unit_size = 12.0
	voice.max_distance = max_distance
	voice.pitch_scale = 1.0 + _rng.randf_range(-0.05, 0.05)
	voice.finished.connect(voice.queue_free)
	voice.play()


func _gunshot(duration: float, cutoff: float, noise_decay: float, thump_hz: float,
		thump_decay: float, noise_amp: float, thump_amp: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var alpha := clampf(TAU * cutoff / float(RATE), 0.02, 0.98)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var white := _rng.randf_range(-1.0, 1.0)
		lp1 += (white - lp1) * alpha
		lp2 += (lp1 - lp2) * alpha
		var crack := lp1 * exp(-t * noise_decay * 1.6)
		var body := lp2 * exp(-t * noise_decay)
		var thump := sin(TAU * thump_hz * t) * exp(-t * thump_decay)
		buf[i] = crack * noise_amp * 0.8 + body * noise_amp + thump * thump_amp
	# короткий "хвост" — имитация эха арены
	buf = _echo(buf, 0.085, 0.32)
	buf = _echo(buf, 0.19, 0.18)
	return _to_stream(buf, 0.92)


func _click(duration: float, cutoff: float, decay: float, amp: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var alpha := clampf(TAU * cutoff / float(RATE), 0.02, 0.98)
	var lp := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * alpha
		buf[i] = lp * exp(-t * decay) * amp
	return _to_stream(buf, 0.8)


func _blip(duration: float, start_hz: float, end_hz: float, decay: float, amp: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var k := t / duration
		var hz: float = lerpf(start_hz, end_hz, k)
		phase += TAU * hz / float(RATE)
		var env := exp(-t * decay)
		buf[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * env * amp
	return _to_stream(buf, 0.85)


func _hurt(duration: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var alpha := 0.25
	var lp := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var k := t / duration
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * alpha
		phase += TAU * lerpf(210.0, 95.0, k) / float(RATE)
		buf[i] = (lp * 0.35 + sin(phase) * 0.65) * exp(-t * 6.0) * 0.8
	return _to_stream(buf, 0.85)


func _footstep() -> AudioStreamWAV:
	var count := int(RATE * 0.09)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var alpha := 0.12
	var lp := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * alpha
		buf[i] = lp * exp(-t * 46.0) * 0.5
	return _to_stream(buf, 0.6)


func _echo(input: PackedFloat32Array, delay_sec: float, amount: float) -> PackedFloat32Array:
	var delay := int(RATE * delay_sec)
	var out := input.duplicate()
	for i in range(delay, out.size()):
		out[i] += input[i - delay] * amount
	return out


func _to_stream(buf: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var max_abs := 0.0
	for v in buf:
		max_abs = maxf(max_abs, absf(v))
	var gain := peak / maxf(max_abs, 0.0001)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var sample := clampf(buf[i] * gain, -1.0, 1.0)
		var iv := int(round(sample * 32000.0))
		data.encode_s16(i * 2, iv)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
