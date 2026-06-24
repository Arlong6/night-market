## LVSfx — Lightweight procedural SFX provider for Lexicon Village.
##
## Generates short tones at runtime (no asset bundling required) for:
##   click()        — small percussive thump when clicking an NPC
##   match_correct() — bright two-tone ding when player places correct icon
##   match_wrong()  — soft downward blip when placing wrong icon
##
## All sounds are mono 22050Hz AudioStreamWAV, cached on first use.
## Auto-loaded as singleton "LVSfx" so anything can call:
##   LVSfx.click()  or  LVSfx.match_correct()
class_name LVSfx
extends Node

const SAMPLE_RATE: int = 22050

static var _click_stream: AudioStreamWAV = null
static var _match_correct_stream: AudioStreamWAV = null
static var _match_wrong_stream: AudioStreamWAV = null

# ─── Public API ───────────────────────────────────────────────────────────────

## Play a tiny click thump (NPC tap, button press, etc.).
static func click(parent: Node) -> void:
	_play(parent, _get_click_stream(), -8.0)

## Play a bright two-tone ding for correct icon match.
static func match_correct(parent: Node) -> void:
	_play(parent, _get_match_correct_stream(), -4.0)

## Play a soft blip for wrong icon match.
static func match_wrong(parent: Node) -> void:
	_play(parent, _get_match_wrong_stream(), -8.0)

# ─── Internal ─────────────────────────────────────────────────────────────────

static func _play(parent: Node, stream: AudioStream, db: float = -6.0) -> void:
	if parent == null or stream == null or not is_instance_valid(parent):
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ─── Stream factories (cached) ────────────────────────────────────────────────

static func _get_click_stream() -> AudioStreamWAV:
	if _click_stream == null:
		_click_stream = _make_click()
	return _click_stream

static func _get_match_correct_stream() -> AudioStreamWAV:
	if _match_correct_stream == null:
		_match_correct_stream = _make_match_correct()
	return _match_correct_stream

static func _get_match_wrong_stream() -> AudioStreamWAV:
	if _match_wrong_stream == null:
		_match_wrong_stream = _make_match_wrong()
	return _match_wrong_stream

## Click — fast attack, very short, mid-frequency thump.
static func _make_click() -> AudioStreamWAV:
	var dur := 0.08
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		# Decay envelope
		var env: float = pow(1.0 - t / dur, 1.5)
		# Mix two tones for "thump" feel
		var s: float = (sin(t * TAU * 380.0) * 0.6 + sin(t * TAU * 520.0) * 0.3) * env * 0.45
		_write_sample(data, i, s)
	return _wrap(data)

## Match-correct — bright two-tone "ding-dong" with quick decay.
static func _make_match_correct() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	# Two-note arpeggio: 880Hz then 1320Hz at t=0.15
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var s: float = 0.0
		# First note
		if t < 0.18:
			var env1: float = _envelope_short(t, 0.18)
			s += sin(t * TAU * 880.0) * env1 * 0.5
		# Second note (starts at 0.13s, overlaps slightly)
		if t >= 0.13:
			var t2: float = t - 0.13
			var env2: float = _envelope_short(t2, 0.22)
			s += sin(t2 * TAU * 1320.0) * env2 * 0.5
		# Harmonic for richness
		s += sin(t * TAU * 1760.0) * (1.0 - t / dur) * 0.08
		_write_sample(data, i, s * 0.85)
	return _wrap(data)

## Match-wrong — short downward blip (low-pitched, sad).
static func _make_match_wrong() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		# Pitch slides down 440 → 280 Hz
		var freq: float = lerp(440.0, 280.0, t / dur)
		var env: float = _envelope_short(t, dur)
		var s: float = sin(t * TAU * freq) * env * 0.45
		_write_sample(data, i, s)
	return _wrap(data)

# ─── Helpers ──────────────────────────────────────────────────────────────────

static func _envelope_short(t: float, dur: float) -> float:
	# Quick attack + linear decay
	var attack := 0.01
	if t < attack:
		return t / attack
	return max(0.0, 1.0 - (t - attack) / (dur - attack))

static func _write_sample(data: PackedByteArray, idx: int, sample_f: float) -> void:
	var s: int = int(clampf(sample_f, -1.0, 1.0) * 32767.0)
	if s < 0:
		s += 65536
	data[idx * 2] = s & 0xFF
	data[idx * 2 + 1] = (s >> 8) & 0xFF

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
