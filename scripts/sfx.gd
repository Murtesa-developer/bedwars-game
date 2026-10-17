extends RefCounted
# Procedural sound effects + background music (no audio files needed). Streams are synthesized once and cached.

const Settings = preload("res://scripts/settings.gd")
const RATE := 22050
static var cache := {}
static var last_play := {}
static var music_player: AudioStreamPlayer = null

# ---------------------------------------------------------------- synthesis helpers
static func _make(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	w.data = bytes
	return w

static func _tone(freq: float, dur: float, vol: float, decay: float, freq_end: float = -1.0) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq if freq_end < 0.0 else lerpf(freq, freq_end, t / dur)
		ph += TAU * f / RATE
		out[i] = sin(ph) * vol * exp(-decay * t)
	return out

static func _noise(dur: float, vol: float, decay: float, smooth: float = 0.0) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + int(dur * 1000.0)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, smooth)
		out[i] = prev * vol * exp(-decay * t)
	return out

static func _mix(parts: Array, offsets: Array = []) -> PackedFloat32Array:
	var n := 0
	for i in parts.size():
		var off := int(RATE * float(offsets[i])) if i < offsets.size() else 0
		n = maxi(n, off + parts[i].size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in parts.size():
		var off2 := int(RATE * float(offsets[i])) if i < offsets.size() else 0
		var p: PackedFloat32Array = parts[i]
		for j in p.size():
			out[off2 + j] += p[j]
	return out

static func _synth(name: String) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	match name:
		"place": s = _mix([_tone(130.0, 0.12, 0.8, 22.0, 70.0), _noise(0.05, 0.35, 50.0, 0.3)])
		"break": s = _mix([_noise(0.22, 0.8, 12.0, 0.2), _tone(90.0, 0.15, 0.4, 20.0)])
		"hit": s = _mix([_noise(0.1, 0.7, 30.0, 0.1), _tone(180.0, 0.1, 0.5, 30.0, 100.0)])
		"swing": s = _noise(0.22, 0.5, 9.0, 0.85)
		"draw": s = _mix([_tone(260.0, 0.6, 0.18, 1.5, 430.0), _noise(0.6, 0.12, 2.0, 0.9)])
		"shot": s = _mix([_tone(300.0, 0.3, 0.6, 10.0, 140.0), _noise(0.12, 0.4, 25.0, 0.5)])
		"arrow_hit": s = _mix([_noise(0.08, 0.5, 40.0, 0.2), _tone(150.0, 0.1, 0.5, 30.0)])
		"explosion": s = _mix([_noise(1.1, 1.0, 3.2, 0.9), _tone(55.0, 0.9, 0.9, 3.0, 30.0)])
		"fireball": s = _mix([_noise(0.6, 0.5, 3.5, 0.8), _tone(200.0, 0.5, 0.3, 4.0, 500.0)])
		"fireball_hit": s = _mix([_noise(0.4, 0.8, 6.0, 0.7), _tone(80.0, 0.3, 0.6, 8.0, 40.0)])
		"fuse": s = _noise(4.0, 0.22, 0.1, 0.5)
		"coin": s = _mix([_tone(988.0, 0.12, 0.4, 12.0), _tone(1319.0, 0.25, 0.4, 9.0)], [0.0, 0.07])
		"emerald": s = _mix([_tone(1568.0, 0.2, 0.35, 8.0), _tone(2093.0, 0.35, 0.35, 6.0)], [0.0, 0.08])
		"eat": s = _mix([_noise(0.06, 0.6, 40.0, 0.4), _noise(0.06, 0.6, 40.0, 0.4), _noise(0.06, 0.6, 40.0, 0.4)], [0.0, 0.12, 0.24])
		"hurt": s = _mix([_tone(220.0, 0.2, 0.6, 12.0, 120.0), _noise(0.1, 0.4, 30.0, 0.2)])
		"death": s = _tone(300.0, 0.6, 0.6, 3.0, 50.0)
		"step": s = _noise(0.07, 0.22, 45.0, 0.6)
		"bed": s = _mix([_noise(0.8, 0.9, 4.0, 0.8), _tone(70.0, 0.7, 0.9, 4.0, 35.0), _tone(200.0, 0.3, 0.4, 8.0)])
		"click": s = _tone(600.0, 0.05, 0.4, 40.0)
		"splash": s = _mix([_noise(0.45, 0.6, 6.0, 0.7), _tone(500.0, 0.25, 0.25, 10.0, 200.0)])
		"win": s = _mix([_tone(523.0, 0.3, 0.4, 4.0), _tone(659.0, 0.3, 0.4, 4.0), _tone(784.0, 0.3, 0.4, 4.0), _tone(1047.0, 0.6, 0.4, 3.0)], [0.0, 0.2, 0.4, 0.6])
		"lose": s = _mix([_tone(392.0, 0.35, 0.4, 4.0), _tone(330.0, 0.35, 0.4, 4.0), _tone(262.0, 0.35, 0.4, 4.0), _tone(220.0, 0.8, 0.4, 3.0)], [0.0, 0.3, 0.6, 0.9])
		_: s = _tone(440.0, 0.1, 0.3, 20.0)
	return _make(s)

static func get_stream(name: String) -> AudioStreamWAV:
	if not cache.has(name):
		cache[name] = _synth(name)
	return cache[name]

# ---------------------------------------------------------------- playback
static func _throttled(name: String) -> bool:
	var now := Time.get_ticks_msec()
	if last_play.has(name) and now - int(last_play[name]) < 40:
		return true
	last_play[name] = now
	return false

static func play2d(parent: Node, name: String, vol_db: float = 0.0) -> void:
	if _throttled(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(name)
	p.volume_db = vol_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # UI / jingle sounds also play while the game is paused
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

static func play3d(parent: Node, name: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if _throttled(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(name)
	p.volume_db = vol_db
	p.unit_size = 10.0
	p.max_distance = 70.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

# Soft looping pad: Am - F - C - G, 2.5s per chord.
static func start_music(parent: Node) -> void:
	if music_player != null and is_instance_valid(music_player):
		return
	var rate := 11025
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [261.6, 329.6, 392.0], [196.0, 246.9, 293.7]]
	var seg := int(rate * 2.5)
	var samples := PackedFloat32Array()
	samples.resize(seg * chords.size())
	for ci in chords.size():
		for i in seg:
			var t := float(i) / rate
			var env := minf(t / 0.5, 1.0) * minf((2.5 - t) / 0.5, 1.0)
			var v := 0.0
			for f in chords[ci]:
				v += sin(TAU * f * t) * 0.12 + sin(TAU * f * 2.0 * t) * 0.03
			v += sin(TAU * chords[ci][0] * 0.5 * t) * 0.1
			samples[ci * seg + i] = v * env
	var w := _make(samples, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	music_player = AudioStreamPlayer.new()
	music_player.stream = w
	parent.add_child(music_player)
	update_music_volume()
	music_player.play()

static func update_music_volume() -> void:
	if music_player != null and is_instance_valid(music_player):
		music_player.volume_db = linear_to_db(maxf(Settings.music_vol, 0.0001)) - 6.0
