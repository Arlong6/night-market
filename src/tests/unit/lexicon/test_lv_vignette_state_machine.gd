## Unit tests for LVVignetteStateMachine — covers AC-1 through AC-14 from
## design/gdd/vignette-state-machine.md.
extends GutTest

const LVVignetteStateMachine = preload("res://lexicon/scripts/lv_vignette_state_machine.gd")
const LVSessionState = preload("res://lexicon/autoloads/lv_session_state.gd")

var ss
var sm

const BAKER_INTRO := [
	[{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"}, {"type": "PUNCTUATION", "value": "."}]
]
const BAKER_ACTION := [
	[{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"}, {"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"}],
	[{"type": "LEXICON_SLOT", "value": &"ADJ_WARM"}, {"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"}]
]
const BAKER_CLOSING := [
	[{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"}, {"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"}, {"type": "PART_Q", "value": "ka"}, {"type": "PUNCTUATION", "value": "?"}]
]
const BAKER_IDLE := [
	[{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"}, {"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"}]
]

const CORRECT_TABLE := {
	&"NOUN_BREAD": &"icon_bread",
	&"VERB_GIVE": &"icon_give",
	&"ADJ_WARM": &"icon_warm",
}
const SLOTS_IN_VIGNETTE := {
	&"BAKER": [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"],
}

func _baker_content_provider(vid: StringName) -> Dictionary:
	if vid == &"BAKER":
		return {
			&"intro_tokens": BAKER_INTRO,
			&"action_tokens": BAKER_ACTION,
			&"closing_tokens": BAKER_CLOSING,
			&"idle_tokens": BAKER_IDLE,
		}
	return {}

func before_each() -> void:
	ss = LVSessionState.new()
	add_child_autofree(ss)
	ss.init_session(1, CORRECT_TABLE, SLOTS_IN_VIGNETTE)
	sm = LVVignetteStateMachine.new(&"BAKER", ss, _baker_content_provider)

# AC-1 — DORMANT to INTRO on NPC click
func test_npc_click_transitions_to_intro() -> void:
	# Arrange
	watch_signals(sm)
	# Act
	sm.on_npc_clicked()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.INTRO)
	assert_signal_emitted(sm, "show_line_requested")

# AC-2 — INTRO to ACTION on advance (single intro line)
func test_intro_advance_transitions_to_action() -> void:
	# Arrange
	sm.on_npc_clicked()  # in INTRO
	watch_signals(sm)
	# Act: BAKER has 1 intro line; advance once advances past it to ACTION
	sm.on_advance_pressed()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.ACTION)
	assert_signal_emitted(sm, "play_tableau_requested")

# AC-3 — ACTION to CLOSING on sprite signal
func test_action_tableau_complete_transitions_to_closing() -> void:
	# Arrange: advance to ACTION
	sm.on_npc_clicked()
	sm.on_advance_pressed()  # INTRO → ACTION
	watch_signals(sm)
	# Act
	sm.on_tableau_complete()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CLOSING)

# AC-4 — CLOSING to COMPLETE_PENDING on advance
func test_closing_advance_transitions_to_complete_pending() -> void:
	# Arrange: get to CLOSING
	sm.on_npc_clicked()
	sm.on_advance_pressed()  # INTRO → ACTION
	sm.on_tableau_complete()  # ACTION → CLOSING
	watch_signals(sm)
	# Act
	sm.on_advance_pressed()  # CLOSING → COMPLETE_PENDING
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.COMPLETE_PENDING)
	assert_signal_emitted(sm, "hide_dialogue_requested")

# AC-5 — Esc mid-INTRO returns to DORMANT
func test_dialogue_cancel_in_intro_returns_to_dormant() -> void:
	# Arrange
	sm.on_npc_clicked()  # INTRO
	# Act
	sm.on_dialogue_cancelled()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.DORMANT)

# AC-6 — Re-click in COMPLETE_PENDING restarts at INTRO
func test_npc_click_in_complete_pending_replays_from_intro() -> void:
	# Arrange: get to COMPLETE_PENDING
	sm.on_npc_clicked()
	sm.on_advance_pressed()
	sm.on_tableau_complete()
	sm.on_advance_pressed()
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.COMPLETE_PENDING)
	# Act
	sm.on_npc_clicked()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.INTRO)

# AC-7 — vignette_completed signal triggers CASCADED
func test_vignette_completed_in_complete_pending_triggers_cascaded() -> void:
	# Arrange: get to COMPLETE_PENDING
	sm.on_npc_clicked()
	sm.on_advance_pressed()
	sm.on_tableau_complete()
	sm.on_advance_pressed()
	# Act: player binds baker (which fires vignette_completed via #19)
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CASCADED)

# AC-8 — CASCADED click dispatches to idle line
func test_cascaded_click_emits_idle_line() -> void:
	# Arrange: get to CASCADED via full bind
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	sm.on_npc_clicked()
	sm.on_advance_pressed()
	sm.on_tableau_complete()
	sm.on_advance_pressed()
	# At this point COMPLETE_PENDING → CASCADED via _enter_complete_pending check
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CASCADED)
	watch_signals(sm)
	# Act
	sm.on_npc_clicked()
	# Assert: idle line emitted, state remains CASCADED
	assert_signal_emitted(sm, "show_line_requested")
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CASCADED)

# AC-10 — Bind before any NPC interaction works (player reaches CASCADED through interaction)
func test_bind_before_interaction_path() -> void:
	# Arrange: pre-bind all baker slots
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	# Act: now player clicks NPC for the first time
	sm.on_npc_clicked()  # INTRO
	sm.on_advance_pressed()  # ACTION
	sm.on_tableau_complete()  # CLOSING
	sm.on_advance_pressed()  # COMPLETE_PENDING → immediately CASCADED
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CASCADED)

# AC-11 — ACTION timeout force-advances to CLOSING
func test_action_timeout_force_advances() -> void:
	# Arrange
	sm.on_npc_clicked()
	sm.on_advance_pressed()  # in ACTION
	# Act
	sm.force_advance_action_timeout()
	# Mark expected push_error
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.CLOSING)

# AC-12 — Per-NPC state independence (two state machines do not interact)
func test_two_npc_state_machines_independent() -> void:
	# Arrange
	var sm2 := LVVignetteStateMachine.new(&"BLACKSMITH", ss, _baker_content_provider)
	# Act
	sm.on_npc_clicked()  # baker INTRO
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.INTRO)
	assert_eq(sm2.get_state(), LVVignetteStateMachine.VignetteState.DORMANT)

# AC-13 — Missing content rejected gracefully
func test_missing_content_keeps_dormant() -> void:
	# Arrange
	var sm_missing := LVVignetteStateMachine.new(&"UNKNOWN", ss, _baker_content_provider)
	# Act
	sm_missing.on_npc_clicked()
	# Mark expected push_error
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	# Assert
	assert_eq(sm_missing.get_state(), LVVignetteStateMachine.VignetteState.DORMANT)

# AC-14 — ENDING phase freezes state
func test_npc_click_in_ending_phase_ignored() -> void:
	# Arrange
	ss.transition_to_ending()
	# Act
	sm.on_npc_clicked()
	# Assert
	assert_eq(sm.get_state(), LVVignetteStateMachine.VignetteState.DORMANT)
