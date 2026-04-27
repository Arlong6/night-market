## Procedural SFX autoload for Night Market Shopping (v0.3 audio pass).
##
## No external audio assets — each beep is a short envelope-shaped sine /
## square / sweep generated into a PackedByteArray at startup and wrapped in
## an AudioStreamWAV. Cheap (~3KB total RAM) and ships zero binary blobs.
##
## A small pool of AudioStreamPlayers gives polyphony so fast back-to-back
## sounds (e.g. typewriter blips during a buy) don't cut each other off.
extends Node

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

const SAMPLE_RATE: int = 22050
const POLYPHONY: int = 4

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

var _bump: AudioStreamWAV
var _pickup: AudioStreamWAV
var _buy: AudioStreamWAV
var _blip: AudioStreamWAV
var _win: AudioStreamWAV
var _choice: AudioStreamWAV

## Test hook — disables actual playback (autoloads still bake the streams).
var muted: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	for i in POLYPHONY:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = 6.0   # +6dB headroom — 8-bit retro beeps need to cut through
		add_child(p)
		_players.append(p)
	# Loud, clearly-audible defaults. Each beep is short so peak amp can sit high.
	_bump = _make_tone(140.0, 0.10, "square", 0.95)
	_pickup = _make_sweep(500.0, 1400.0, 0.16, 0.85)
	_buy = _make_two_tone(660.0, 990.0, 0.22, 0.85)
	_blip = _make_tone(1400.0, 0.018, "square", 0.6)
	_win = _make_arpeggio([523.25, 659.25, 784.0, 1046.5], 0.13, 0.85)
	_choice = _make_tone(880.0, 0.05, "square", 0.6)
	print("[Sfx] ready — 6 streams baked, volume_db=+6")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play_bump() -> void: _play(_bump)
func play_pickup() -> void: _play(_pickup)
func play_buy() -> void: _play(_buy)
func play_blip() -> void: _play(_blip)
func play_win() -> void: _play(_win)
func play_choice() -> void: _play(_choice)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _play(stream: AudioStreamWAV) -> void:
	if muted or stream == null or _players.is_empty():
		return
	# Auto-suppress under test_mode so unit tests don't churn the audio bus.
	var game: Node = get_node_or_null("/root/Game")
	if game != null and bool(game.get("test_mode")):
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.play()


## Linear 5% attack, quadratic decay across the remaining 95%.
func _envelope(u: float) -> float:
	if u < 0.05:
		return u / 0.05
	var d: float = (u - 0.05) / 0.95
	return (1.0 - d) * (1.0 - d)


func _make_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo = false
	s.data = bytes
	return s


func _make_tone(freq: float, dur: float, shape: String, amp: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = _envelope(float(i) / float(n))
		var s: float
		match shape:
			"square":
				s = 1.0 if sin(TAU * freq * t) > 0.0 else -1.0
			"triangle":
				s = 2.0 * absf(2.0 * fposmod(t * freq, 1.0) - 1.0) - 1.0
			_:
				s = sin(TAU * freq * t)
		var sample: int = int(clampf(s * env * amp, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _make_stream(bytes)


func _make_sweep(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var u: float = float(i) / float(n)
		var freq: float = lerpf(f0, f1, u)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = _envelope(u)
		var s: float = sin(phase)
		var sample: int = int(clampf(s * env * amp, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _make_stream(bytes)


func _make_two_tone(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n: int = int(dur * SAMPLE_RATE)
	var split: int = n / 2
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = f0 if i < split else f1
		var u_local: float
		if i < split:
			u_local = float(i) / float(split)
		else:
			u_local = float(i - split) / float(n - split)
		var env: float = _envelope(u_local)
		var s: float = sin(TAU * freq * t)
		var sample: int = int(clampf(s * env * amp, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _make_stream(bytes)


func _make_arpeggio(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var note_n: int = int(note_dur * SAMPLE_RATE)
	var total: int = note_n * freqs.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total * 2)
	var phase: float = 0.0
	for ni in freqs.size():
		var freq: float = float(freqs[ni])
		for i in note_n:
			phase += TAU * freq / float(SAMPLE_RATE)
			var u: float = float(i) / float(note_n)
			var env: float = _envelope(u)
			var s: float = sin(phase)
			var idx: int = (ni * note_n + i) * 2
			var sample: int = int(clampf(s * env * amp, -1.0, 1.0) * 32767.0)
			bytes.encode_s16(idx, sample)
	return _make_stream(bytes)
