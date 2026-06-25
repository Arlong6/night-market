## WSAudio — procedural sound for 一字一句 (Word Suika).
##
## A merge game lives and dies on the satisfying merge "pop". This module
## synthesises every sound at runtime as AudioStreamWAV (no bundled assets),
## so the whole soundscape ships inside the code with zero download weight.
##
## Design intent (from the juice review):
##   - merge_pop() pitch RISES up the tier ladder, so a chain reaction plays an
##     ascending pentatonic run — the ear reads it as "you're winning".
##   - Low-tier merges are light & dry; high-tier merges are fuller & louder, so
##     there is dynamic range and the 詩 climax has somewhere to escalate to.
##   - drop_thock() acknowledges the player's click so dropping feels physical.
##   - poem_fanfare() is a held triumphant chord reserved for reaching 詩.
##
## WEB-SAFE: every sound only fires from a user gesture (a drop/merge that the
## click caused), never on _ready or a loop, so the browser autoplay gate is
## satisfied by the player's first click — sound is audible by the first merge.
##
## Pattern ported from Lexicon Village's lv_chime.gd / lv_sfx.gd.
class_name WSAudio
extends RefCounted

const SAMPLE_RATE: int = 22050

## Root note for the pitch ladder: C5 ≈ 523.25 Hz.
const ROOT_HZ: float = 523.25

## Semitone offset per tier (0..7) — a rising MAJOR PENTATONIC scale so any
## chain of merges sounds consonant and climbs musically (no dissonant clashes
## even on random cascades). 8 entries map 1:1 to the 8 tiers 雨..詩.
const TIER_SEMITONES: Array = [0, 2, 4, 7, 9, 12, 14, 16]

# Cached streams — generated once on first use, reused forever.
static var _merge_streams: Dictionary = {}   # tier:int -> AudioStreamWAV
static var _drop_stream: AudioStreamWAV = null
static var _fanfare_stream: AudioStreamWAV = null
static var _gameover_stream: AudioStreamWAV = null

# ─── Public API ─────────────────────────────────────────────────────────────

## Pop fired when two glyphs merge. `tier` is the tier of the NEW (larger)
## glyph — higher tier → higher pitch + fuller body.
static func merge_pop(parent: Node, tier: int) -> void:
	var t: int = clampi(tier, 0, TIER_SEMITONES.size() - 1)
	if not _merge_streams.has(t):
		_merge_streams[t] = _make_merge_pop(t)
	# Louder as we climb so big merges feel bigger (dynamic range).
	var db: float = lerpf(-12.0, -3.0, float(t) / float(TIER_SEMITONES.size() - 1))
	_play(parent, _merge_streams[t], db)

## Short dry "thock" acknowledging a drop/launch.
static func drop_thock(parent: Node) -> void:
	if _drop_stream == null:
		_drop_stream = _make_drop()
	_play(parent, _drop_stream, -10.0)

## Held triumphant chord — reserved for reaching 詩 (the "watermelon").
static func poem_fanfare(parent: Node) -> void:
	if _fanfare_stream == null:
		_fanfare_stream = _make_fanfare()
	_play(parent, _fanfare_stream, -2.0)

## Soft descending tone on game over.
static func game_over(parent: Node) -> void:
	if _gameover_stream == null:
		_gameover_stream = _make_gameover()
	_play(parent, _gameover_stream, -6.0)

# ─── Playback ───────────────────────────────────────────────────────────────

static func _play(parent: Node, stream: AudioStream, db: float) -> void:
	if parent == null or stream == null or not is_instance_valid(parent):
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ─── Stream synthesis ───────────────────────────────────────────────────────

## Merge pop: a quick percussive transient + a short tonal "bloop" at the
## tier's pitch. Higher tiers get a longer body and an added octave for weight.
static func _make_merge_pop(tier: int) -> AudioStreamWAV:
	var freq: float = ROOT_HZ * pow(2.0, float(TIER_SEMITONES[tier]) / 12.0)
	# Higher tiers ring a touch longer (0.14s → 0.26s).
	var dur: float = lerpf(0.14, 0.26, float(tier) / float(TIER_SEMITONES.size() - 1))
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	# Octave weight grows with tier for body on the big merges.
	var oct_amp: float = lerpf(0.05, 0.30, float(tier) / float(TIER_SEMITONES.size() - 1))
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 1.6)   # fast attack, exp-ish decay
		# A short upward pitch blip in the first 25ms gives the "pop" snap.
		var blip: float = 1.0 + 0.18 * maxf(0.0, 1.0 - t / 0.025)
		var s: float = sin(t * TAU * freq * blip) * 0.6
		s += sin(t * TAU * freq * 2.0) * oct_amp        # octave for weight
		s += sin(t * TAU * freq * 0.5) * 0.10            # sub for thump
		_write_sample(data, i, s * env * 0.5)
	return _wrap(data)

## Drop thock: very short, low, woody — no clear pitch, just a tap.
static func _make_drop() -> AudioStreamWAV:
	var dur: float = 0.07
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 2.0)
		# Pitch drops 220→140 for a soft wooden knock.
		var freq: float = lerpf(220.0, 140.0, t / dur)
		var s: float = (sin(t * TAU * freq) * 0.7 + sin(t * TAU * freq * 1.5) * 0.2)
		_write_sample(data, i, s * env * 0.5)
	return _wrap(data)

## Poem fanfare: a held major triad (root + 3rd + 5th + octave) with a warm
## slow-ish attack and gentle release — the peak of the run.
static func _make_fanfare() -> AudioStreamWAV:
	var dur: float = 0.95
	var attack: float = 0.04
	var release: float = 0.30
	var sustain_end: float = dur - release
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	# C major triad above the root, plus the octave for shine.
	var partials: Array = [
		[1.000, 0.34],                       # root
		[pow(2.0, 4.0 / 12.0), 0.26],        # major 3rd
		[pow(2.0, 7.0 / 12.0), 0.24],        # perfect 5th
		[2.000, 0.16],                       # octave
	]
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 0.0
		if t < attack:
			var a: float = t / attack
			env = a * a * (3.0 - 2.0 * a)
		elif t < sustain_end:
			env = 1.0 - (t - attack) / (sustain_end - attack) * 0.25
		else:
			var r: float = (t - sustain_end) / release
			env = 0.75 * (1.0 - r * r)
		var mix: float = 0.0
		for p in partials:
			mix += sin(t * TAU * ROOT_HZ * float(p[0])) * float(p[1])
		_write_sample(data, i, mix * env * 0.5)
	return _wrap(data)

## Game over: a soft two-step descending tone (gentle, not punishing).
static func _make_gameover() -> AudioStreamWAV:
	var dur: float = 0.6
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - t / dur, 1.3)
		# Step down: 392Hz (G4) for first half, 294Hz (D4) for second.
		var freq: float = 392.0 if t < dur * 0.45 else 294.0
		var s: float = sin(t * TAU * freq) * 0.5 + sin(t * TAU * freq * 2.0) * 0.12
		_write_sample(data, i, s * env * 0.45)
	return _wrap(data)

# ─── Helpers ────────────────────────────────────────────────────────────────

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
