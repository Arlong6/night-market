## Unit tests for LVSymbolBinding — covers logic-layer ACs from
## design/gdd/symbol-binding.md. Visual-state ACs deferred to #16 Notebook UI tests.
extends GutTest

const LVSymbolBinding = preload("res://lexicon/scripts/lv_symbol_binding.gd")
const LVSessionState = preload("res://lexicon/autoloads/lv_session_state.gd")

var ss
var sb

const CORRECT_TABLE := {
	&"NOUN_BREAD": &"icon_bread",
	&"VERB_GIVE": &"icon_give",
	&"ADJ_WARM": &"icon_warm",
}
const SLOTS_IN_VIGNETTE := {
	&"BAKER": [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"],
}

func before_each() -> void:
	ss = LVSessionState.new()
	add_child_autofree(ss)
	ss.init_session(1, CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	sb = LVSymbolBinding.new(ss)

# AC-1 — Pick-up from palette enters CARRIED state
func test_pick_up_from_palette_carries_icon() -> void:
	# Arrange/Act
	var ok: bool = sb.pick_up_from_palette(&"icon_bread")
	# Assert
	assert_true(ok)
	assert_true(sb.is_carrying())
	assert_eq(sb.get_carried_icon(), &"icon_bread")
	assert_eq(sb.get_carried_origin_slot(), null)

# AC-1 — Signal emitted on pickup
func test_pick_up_emits_signal() -> void:
	# Arrange
	watch_signals(sb)
	# Act
	sb.pick_up_from_palette(&"icon_bread")
	# Assert
	assert_signal_emitted_with_parameters(sb, "icon_picked_up", [&"icon_bread", null])

# AC-2 — Placement on empty slot writes binding
func test_place_on_empty_slot_writes_binding() -> void:
	# Arrange
	sb.pick_up_from_palette(&"icon_bread")
	# Act
	var ok: bool = sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_true(ok)
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_bread")
	assert_false(sb.is_carrying())

# AC-2 — Placement emits icon_placed signal
func test_place_emits_signal() -> void:
	# Arrange
	sb.pick_up_from_palette(&"icon_bread")
	watch_signals(sb)
	# Act
	sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_signal_emitted_with_parameters(sb, "icon_placed", [&"NOUN_BREAD", &"icon_bread"])

# AC-3 — Placement on occupied non-confirmed slot performs swap
func test_place_on_occupied_slot_swaps() -> void:
	# Arrange: NOUN_BREAD has icon_other
	ss.set_binding(&"NOUN_BREAD", &"icon_other")
	sb.pick_up_from_palette(&"icon_bread")
	# Act
	sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_bread")
	# (icon_other is "returned to palette" via _session_state.set_binding(slot, null)
	# then we placed icon_bread. icon_other is just dropped — caller/UI manages
	# palette state.)

# AC-4 — Placement on confirmed slot silently rejected
func test_place_on_confirmed_slot_rejected() -> void:
	# Arrange: cascade baker first
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	assert_true(ss.is_confirmed(&"NOUN_BREAD"))
	# Player tries to place a different icon on confirmed slot
	sb.pick_up_from_palette(&"icon_other")
	# Act
	var ok: bool = sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_false(ok)
	# Carried icon remains carried (UI animates snap-back)
	assert_true(sb.is_carrying())
	assert_eq(sb.get_carried_icon(), &"icon_other")
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_bread")  # unchanged

# AC-5 — Click confirmed slot when not carrying: no pickup
func test_pick_up_from_confirmed_slot_rejected() -> void:
	# Arrange: cascade baker
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	# Act
	var ok: bool = sb.pick_up_from_slot(&"NOUN_BREAD")
	# Assert
	assert_false(ok)
	assert_false(sb.is_carrying())

# AC-6 — Pick-up from non-confirmed filled slot clears binding
func test_pick_up_from_filled_slot_clears_binding() -> void:
	# Arrange
	ss.set_binding(&"NOUN_BREAD", &"icon_X")
	# Act
	var ok: bool = sb.pick_up_from_slot(&"NOUN_BREAD")
	# Assert
	assert_true(ok)
	assert_true(sb.is_carrying())
	assert_eq(sb.get_carried_icon(), &"icon_X")
	assert_eq(sb.get_carried_origin_slot(), &"NOUN_BREAD")
	assert_eq(ss.get_binding(&"NOUN_BREAD"), null)  # slot cleared

# AC-7 — Cancel returns icon to palette (no event when from palette)
func test_cancel_carry_from_palette_no_binding_change() -> void:
	# Arrange
	sb.pick_up_from_palette(&"icon_bread")
	watch_signals(sb)
	# Act
	sb.cancel_carry()
	# Assert
	assert_false(sb.is_carrying())
	assert_signal_emitted(sb, "carry_cancelled")
	# binding_map should still be empty
	assert_eq(ss.get_binding_map().size(), 0)

# AC-8 — Cancel after slot pick-up restores prior binding
func test_cancel_carry_from_slot_restores_binding() -> void:
	# Arrange
	ss.set_binding(&"NOUN_BREAD", &"icon_X")
	sb.pick_up_from_slot(&"NOUN_BREAD")
	assert_eq(ss.get_binding(&"NOUN_BREAD"), null)  # cleared after pickup
	# Act
	sb.cancel_carry()
	# Assert
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_X")  # restored
	assert_false(sb.is_carrying())

# AC-9 — Icon double-binding check (palette helper)
func test_is_icon_placed_somewhere_detects_existing_placement() -> void:
	# Arrange
	ss.set_binding(&"NOUN_BREAD", &"icon_X")
	# Act / Assert
	assert_true(sb.is_icon_placed_somewhere(&"icon_X"))
	assert_false(sb.is_icon_placed_somewhere(&"icon_other"))

# AC-14 — ENDING phase locks all interactive elements
func test_phase_ending_locks_pickup() -> void:
	# Arrange: transition to ENDING
	ss.transition_to_ending()
	# Act
	var ok: bool = sb.pick_up_from_palette(&"icon_bread")
	# Assert
	assert_false(ok)
	assert_false(sb.is_carrying())

# AC-14 — ENDING phase blocks placement
func test_phase_ending_blocks_placement() -> void:
	# Arrange: pick up while PLAYING, then transition
	sb.pick_up_from_palette(&"icon_bread")
	ss.transition_to_ending()
	# Act
	var ok: bool = sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_false(ok)
	assert_eq(ss.get_binding(&"NOUN_BREAD"), null)

# AC-15 — Second-icon replacement returns first to origin
func test_pick_up_second_icon_returns_first_to_palette() -> void:
	# Arrange
	sb.pick_up_from_palette(&"icon_A")
	# Act
	sb.pick_up_from_palette(&"icon_B")
	# Assert
	assert_eq(sb.get_carried_icon(), &"icon_B")
	# icon_A is "returned" silently (since it was from palette, no binding to restore)
	assert_eq(ss.get_binding_map().size(), 0)

# AC-15 (variant) — Pick up second icon while holding slot-origin icon: restore the slot
func test_pick_up_second_icon_while_holding_slot_icon_restores_slot() -> void:
	# Arrange
	ss.set_binding(&"NOUN_BREAD", &"icon_X")
	sb.pick_up_from_slot(&"NOUN_BREAD")  # carrying icon_X from NOUN_BREAD
	# Act
	sb.pick_up_from_palette(&"icon_Y")
	# Assert: NOUN_BREAD restored to icon_X; now carrying icon_Y from palette
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_X")
	assert_eq(sb.get_carried_icon(), &"icon_Y")
	assert_eq(sb.get_carried_origin_slot(), null)

# Cancel without carrying is a no-op
func test_cancel_when_not_carrying_is_noop() -> void:
	# Arrange
	watch_signals(sb)
	# Act
	sb.cancel_carry()
	# Assert
	assert_signal_emit_count(sb, "carry_cancelled", 0)

# Picking up empty slot does nothing
func test_pick_up_from_empty_slot_no_op() -> void:
	# Arrange (NOUN_BREAD empty)
	# Act
	var ok: bool = sb.pick_up_from_slot(&"NOUN_BREAD")
	# Assert
	assert_false(ok)
	assert_false(sb.is_carrying())

# Place without carrying is a no-op
func test_place_without_carrying_is_noop() -> void:
	# Arrange
	# Act
	var ok: bool = sb.place_on_slot(&"NOUN_BREAD")
	# Assert
	assert_false(ok)
	assert_eq(ss.get_binding(&"NOUN_BREAD"), null)
