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

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _stream: AudioStreamWAV
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
	print("[Music] ready — market loop baked (%d samples, %.2fs)" %
		[_stream.data.size() / 2, float(_stream.data.size() / 2) / SAMPLE_RATE])


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


## Stops any current track. Safe to call when nothing is playing.
func stop() -> void:
	if _player != null:
		_player.stop()


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
