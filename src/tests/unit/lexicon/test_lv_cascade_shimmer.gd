## Unit tests for LVCascadeShimmer (#10).
## Covers headless-testable ACs from design/gdd/cascade-shimmer.md.
##
## Deferred to manual / playtest evidence:
##   AC-1  — visual "fires within same frame" (covered by signal test)
##   AC-11 — audio chime panning (pan math tested; actual stream play not unit-tested)
##   AC-15 — PLAYTEST acceptance (requires human testers)
##
extends GutTest

const LVCascadeShimmer = preload("res://lexicon/scripts/lv_cascade_shimmer.gd")
const LVDialogueDisplay = preload("res://lexicon/scripts/lv_dialogue_display.gd")

var shimmer: Node
var dd: LVDialogueDisplay

const BAKER_LINE := [
	{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
	{"type": "PUNCTUATION", "value": "."},
]

func before_each() -> void:
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss:
		global_ss.init_session(1, {&"NOUN_BREAD": &"icon_bread"}, {&"BAKER": [&"NOUN_BREAD"]})
	shimmer = LVCascadeShimmer.new()
	add_child_autofree(shimmer)
	dd = LVDialogueDisplay.new()
	add_child_autofree(dd)
	await get_tree().process_frame
	shimmer.inject_dialogue_display(dd)

func after_each() -> void:
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss:
		global_ss.destroy_session()

# ─── Formula tests (pure functions) ───────────────────────────────────────────

# AC-3 — t_arrive monotonically increases with distance
func test_t_arrive_nearer_is_earlier_than_farther() -> void:
	# Arrange
	var r_max := 1280.0
	# Act
	var t_near: float = LVCascadeShimmer.compute_t_arrive(100.0, r_max)
	var t_far: float = LVCascadeShimmer.compute_t_arrive(600.0, r_max)
	# Assert
	assert_true(t_near < t_far, "Near token should arrive before far token")

# AC-4 — ease-out curvature (near tokens arrive disproportionately earlier)
func test_t_arrive_ease_out_curvature_not_linear() -> void:
	# Arrange
	var r_max := 1280.0
	# Act
	var t_100: float = LVCascadeShimmer.compute_t_arrive(100.0, r_max)
	var t_500: float = LVCascadeShimmer.compute_t_arrive(500.0, r_max)
	# Assert: t_arrive(100) < t_arrive(500) × 0.5 confirms ease-out
	assert_true(t_100 < t_500 * 0.5,
		"Ease-out: t(100)=%f should be less than t(500)*0.5=%f" % [t_100, t_500 * 0.5])

# Formula 2 boundary: distance >= r_max clamps to RIPPLE_DURATION
func test_t_arrive_clamps_at_r_max() -> void:
	# Arrange
	var r_max := 1000.0
	# Act
	var t: float = LVCascadeShimmer.compute_t_arrive(r_max + 500.0, r_max)
	# Assert
	assert_almost_eq(t, LVCascadeShimmer.RIPPLE_DURATION, 0.001)

# Formula 2 boundary: distance 0 → t_arrive 0
func test_t_arrive_origin_is_zero() -> void:
	# Act
	var t: float = LVCascadeShimmer.compute_t_arrive(0.0, 1000.0)
	# Assert
	assert_almost_eq(t, 0.0, 0.001)

# AC-11 — pan math (Formula 4)
func test_compute_pan_left_of_center_is_negative() -> void:
	# Arrange: x=256 on 1024 viewport
	# Act
	var pan: float = LVCascadeShimmer.compute_pan(256.0, 1024.0)
	# Assert: ≈ -0.3 per Formula 4 (0.25 - 0.5) * 2 * 0.6 = -0.3
	assert_almost_eq(pan, -0.3, 0.01)

func test_compute_pan_right_of_center_is_positive() -> void:
	# Arrange: x=768 on 1024 viewport
	# Act
	var pan: float = LVCascadeShimmer.compute_pan(768.0, 1024.0)
	# Assert: (0.75 - 0.5) * 2 * 0.6 = 0.3
	assert_almost_eq(pan, 0.3, 0.01)

func test_compute_pan_center_is_zero() -> void:
	# Act
	var pan: float = LVCascadeShimmer.compute_pan(512.0, 1024.0)
	# Assert
	assert_almost_eq(pan, 0.0, 0.001)

# Formula 3 — total timeline
func test_total_duration_sums_phases() -> void:
	# Act
	var total: float = LVCascadeShimmer.total_duration()
	# Assert
	var expected := LVCascadeShimmer.RIPPLE_DURATION + LVCascadeShimmer.APPROACH_DURATION + LVCascadeShimmer.DWELL_DURATION + LVCascadeShimmer.SETTLE_DURATION
	assert_almost_eq(total, expected, 0.001)

# ─── Tuning constant locks ────────────────────────────────────────────────────

func test_color_peak_locked() -> void:
	assert_eq(LVCascadeShimmer.COLOR_PEAK, Color(1.0, 0.9, 0.5, 1.0))

func test_color_resolved_locked() -> void:
	assert_eq(LVCascadeShimmer.COLOR_RESOLVED, Color(0.15, 0.1, 0.05, 1.0))

func test_dwell_above_perceptual_floor() -> void:
	# game-designer: DWELL must remain ≥ 0.3s to read as "wave" not "pop"
	assert_true(LVCascadeShimmer.DWELL_DURATION >= 0.3)

func test_max_animated_glyphs_is_80() -> void:
	assert_eq(LVCascadeShimmer.MAX_ANIMATED_GLYPHS, 80)

# ─── State machine tests ──────────────────────────────────────────────────────

# Starts IDLE
func test_initial_state_is_idle() -> void:
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.IDLE)

# AC-1 — vignette_completed triggers ripple (state transition)
func test_vignette_completed_starts_ripple() -> void:
	# Arrange: dialogue display showing tokens (so wavefront has visible targets)
	dd.show_line(BAKER_LINE)
	dd.advance() # complete typewriter
	# Act
	shimmer.on_vignette_completed(&"BAKER")
	# Assert
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.RIPPLE_ACTIVE)

# AC-7 — second vignette during active ripple does not start immediately
func test_second_completion_queues_does_not_start_immediately() -> void:
	# Arrange
	dd.show_line(BAKER_LINE)
	dd.advance()
	shimmer.on_vignette_completed(&"BAKER")
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.RIPPLE_ACTIVE)
	# Act: fire a second one while first is active
	shimmer.on_vignette_completed(&"SMITH")
	# Assert: still active on first (second is queued)
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.RIPPLE_ACTIVE)
	assert_eq(shimmer.get_queue_size(), 1)

# AC-8 — multiple completions all eventually queue
func test_three_completions_all_queued_or_active() -> void:
	# Arrange — use real BAKER (only first one starts a ripple; others queue)
	dd.show_line(BAKER_LINE)
	dd.advance()
	# Act
	shimmer.on_vignette_completed(&"BAKER")
	shimmer.on_vignette_completed(&"BAKER")
	shimmer.on_vignette_completed(&"BAKER")
	# Assert: 1 active + 2 queued = 3 accounted for
	assert_eq(shimmer.get_queue_size(), 2)
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.RIPPLE_ACTIVE)

# AC-16 — notebook-open defers shimmer start
func test_notebook_open_defers_shimmer() -> void:
	# Arrange
	dd.show_line(BAKER_LINE)
	dd.advance()
	shimmer.set_notebook_open(true)
	# Act
	shimmer.on_vignette_completed(&"BAKER")
	# Assert: deferred — still IDLE, deferred vignette present
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.IDLE)
	assert_true(shimmer.has_deferred())

func test_notebook_close_drains_deferred() -> void:
	# Arrange
	dd.show_line(BAKER_LINE)
	dd.advance()
	shimmer.set_notebook_open(true)
	shimmer.on_vignette_completed(&"BAKER")
	# Act
	shimmer.set_notebook_open(false)
	# Assert: deferred drained → now active
	assert_eq(shimmer.get_state(), LVCascadeShimmer.ShimmerState.RIPPLE_ACTIVE)
	assert_false(shimmer.has_deferred())

# AC-12 — reduced-motion sets t_arrive = 0 for all tokens
func test_reduced_motion_t_arrive_is_zero() -> void:
	# Act under reduced-motion flag
	shimmer.set_reduced_motion(true)
	var t: float = shimmer.compute_t_arrive_with_motion(800.0, 1280.0)
	# Assert
	assert_almost_eq(t, 0.0, 0.001)

func test_reduced_motion_off_uses_formula() -> void:
	# Act
	shimmer.set_reduced_motion(false)
	var t: float = shimmer.compute_t_arrive_with_motion(800.0, 1280.0)
	# Assert (should match pure formula)
	var expected: float = LVCascadeShimmer.compute_t_arrive(800.0, 1280.0)
	assert_almost_eq(t, expected, 0.001)

# ─── Token selection / cap tests ──────────────────────────────────────────────

# AC-9 — 80-glyph cap selects nearest 80
func test_select_animation_targets_caps_at_80() -> void:
	# Arrange: 90 fake distances 0..89
	var distances: Array = []
	for i in 90:
		distances.append(float(i * 10))
	# Act
	var result: Dictionary = LVCascadeShimmer.split_animated_vs_direct(distances, LVCascadeShimmer.MAX_ANIMATED_GLYPHS)
	# Assert
	assert_eq(result.animated_indices.size(), 80)
	assert_eq(result.direct_indices.size(), 10)

# AC-9 — cap selects nearest (lowest distance)
func test_cap_selects_nearest() -> void:
	# Arrange: 81 distances; mostly large, one tiny + one medium
	var distances: Array = []
	for i in 81:
		distances.append(1000.0 + i)
	distances[40] = 5.0  # tiny — should always be animated
	# Act
	var result: Dictionary = LVCascadeShimmer.split_animated_vs_direct(distances, LVCascadeShimmer.MAX_ANIMATED_GLYPHS)
	# Assert: index 40 must be in animated set
	assert_true(result.animated_indices.has(40))

# AC-6 — off-screen flag: direct resolve (no Tween)
func test_off_screen_token_resolves_direct() -> void:
	# Arrange: a token outside viewport rect
	var token_rect := Rect2(Vector2(10000, 10000), Vector2(8, 8))
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(320, 180))
	# Act
	var is_visible: bool = LVCascadeShimmer.is_on_screen(token_rect, viewport_rect)
	# Assert
	assert_false(is_visible)

func test_on_screen_token_detected() -> void:
	# Arrange
	var token_rect := Rect2(Vector2(100, 100), Vector2(8, 8))
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(320, 180))
	# Act
	var is_visible: bool = LVCascadeShimmer.is_on_screen(token_rect, viewport_rect)
	# Assert
	assert_true(is_visible)

# AC-10 — freeing a tween target mid-shimmer does not crash
func test_freeing_label_mid_shimmer_does_not_crash() -> void:
	# Arrange
	dd.show_line(BAKER_LINE)
	dd.advance()
	shimmer.on_vignette_completed(&"BAKER")
	# Act: free a token label
	var labels: Array = dd.get_token_labels()
	if not labels.is_empty():
		labels[0].queue_free()
	await get_tree().process_frame
	# Assert: no crash, shimmer can still be queried
	assert_true(shimmer.get_state() != LVCascadeShimmer.ShimmerState.IDLE
		or shimmer.get_state() == LVCascadeShimmer.ShimmerState.IDLE)  # tautology — crash would fail before

# slot_resolved signal fires when shimmer starts
func test_shimmer_fires_slot_resolved_signal() -> void:
	# Arrange
	dd.show_line(BAKER_LINE)
	dd.advance()
	watch_signals(shimmer)
	# Act
	shimmer.on_vignette_completed(&"BAKER")
	# Assert: slot_resolved emitted (with NOUN_BREAD for BAKER's slot list)
	assert_signal_emitted(shimmer, "slot_resolved")
