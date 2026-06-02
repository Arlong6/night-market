## LVChime — Lexicon Village procedural chime generator
##
## Generates a soft, slow-attack chime as AudioStreamWAV at runtime. Used by
## #10 Cascade Shimmer to play a single panned chime per ripple.
##
## Per cascade-shimmer.md anti-patterns: NO percussive transient, pure tone
## with slow attack. The chime must read as "warmth" not "achievement ding".
##
## Default tone: 880Hz (A5) — chosen for clarity above NPC mid-range without
## stridency. Envelope: 0.15s attack, sustain → gentle decay, 0.2s release.
class_name LVChime
extends RefCounted

const SAMPLE_RATE: int = 22050
const DURATION_SEC: float = 1.2
const ATTACK_SEC: float = 0.15
const RELEASE_SEC: float = 0.2
const TONE_HZ: float = 880.0
const PEAK_AMPLITUDE: float = 0.45  # avoid clipping, leave audio room for music bed

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
		var env: float = 0.0
		if t < ATTACK_SEC:
			# Smooth attack curve (ease-in-out via smoothstep-ish)
			var a: float = t / ATTACK_SEC
			env = a * a * (3.0 - 2.0 * a)
		elif t < sustain_end:
			# Gentle decay through sustain (1.0 → 0.6 across ~0.85s)
			var s: float = (t - ATTACK_SEC) / (sustain_end - ATTACK_SEC)
			env = 1.0 - s * 0.4
		else:
			# Release fade out
			var r: float = (t - sustain_end) / RELEASE_SEC
			env = 0.6 * (1.0 - r * r)
		var sample_f: float = sin(t * TAU * TONE_HZ) * env * PEAK_AMPLITUDE
		var sample_i: int = int(clampf(sample_f, -1.0, 1.0) * 32767.0)
		# Pack as little-endian int16
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
