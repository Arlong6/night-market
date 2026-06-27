## RRAudio — procedural SFX for 橫衝直撞 (impact crunch, explosion, siren).
## Web-safe: only ever played from a user-caused event.
class_name RRAudio
extends RefCounted

const SAMPLE_RATE: int = 22050
static var _impact: AudioStreamWAV = null
static var _explosion: AudioStreamWAV = null
static var _siren: AudioStreamWAV = null

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

static func _play(parent: Node, stream: AudioStream, db: float) -> void:
	if parent == null or stream == null or not is_instance_valid(parent): return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
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
