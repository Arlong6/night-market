## GUT tests for SkyOverlay (v0.51 時段系統).
##
## Tests focus on the static phase / tint helpers — those are the contract
## consumed by lanterns_canvas + future systems, and they're trivially
## verifiable without spinning up the engine.
extends GutTest


func test_sky_overlay_phase_index_dusk_at_zero() -> void:
	# Arrange / Assert
	assert_eq(SkyOverlay.phase_index(0.0), 0,
		"phase 0 (黃昏) at session_time 0")


func test_sky_overlay_phase_index_dusk_just_before_boundary() -> void:
	# DUSK_END = 30. One tick before should still be 黃昏.
	assert_eq(SkyOverlay.phase_index(SkyOverlay.DUSK_END - 0.01), 0,
		"phase should still be 0 just before DUSK_END")


func test_sky_overlay_phase_index_night_at_dusk_end() -> void:
	assert_eq(SkyOverlay.phase_index(SkyOverlay.DUSK_END), 1,
		"phase should flip to 1 (夜晚) exactly at DUSK_END")


func test_sky_overlay_phase_index_late_night_after_night_end() -> void:
	assert_eq(SkyOverlay.phase_index(SkyOverlay.NIGHT_END + 1.0), 2,
		"phase should reach 2 (深夜) past NIGHT_END")


func test_sky_overlay_compute_tint_zero_alpha_at_zero() -> void:
	# t=0 → fully transparent (no overlay yet)
	var tint: Color = SkyOverlay.compute_tint(0.0)
	assert_almost_eq(tint.a, 0.0, 0.001,
		"tint at t=0 should be fully transparent")


func test_sky_overlay_compute_tint_dusk_peak() -> void:
	# At exactly DUSK_END the dusk ramp should sit at DUSK_PEAK_ALPHA.
	# (Phase has flipped to 1 but alpha lerp starts from same value.)
	var tint_just_before: Color = SkyOverlay.compute_tint(
		SkyOverlay.DUSK_END - 0.001
	)
	assert_almost_eq(
		tint_just_before.a, SkyOverlay.DUSK_PEAK_ALPHA, 0.005,
		"alpha just before DUSK_END should be ~DUSK_PEAK_ALPHA"
	)


func test_sky_overlay_compute_tint_night_peak_held() -> void:
	# Past NIGHT_END the alpha holds at NIGHT_PEAK regardless of how much
	# more time elapses (we don't keep darkening forever).
	var t1: Color = SkyOverlay.compute_tint(SkyOverlay.NIGHT_END + 5.0)
	var t2: Color = SkyOverlay.compute_tint(SkyOverlay.NIGHT_END + 500.0)
	assert_almost_eq(t1.a, SkyOverlay.NIGHT_PEAK_ALPHA, 0.001,
		"5s past NIGHT_END should be at peak alpha")
	assert_almost_eq(t2.a, SkyOverlay.NIGHT_PEAK_ALPHA, 0.001,
		"500s past NIGHT_END should still be at peak alpha (clamped)")


func test_sky_overlay_compute_tint_alpha_monotonically_non_decreasing() -> void:
	# Sample at several times; alpha must never go down between samples.
	var samples: Array[float] = [0.0, 5.0, 15.0, 29.0, 45.0, 89.0, 120.0]
	var prev_alpha: float = -1.0
	for t in samples:
		var a: float = SkyOverlay.compute_tint(t).a
		assert_true(a >= prev_alpha,
			"alpha at t=%.1f (%.3f) must be >= prev (%.3f)" % [t, a, prev_alpha])
		prev_alpha = a
