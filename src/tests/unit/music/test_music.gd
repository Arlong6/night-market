## GUT smoke tests for Music autoload (v0.4 BGM pass).
extends GutTest


func before_each() -> void:
	Game.test_mode = true   # play_market short-circuits


func after_each() -> void:
	Game.test_mode = false
	Music.stop()


func test_music_bakes_market_loop_on_ready() -> void:
	var s: AudioStreamWAV = Music._stream
	assert_not_null(s, "Music._stream should be baked")
	assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_gt(s.data.size(), 0, "PCM data should not be empty")
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD,
		"Loop mode should be LOOP_FORWARD for seamless replay")
	assert_eq(s.loop_begin, 0)
	# loop_end is in samples — should match the byte length / 2 (16-bit mono).
	assert_eq(s.loop_end, s.data.size() / 2,
		"loop_end should cover the entire baked region")


func test_music_play_market_is_safe_under_test_mode() -> void:
	# Under test_mode play_market short-circuits; no crash.
	Music.play_market()
	assert_false(Music._player.playing,
		"player should NOT be playing when test_mode suppresses output")


func test_music_stop_is_idempotent() -> void:
	Music.stop()
	Music.stop()  # double-stop safe
	assert_false(Music._player.playing)


func test_music_loop_seam_phase_alignment() -> void:
	# 110Hz drone × 9.6s = 1056 cycles → loop endpoints land on integer cycles.
	# Verify the last few samples don't deviate wildly from the first.
	var s: AudioStreamWAV = Music._stream
	var n: int = s.data.size() / 2
	# Re-decode last sample and first sample as int16 from PackedByteArray.
	var first: int = s.data.decode_s16(0)
	var last: int = s.data.decode_s16((n - 1) * 2)
	# Both should be near zero because the pluck envelope decays to ~0 at
	# end of each note. Allow up to ±2000 (~6% of full scale).
	assert_lt(absi(first), 2000,
		"first sample should be near silence — got %d" % first)
	assert_lt(absi(last), 2000,
		"last sample should be near silence — got %d" % last)


# ---------------------------------------------------------------------------
# v0.32 — bedroom lullaby loop
# ---------------------------------------------------------------------------

func test_music_bakes_lullaby_loop_on_ready() -> void:
	# Arrange / Act
	var s: AudioStreamWAV = Music._lullaby_stream

	# Assert
	assert_not_null(s, "Music._lullaby_stream should be baked at startup")
	assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_gt(s.data.size(), 0, "lullaby PCM data should not be empty")
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD,
		"lullaby should LOOP_FORWARD for seamless playback")


func test_music_play_lullaby_is_safe_under_test_mode() -> void:
	# Arrange / Act — test_mode short-circuits play_lullaby like play_market
	Music.play_lullaby()

	# Assert
	assert_false(Music._player.playing,
		"player should NOT be playing when test_mode suppresses output")


func test_music_stop_resets_player_volume_for_next_track() -> void:
	# Arrange — simulate the lullaby having lowered the volume
	Music._player.volume_db = Music.LULLABY_VOLUME_DB

	# Act
	Music.stop()

	# Assert: stop() should restore the standard market volume so a later
	# play_market() doesn't accidentally inherit the lullaby's softer mix.
	assert_almost_eq(Music._player.volume_db, Music.VOLUME_DB, 0.01,
		"stop() should reset volume to VOLUME_DB — got %f"
		% Music._player.volume_db)
