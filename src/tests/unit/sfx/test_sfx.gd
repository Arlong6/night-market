## GUT smoke tests for Sfx autoload (v0.3 audio pass).
##
## Audio output isn't asserted (headless can't hear). What we verify:
##   1. Each procedural stream was baked at startup
##   2. Streams are valid AudioStreamWAV instances with non-empty data
##   3. play_*() methods don't crash even under test_mode (silent path)
extends GutTest


func before_each() -> void:
	Game.test_mode = true   # silent path — _play() short-circuits


func after_each() -> void:
	Game.test_mode = false
	Sfx.muted = false


func test_sfx_bakes_all_streams_on_ready() -> void:
	# Streams are private (_bump etc); reach them via property names
	# so a future rename forces a test update too.
	# v0.32: 5 new streams (footstep / sizzle / page_flip / chime / denial).
	var stream_names: PackedStringArray = PackedStringArray([
		"_bump", "_pickup", "_buy", "_blip", "_win", "_choice",
		"_footstep", "_sizzle", "_page_flip", "_chime", "_denial",
	])
	for name in stream_names:
		var s: AudioStreamWAV = Sfx.get(name)
		assert_not_null(s, "Sfx.%s should be baked" % name)
		assert_gt(s.data.size(), 0,
			"Sfx.%s should have non-empty PCM data" % name)
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS,
			"Sfx.%s should be 16-bit PCM" % name)


func test_sfx_play_methods_are_safe_under_test_mode() -> void:
	# Under test_mode every _play short-circuits — should never throw.
	Sfx.play_bump()
	Sfx.play_pickup()
	Sfx.play_buy()
	Sfx.play_blip()
	Sfx.play_win()
	Sfx.play_choice()
	# v0.32 — texture / per-action SFX
	Sfx.play_footstep()
	Sfx.play_sizzle()
	Sfx.play_page_flip()
	Sfx.play_chime()
	Sfx.play_denial()
	assert_true(true, "All play_*() returned cleanly under test_mode")


func test_sfx_muted_flag_suppresses_output() -> void:
	Game.test_mode = false
	Sfx.muted = true
	# Should still not crash and not advance the player pool — this is the
	# only observable side-effect we can check headlessly.
	var before: int = Sfx._next_player
	Sfx.play_bump()
	assert_eq(Sfx._next_player, before,
		"muted=true should skip player rotation")


func test_sfx_polyphony_rotates_players() -> void:
	# Need real audio path for this — disable both gates.
	Game.test_mode = false
	Sfx.muted = false
	var start: int = Sfx._next_player
	for i in 5:
		Sfx.play_blip()
	# With POLYPHONY=4, after 5 plays we should have wrapped once.
	var expected: int = (start + 5) % Sfx._players.size()
	assert_eq(Sfx._next_player, expected,
		"player index should rotate by play count modulo POLYPHONY")
