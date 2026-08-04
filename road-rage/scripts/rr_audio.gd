## RRAudio — procedural SFX for 橫衝直撞 (impact crunch, explosion, siren).
## Web-safe: only ever played from a user-caused event.
class_name RRAudio
extends RefCounted

const SAMPLE_RATE: int = 22050
static var _impact: AudioStreamWAV = null
static var _explosion: AudioStreamWAV = null
static var _siren: AudioStreamWAV = null
static var _gunshot: AudioStreamWAV = null
static var _scream: AudioStreamWAV = null
static var _fanfare: AudioStreamWAV = null
static var _buzz: AudioStreamWAV = null

static func impact(parent: Node, force: float) -> void:
	if _impact == null: _impact = _make_impact()
	var db: float = lerpf(-14.0, -2.0, clampf(force / 1500.0, 0.0, 1.0))
	_play(parent, _impact, db)

static func explosion(parent: Node) -> void:
	if _explosion == null: _explosion = _make_explosion()
	_play(parent, _explosion, -3.0)

static func siren(parent: Node) -> void:
	if _siren == null: _siren = _make_siren()
	_play(parent, _siren, -10.0)

static func gunshot(parent: Node, pitch: float = 1.0) -> void:
	if _gunshot == null: _gunshot = _make_gunshot()
	_play(parent, _gunshot, -7.0, pitch)

## A panicked pedestrian yelp. `pitch` varies per ped so a crowd doesn't sound cloned.
static func scream(parent: Node, pitch: float = 1.0) -> void:
	if _scream == null: _scream = _make_scream()
	_play(parent, _scream, -13.0, pitch)

## Rising arpeggio — mission complete.
static func fanfare(parent: Node) -> void:
	if _fanfare == null: _fanfare = _make_fanfare()
	_play(parent, _fanfare, -8.0)

## Low descending double-buzz — mission failed.
static func buzz(parent: Node) -> void:
	if _buzz == null: _buzz = _make_buzz()
	_play(parent, _buzz, -10.0)

static func _play(parent: Node, stream: AudioStream, db: float, pitch: float = 1.0) -> void:
	if parent == null or stream == null or not is_instance_valid(parent): return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Crunchy noise burst with a low thump.
static func _make_impact() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var seed_v := 12345
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 1.8)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(seed_v) / 1073741823.0) - 1.0
		var thump: float = sin(t * TAU * lerpf(150.0, 70.0, t / dur))
		_w(data, i, (noise * 0.5 + thump * 0.5) * env * 0.6)
	return _wrap(data)

# Longer, lower boom.
static func _make_explosion() -> AudioStreamWAV:
	var dur := 0.6
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var seed_v := 9876
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 1.3)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(seed_v) / 1073741823.0) - 1.0
		var boom: float = sin(t * TAU * lerpf(110.0, 40.0, t / dur))
		_w(data, i, (noise * 0.4 + boom * 0.6) * env * 0.7)
	return _wrap(data)

# Two-tone siren loop fragment.
static func _make_siren() -> AudioStreamWAV:
	var dur := 0.9
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var freq: float = 660.0 if fmod(t, 0.45) < 0.225 else 520.0
		_w(data, i, sin(t * TAU * freq) * 0.4)
	return _wrap(data)

# Loopable engine drone — low harmonic buzz. Caller loops it and shifts
# pitch_scale with speed for an acceleration sense. base 72Hz × 0.25s = 18
# whole cycles (and all partials are integer multiples) so the loop seam is clean.
static func make_engine_stream() -> AudioStreamWAV:
	var dur := 0.25
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var base := 72.0
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var s: float = sin(t * TAU * base) * 0.5
		s += sin(t * TAU * base * 2.0) * 0.24
		s += sin(t * TAU * base * 3.0) * 0.12
		s += sin(t * TAU * base * 0.5) * 0.16   # sub-octave growl
		_w(data, i, s * 0.5)
	var st := _wrap(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st

# A short rising arpeggio (C-E-G-C) with a bell envelope — success jingle.
static func _make_fanfare() -> AudioStreamWAV:
	var dur := 0.55
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var notes := [523.25, 659.25, 783.99, 1046.5]   # C5 E5 G5 C6
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var frac: float = t / dur
		var idx: int = clampi(int(frac * 4.0), 0, 3)
		var nf: float = notes[idx]
		var local: float = frac * 4.0 - float(idx)
		var env: float = pow(1.0 - local, 1.2) * (1.0 - frac * 0.2)
		var s: float = sin(t * TAU * nf) + 0.4 * sin(t * TAU * nf * 2.0)
		_w(data, i, s * env * 0.4)
	return _wrap(data)

# A low descending double-buzz — mission failed.
static func _make_buzz() -> AudioStreamWAV:
	var dur := 0.45
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var frac: float = t / dur
		var f: float = lerpf(200.0, 110.0, frac)
		var gate: float = 1.0 if fmod(t, 0.22) < 0.16 else 0.0
		var env: float = (1.0 - frac) * gate
		var s: float = signf(sin(t * TAU * f)) * 0.5 + sin(t * TAU * f) * 0.5
		_w(data, i, s * env * 0.4)
	return _wrap(data)

# A short startled yelp: pitch swoops up then sags, with vibrato + breath.
static func _make_scream() -> AudioStreamWAV:
	var dur := 0.42
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var seed_v := 2029
	var phase := 0.0
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var frac: float = t / dur
		var env: float = sin(frac * PI)                       # soft bell in/out
		var f: float = 300.0 + 300.0 * sin(frac * PI) + 28.0 * sin(t * TAU * 12.0)  # swoop + vibrato
		phase += f / SAMPLE_RATE
		var tone: float = sin(phase * TAU) + 0.3 * sin(phase * TAU * 2.0)  # a formant harmonic
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var breath: float = ((float(seed_v) / 1073741823.0) - 1.0) * 0.12
		_w(data, i, (tone * 0.85 + breath) * env * 0.5)
	return _wrap(data)

# Short sharp gunshot crack.
static func _make_gunshot() -> AudioStreamWAV:
	var dur := 0.12
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seed_v := 4242
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 2.5)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(seed_v) / 1073741823.0) - 1.0
		var crack: float = sin(t * TAU * lerpf(420.0, 120.0, t / dur))
		_w(data, i, (noise * 0.7 + crack * 0.3) * env * 0.8)
	return _wrap(data)

static func _w(data: PackedByteArray, idx: int, s: float) -> void:
	var v: int = int(clampf(s, -1.0, 1.0) * 32767.0)
	if v < 0: v += 65536
	data[idx * 2] = v & 0xFF
	data[idx * 2 + 1] = (v >> 8) & 0xFF

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SAMPLE_RATE
	st.stereo = false
	st.data = data
	return st
