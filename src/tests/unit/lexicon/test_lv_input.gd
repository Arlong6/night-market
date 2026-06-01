## Unit tests for LVInput — covers AC-1, AC-2, AC-3, AC-5, AC-6, AC-10, AC-14, AC-16, AC-17 from
## design/gdd/input-system.md (where unit-testable in isolation; mouse drag/keyboard event
## injection is integration-level and deferred).
extends GutTest

const LVInput = preload("res://lexicon/autoloads/lv_input.gd")

var inp

func before_each() -> void:
	inp = LVInput.new()
	add_child_autofree(inp)
	inp.set_state(LVInput.InputState.NORMAL)
	inp.set_reduced_motion(false)

# AC-1 — NPC interaction emits signal only in NORMAL state
func test_request_npc_interaction_in_normal_fires_signal() -> void:
	# Arrange
	watch_signals(inp)
	# Act
	inp.request_npc_interaction(&"baker")
	# Assert
	assert_signal_emitted_with_parameters(inp, "npc_interaction_requested", [&"baker"])

# Phase gate: NPC interaction rejected outside NORMAL
func test_request_npc_interaction_in_notebook_open_no_signal() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.NOTEBOOK_OPEN)
	watch_signals(inp)
	# Act
	inp.request_npc_interaction(&"baker")
	# Assert
	assert_signal_emit_count(inp, "npc_interaction_requested", 0)

# AC-3 — Slot assignment fires in NOTEBOOK_OPEN
func test_emit_slot_assignment_in_notebook_open() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.NOTEBOOK_OPEN)
	watch_signals(inp)
	# Act
	inp.emit_slot_assignment(&"NOUN_BREAD", &"icon_bread")
	# Assert
	assert_signal_emitted_with_parameters(inp, "slot_assignment_changed", [&"NOUN_BREAD", &"icon_bread"])

# AC-3 — Slot assignment fires in ICON_SELECTED
func test_emit_slot_assignment_in_icon_selected() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.ICON_SELECTED)
	watch_signals(inp)
	# Act
	inp.emit_slot_assignment(&"NOUN_BREAD", &"icon_bread")
	# Assert
	assert_signal_emitted(inp, "slot_assignment_changed")

# AC-6 — Slot assignment rejected outside binding states
func test_emit_slot_assignment_in_normal_no_signal() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.NORMAL)
	watch_signals(inp)
	# Act
	inp.emit_slot_assignment(&"NOUN_BREAD", &"icon_bread")
	# Assert
	assert_signal_emit_count(inp, "slot_assignment_changed", 0)

# AC-6 — Slot assignment rejected during CUTSCENE
func test_emit_slot_assignment_in_cutscene_no_signal() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.CUTSCENE)
	watch_signals(inp)
	# Act
	inp.emit_slot_assignment(&"NOUN_BREAD", &"icon_bread")
	# Assert
	assert_signal_emit_count(inp, "slot_assignment_changed", 0)

# AC-5 — slot_cleared emits in binding states
func test_emit_slot_clear_fires_in_notebook_open() -> void:
	# Arrange
	inp.set_state(LVInput.InputState.NOTEBOOK_OPEN)
	watch_signals(inp)
	# Act
	inp.emit_slot_clear(&"NOUN_BREAD")
	# Assert
	assert_signal_emitted_with_parameters(inp, "slot_cleared", [&"NOUN_BREAD"])

# AC-14 — InputMap actions are registered (not hardcoded)
func test_inputmap_lv_actions_registered() -> void:
	# Arrange/Act: actions are registered in _ready() of the autoload instance
	# Assert: all expected actions exist
	assert_true(InputMap.has_action(&"lv_confirm"))
	assert_true(InputMap.has_action(&"lv_cancel"))
	assert_true(InputMap.has_action(&"lv_notebook_open"))
	assert_true(InputMap.has_action(&"lv_next_page"))
	assert_true(InputMap.has_action(&"lv_prev_page"))
	assert_true(InputMap.has_action(&"lv_nav_up"))
	assert_true(InputMap.has_action(&"lv_nav_down"))
	assert_true(InputMap.has_action(&"lv_nav_left"))
	assert_true(InputMap.has_action(&"lv_nav_right"))

# AC-13 — Reduced-motion: snap-back is instant (0ms)
func test_reduced_motion_zeros_snap_back_duration() -> void:
	# Arrange
	inp.set_reduced_motion(true)
	# Act
	var duration: int = inp.effective_snap_back_ms()
	# Assert
	assert_eq(duration, 0)

# Default snap-back duration when reduced-motion is off
func test_normal_motion_snap_back_is_120ms() -> void:
	# Arrange
	inp.set_reduced_motion(false)
	# Act
	var duration: int = inp.effective_snap_back_ms()
	# Assert
	assert_eq(duration, LVInput.DRAG_SNAP_BACK_DURATION_MS)
	assert_eq(duration, 120)

# State setter/getter round-trip
func test_state_setter_getter_round_trip() -> void:
	# Arrange / Act
	inp.set_state(LVInput.InputState.DIALOGUE_OPEN)
	# Assert
	assert_eq(inp.get_state(), LVInput.InputState.DIALOGUE_OPEN)

	inp.set_state(LVInput.InputState.CUTSCENE)
	assert_eq(inp.get_state(), LVInput.InputState.CUTSCENE)

# State transitions are exclusive (no enum overlap)
func test_state_enum_values_distinct() -> void:
	# Assert no duplicate enum values
	var values: Array = [
		LVInput.InputState.NORMAL,
		LVInput.InputState.DIALOGUE_OPEN,
		LVInput.InputState.NOTEBOOK_OPEN,
		LVInput.InputState.ICON_SELECTED,
		LVInput.InputState.DRAG_IN_PROGRESS,
		LVInput.InputState.CUTSCENE,
	]
	var seen: Dictionary = {}
	for v in values:
		assert_false(seen.has(v), "Duplicate enum value: %d" % v)
		seen[v] = true
