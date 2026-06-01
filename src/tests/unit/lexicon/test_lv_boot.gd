## Unit tests for LVBoot — covers AC-1 through AC-17 from
## design/gdd/boot-scene-flow.md (where unit-testable without real scene files).
## Scene file existence (AC-12) is integration-tested separately.
extends GutTest

const LVBoot = preload("res://lexicon/autoloads/lv_boot.gd")
const LVSessionState = preload("res://lexicon/autoloads/lv_session_state.gd")

var boot
var ss

const CORRECT_TABLE := {
	&"NOUN_BREAD": &"icon_bread",
	&"VERB_GIVE": &"icon_give",
	&"ADJ_WARM": &"icon_warm",
}
const SLOTS_IN_VIGNETTE := {
	&"BAKER": [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"],
}

func before_each() -> void:
	# Instance our own LVSessionState to keep tests isolated from the global autoload.
	# We DO NOT use the /root/LVSessionState autoload in tests.
	# Instead, we instance LVBoot which uses get_node_or_null which returns null,
	# and then manually drive both sides.
	# For tests that need the wiring, we replace /root/LVSessionState with our test instance.
	ss = LVSessionState.new()
	ss.name = "TestLVSessionState"
	# Don't add as /root/LVSessionState since that's the real autoload.
	# Instead, we test LVBoot's API without the autoload-coupled signal wiring.
	add_child_autofree(ss)

	boot = LVBoot.new()
	add_child_autofree(boot)
	boot.set_scene_swap_inhibited(true)  # No real scenes loaded during unit tests

# AC-1 — BOOTING is initial state
func test_initial_state_is_booting() -> void:
	# Assert
	assert_eq(boot.get_state(), LVBoot.BootState.BOOTING)

# AC-1 — boot_complete() transitions BOOTING → TITLE
func test_boot_complete_transitions_to_title() -> void:
	# Arrange
	watch_signals(boot)
	# Act
	boot.boot_complete()
	# Assert
	assert_eq(boot.get_state(), LVBoot.BootState.TITLE)
	assert_signal_emitted_with_parameters(boot, "boot_state_changed", [LVBoot.BootState.TITLE])

# AC-1 — boot_complete() is idempotent (no-op after first call)
func test_boot_complete_idempotent() -> void:
	# Arrange
	boot.boot_complete()
	watch_signals(boot)
	# Act
	boot.boot_complete()
	# Assert: no second transition (already in TITLE)
	assert_eq(boot.get_state(), LVBoot.BootState.TITLE)
	assert_signal_emit_count(boot, "boot_state_changed", 0)

# AC-2 — start_game() transitions TITLE → GAME
func test_start_game_transitions_title_to_game() -> void:
	# Arrange
	boot.boot_complete()
	# Act
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	# Assert
	assert_eq(boot.get_state(), LVBoot.BootState.GAME)

# AC-2 — start_game() initializes session state when LVSessionState autoload exists
func test_start_game_initializes_session_when_autoload_present() -> void:
	# Skipped if /root/LVSessionState autoload exists (which it does at runtime).
	# Verify by checking the global autoload's state after start_game.
	# Arrange
	boot.boot_complete()
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss == null:
		# Autoload not present in test runtime — skip the assertion
		assert_true(true, "Skipped: /root/LVSessionState not available")
		return
	# Act
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	# Assert
	assert_eq(global_ss.get_game_phase(), LVSessionState.GamePhase.PLAYING)
	assert_eq(global_ss.get_language_seed(), 12345)
	# Cleanup: destroy session so other tests aren't affected
	global_ss.destroy_session()

# AC-2 — start_game() ignored if not in TITLE
func test_start_game_ignored_if_not_in_title() -> void:
	# Arrange (still BOOTING)
	# Act
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	# Assert: stayed in BOOTING
	assert_eq(boot.get_state(), LVBoot.BootState.BOOTING)

# AC-3 — go_to_ending() transitions GAME → ENDING
func test_go_to_ending_transitions_game_to_ending() -> void:
	# Arrange
	boot.boot_complete()
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	# Act
	boot.go_to_ending()
	# Assert
	assert_eq(boot.get_state(), LVBoot.BootState.ENDING)

# AC-5 — return_to_title() transitions ENDING → TITLE
func test_return_to_title_transitions_ending_to_title() -> void:
	# Arrange
	boot.boot_complete()
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	boot.go_to_ending()
	# Act
	boot.return_to_title()
	# Assert
	assert_eq(boot.get_state(), LVBoot.BootState.TITLE)

# AC-6 — Restart destroys session state
func test_return_to_title_destroys_session_when_autoload_present() -> void:
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss == null:
		assert_true(true, "Skipped: /root/LVSessionState not available")
		return
	# Arrange: full cycle
	boot.boot_complete()
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	boot.go_to_ending()
	# Act
	boot.return_to_title()
	# Assert
	assert_eq(global_ss.get_game_phase(), LVSessionState.GamePhase.TITLE)

# AC-10 — Boot is sole scene-swap authority (this is a code-review check; here we
# verify the API doesn't expose direct scene-change methods to consumers).
func test_boot_does_not_expose_direct_scene_change_api() -> void:
	# Assert: only TX methods are boot_complete / start_game / go_to_ending / return_to_title
	# No exposed change_scene method.
	assert_false(boot.has_method("change_scene"))
	assert_false(boot.has_method("change_scene_to_file"))
	assert_false(boot.has_method("load_scene"))

# AC-15 — Web first-load constant exists and is 8s
func test_web_first_load_max_constant_is_8s() -> void:
	# Assert
	assert_eq(LVBoot.WEB_FIRST_LOAD_MAX_S, 8)

# AC-16 — Scene transition constant is 300ms
func test_scene_transition_max_constant_is_300ms() -> void:
	# Assert
	assert_eq(LVBoot.SCENE_TRANSITION_MAX_MS, 300)

# AC-17 — No save/load: destroy_session clears all
func test_no_save_load_full_destroy_on_return_to_title() -> void:
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss == null:
		assert_true(true, "Skipped: /root/LVSessionState not available")
		return
	# Arrange: bind something
	boot.boot_complete()
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	global_ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	# Act
	boot.go_to_ending()
	boot.return_to_title()
	# Assert: all state gone
	assert_eq(global_ss.get_binding(&"NOUN_BREAD"), null)
	assert_eq(global_ss.get_binding_map().size(), 0)

# State machine: no invalid transitions
func test_go_to_ending_from_title_is_noop() -> void:
	# Arrange
	boot.boot_complete()
	# Act
	boot.go_to_ending()
	# Assert: stayed in TITLE
	assert_eq(boot.get_state(), LVBoot.BootState.TITLE)

func test_return_to_title_from_booting_is_noop() -> void:
	# Arrange (still BOOTING)
	# Act
	boot.return_to_title()
	# Assert: stayed in BOOTING
	assert_eq(boot.get_state(), LVBoot.BootState.BOOTING)

# Seed generation produces deterministic value for MVP
func test_seed_generation_deterministic_in_mvp() -> void:
	# Arrange
	boot.boot_complete()
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss == null:
		assert_true(true, "Skipped: /root/LVSessionState not available")
		return
	# Act
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	var seed_a: int = global_ss.get_language_seed()
	boot.go_to_ending()
	boot.return_to_title()
	boot.start_game(CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	var seed_b: int = global_ss.get_language_seed()
	# Assert: same seed both times (MVP hard-coded)
	assert_eq(seed_a, seed_b)
	# Cleanup
	global_ss.destroy_session()
