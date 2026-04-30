## Procedural BGM autoload — bakes a looping pentatonic A-minor track at
## startup and hands it to a single AudioStreamPlayer with LOOP_FORWARD.
##
## Style: 廟口 / 夜市 vibe — pentatonic melody (A C D E G) with a soft A2
## drone underneath. 4 bars × 8 eighth notes at 100 BPM = 9.6s per cycle.
##
## Sits at -10 dB so SFX from sfx.gd cuts through cleanly.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SAMPLE_RATE: int = 22050
const VOLUME_DB: float = -10.0

const BPM: float = 100.0
const NOTE_DRONE: float = 110.0  ## A2

# Pentatonic A minor scale notes (Hz). Sticking to 5 pitches keeps it tonal
# and forgiving — any sequence of these "works" musically.
const N_A4: float = 440.0
const N_C5: float = 523.25
const N_D5: float = 587.33
const N_E5: float = 659.25
const N_G5: float = 783.99
const N_A5: float = 880.0
const N_G4: float = 392.0

## 4 bars × 8 eighth notes = 32 melody slots.
const MELODY: Array[float] = [
	# Bar 1 — climb pentatonic, descend
	N_A4, N_C5, N_D5, N_E5, N_G5, N_E5, N_D5, N_C5,
	# Bar 2 — push to high A
	N_A4, N_D5, N_E5, N_G5, N_A5, N_G5, N_E5, N_D5,
	# Bar 3 — settle from G4
	N_G4, N_A4, N_C5, N_D5, N_E5, N_D5, N_C5, N_A4,
	# Bar 4 — close back to root
	N_A4, N_C5, N_D5, N_E5, N_D5, N_C5, N_A4, N_G4,
]

## v0.32 — slow bedroom lullaby. Half-speed of the market loop, sparser
## (a third of the slots are rests — float 0.0), simpler shape. Same
## pentatonic scale so it stays in the same musical world.
const LULLABY_BPM: float = 50.0
const LULLABY_DRONE: float = 110.0  # A2, same as market
const LULLABY: Array[float] = [
	N_A4, 0.0,  N_C5, 0.0,  N_D5, 0.0,  N_E5, 0.0,
	N_C5, 0.0,  N_A4, 0.0,  N_G4, 0.0,  N_A4, 0.0,
]
const LULLABY_VOLUME_DB: float = -16.0  ## quieter than market

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _stream: AudioStreamWAV
var _lullaby_stream: AudioStreamWAV
var _player: AudioStreamPlayer

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_stream = _bake_market_loop()
	_lullaby_stream = _bake_lullaby_loop()
	print("[Music] ready — market loop %d samples, lullaby %d samples" % [
		_stream.data.size() / 2, _lullaby_stream.data.size() / 2,
	])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Starts the market loop if not already playing the same track.
func play_market() -> void:
	if _is_test_mode():
		return
	if _player == null or _stream == null:
		return
	if _player.playing and _player.stream == _stream:
		return
	_player.stream = _stream
	_player.play()


## v0.32: starts the bedroom lullaby loop at -16 dB. Same player as the
## market loop, so swapping scenes naturally takes over from each other.
func play_lullaby() -> void:
	if _is_test_mode():
		return
	if _player == null or _lullaby_stream == null:
		return
	if _player.playing and _player.stream == _lullaby_stream:
		return
	_player.stream = _lullaby_stream
	# Lullaby plays softer than the market loop — set the volume on the
	# player itself rather than swapping the bus; mute is still respected
	# because set_muted() drops to -80 dB regardless.
	_player.volume_db = LULLABY_VOLUME_DB
	_player.play()


## Stops any current track. Safe to call when nothing is playing.
## v0.32: also resets player volume so the next play_market() starts at
## the standard VOLUME_DB rather than the lullaby's softer setting.
func stop() -> void:
	if _player != null:
		_player.stop()
		_player.volume_db = VOLUME_DB


## v0.12: applied by HiScore on startup + on M-key toggle. Mutes by dropping
## the bus volume to -80 dB; un-mutes restores VOLUME_DB.
func set_muted(muted: bool) -> void:
	if _player == null:
		return
	_player.volume_db = -80.0 if muted else VOLUME_DB


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _is_test_mode() -> bool:
	var g: Node = get_node_or_null("/root/Game")
	return g != null and bool(g.get("test_mode"))


## Plucky envelope per note — quick attack, exponential decay.
func _pluck_env(u: float) -> float:
	if u < 0.02:
		return u / 0.02
	var d: float = (u - 0.02) / 0.98
	return pow(1.0 - d, 1.4)


func _bake_market_loop() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BPM
	var eighth: float = beat_dur / 2.0
	var n_per_eighth: int = int(eighth * SAMPLE_RATE)
	var total_samples: int = n_per_eighth * MELODY.size()

	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	# Phases accumulate continuously across notes for waveform smoothness.
	# 110Hz drone × 9.6s = 1056 cycles (integer) → loop seam phase-aligned.
	var melody_phase: float = 0.0
	var drone_phase: float = 0.0

	for note_idx in MELODY.size():
		var freq: float = MELODY[note_idx]
		for i in n_per_eighth:
			var u: float = float(i) / float(n_per_eighth)
			var env: float = _pluck_env(u)
			melody_phase += TAU * freq / float(SAMPLE_RATE)
			drone_phase += TAU * NOTE_DRONE / float(SAMPLE_RATE)
			# Triangle melody (warmer than sine via arcsin trick)
			var m: float = (2.0 / PI) * asin(sin(melody_phase))
			# Sine drone (smoother low end)
			var d: float = sin(drone_phase)
			var s: float = m * 0.4 * env + d * 0.28
			var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
			var idx: int = (note_idx * n_per_eighth + i) * 2
			bytes.encode_s16(idx, sample)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	# Loop the whole baked region — the drone cycle is integer so seams smooth.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream


## v0.32: slow lullaby loop for the bedroom scene. Half-speed of the
## market track, sparse rests (entries with freq=0.0), and a softer pluck
## envelope. Drone stays the same A2 so transitioning between rooms feels
## tonally connected.
func _bake_lullaby_loop() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / LULLABY_BPM
	var eighth: float = beat_dur / 2.0
	var n_per_eighth: int = int(eighth * SAMPLE_RATE)
	var total_samples: int = n_per_eighth * LULLABY.size()

	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)

	var melody_phase: float = 0.0
	var drone_phase: float = 0.0

	for note_idx in LULLABY.size():
		var freq: float = LULLABY[note_idx]
		var rest: bool = freq <= 0.0
		for i in n_per_eighth:
			var u: float = float(i) / float(n_per_eighth)
			# Slower attack on the lullaby — longer attack ramp = softer feel.
			var env: float = _lullaby_env(u)
			drone_phase += TAU * LULLABY_DRONE / float(SAMPLE_RATE)
			var m: float = 0.0
			if not rest:
				melody_phase += TAU * freq / float(SAMPLE_RATE)
				m = (2.0 / PI) * asin(sin(melody_phase))
			var d: float = sin(drone_phase)
			# Lullaby mixes softer overall + heavier on the drone for "sleepy"
			var s: float = m * 0.28 * env + d * 0.22
			var sample: int = int(clampf(s, -1.0, 1.0) * 32767.0)
			var idx: int = (note_idx * n_per_eighth + i) * 2
			bytes.encode_s16(idx, sample)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream


## Slow attack/decay envelope — softer than the market loop's pluck.
## 15% attack, gentle exponential decay across remaining 85%.
func _lullaby_env(u: float) -> float:
	if u < 0.15:
		return u / 0.15
	var d: float = (u - 0.15) / 0.85
	return pow(1.0 - d, 1.1)
