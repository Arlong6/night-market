extends GutTest

const RRAudio = preload("res://scripts/rr_audio.gd")

func test_impact_stream_valid() -> void:
	var s: AudioStreamWAV = RRAudio._make_impact()
	assert_true(s != null and s.data.size() > 0 and s.format == AudioStreamWAV.FORMAT_16_BITS)

func test_explosion_stream_valid() -> void:
	var s: AudioStreamWAV = RRAudio._make_explosion()
	assert_true(s != null and s.data.size() > 0)

func test_siren_stream_valid() -> void:
	var s: AudioStreamWAV = RRAudio._make_siren()
	assert_true(s != null and s.data.size() > 0)
