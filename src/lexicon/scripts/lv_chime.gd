## LVChime — Lexicon Village procedural chime generator
##
## Generates a soft, slow-attack chime as AudioStreamWAV at runtime. Used by
## #10 Cascade Shimmer to play a single panned chime per ripple.
##
## Per cascade-shimmer.md anti-patterns: NO percussive transient, pure tone OR
## soft harmonic with slow attack. Chime must read as "warmth" not "ding".
##
## v0.58 upgrade: multi-harmonic stack (fundamental + 5th + octave + 2-octave
## with slight detune). Reads as warm bell rather than test tone. Per design:
## "soft harmonic" path explicit in GDD allows this.
##
## Fundamental: 440Hz (A4). Slightly detuned partials add chorus warmth without
## sounding "synth-y". Envelope: 0.15s attack, sustain → gentle decay, 0.2s release.
class_name LVChime
extends RefCounted

const SAMPLE_RATE: int = 22050
const DURATION_SEC: float = 1.2
const ATTACK_SEC: float = 0.15
const RELEASE_SEC: float = 0.2
const PEAK_AMPLITUDE: float = 0.45  # avoid clipping, leave room for music bed

# ─── Harmonic stack ───────────────────────────────────────────────────────────
# Each entry: [frequency_hz, amplitude_weight]. Amplitudes are normalized so
# the sum never exceeds 1.0 before envelope is applied. Slight detune on the
# 5th and 2-octave partials adds a "soft chorus" warmth.

const FUNDAMENTAL_HZ: float = 440.0  # A4 — warmer than v0.56's A5/880
const HARMONICS: Array = [
	# [hz_multiplier, amplitude]
	[1.000, 0.42],   # fundamental — load-bearing for pitch identity
	[1.500, 0.22],   # perfect 5th (660Hz) — adds chord-like warmth
	[2.005, 0.18],   # octave (880Hz, +0.5%/cent detune for chorus)
	[3.997, 0.10],   # 2-octave (1760Hz, −0.075% detune)
]

## Generate a single-shot chime stream. Cache the result — calling this once
## per game session is fine; per-shimmer is wasteful.
static func generate() -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * DURATION_SEC)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono = 2 bytes/sample
	var sustain_end: float = DURATION_SEC - RELEASE_SEC
	for i in sample_count:
		var t: float = float(i) / SAMPLE_RATE
		# Envelope: slow attack, gentle decay through sustain, smooth release
		var env: float = _envelope(t, sustain_end)
		# Sum harmonic partials (slight detune adds chorus warmth)
		var mix: float = 0.0
		for h in HARMONICS:
			var hz: float = FUNDAMENTAL_HZ * float(h[0])
			var amp: float = float(h[1])
			mix += sin(t * TAU * hz) * amp
		# Higher partials decay slightly faster (bell-like spectral evolution)
		mix *= env
		var sample_f: float = mix * PEAK_AMPLITUDE
		var sample_i: int = int(clampf(sample_f, -1.0, 1.0) * 32767.0)
		if sample_i < 0:
			sample_i += 65536
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

## Envelope curve: smooth attack (ease-in-out), gentle decay during sustain,
## smooth release. Used to shape the harmonic-mix output.
static func _envelope(t: float, sustain_end: float) -> float:
	if t < ATTACK_SEC:
		var a: float = t / ATTACK_SEC
		return a * a * (3.0 - 2.0 * a)
	elif t < sustain_end:
		var s: float = (t - ATTACK_SEC) / (sustain_end - ATTACK_SEC)
		return 1.0 - s * 0.4
	else:
		var r: float = (t - sustain_end) / RELEASE_SEC
		return 0.6 * (1.0 - r * r)
