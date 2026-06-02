## Unit tests for LVDialogueDisplay (#11) — covers headless-testable ACs.
## Visual/animation ACs deferred to manual playtest evidence.
extends GutTest

const LVDialogueDisplay = preload("res://lexicon/scripts/lv_dialogue_display.gd")

var dd

const TEST_LINE := [
	{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
	{"type": "PUNCTUATION", "value": "."},
]

const TEST_LINE_2 := [
	{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"},
	{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
	{"type": "PUNCTUATION", "value": "."},
]

func before_each() -> void:
	# Ensure global LVSessionState is in PLAYING phase so dialogue's phase gate passes.
	# Use seed=0 so render falls back to MVP SEED_GLYPHS const ("mura" etc.) —
	# dialogue display tests target rendering API, not procedural language identity.
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss:
		global_ss.init_session(0, {&"NOUN_BREAD": &"icon_bread"}, {&"BAKER": [&"NOUN_BREAD"]})
	dd = LVDialogueDisplay.new()
	add_child_autofree(dd)
	# Wait one frame so _ready completes (creates Label, etc.)
	await get_tree().process_frame

func after_each() -> void:
	# Cleanup: reset global session
	var global_ss = get_node_or_null("/root/LVSessionState")
	if global_ss:
		global_ss.destroy_session()

# AC-1 — Unresolved slot renders foreign glyph form
func test_show_line_renders_unresolved_glyph() -> void:
	# Arrange
	# Act
	dd.show_line(TEST_LINE)
	# Assert: rendered text contains "mura" (unresolved NOUN_BREAD glyph)
	assert_eq(dd.get_state(), LVDialogueDisplay.DialogueState.SHOWING)
	# After typewriter completes, text contains "mura"
	dd.advance()  # skip typewriter
	assert_true(dd._full_text.contains("mura"))

# State: starts HIDDEN
func test_initial_state_is_hidden() -> void:
	assert_eq(dd.get_state(), LVDialogueDisplay.DialogueState.HIDDEN)

# AC-1 — show_line sets state to SHOWING
func test_show_line_sets_state_showing() -> void:
	# Arrange/Act
	dd.show_line(TEST_LINE)
	# Assert
	assert_eq(dd.get_state(), LVDialogueDisplay.DialogueState.SHOWING)
	assert_true(dd.visible)

# AC-1 — empty tokens emits error and does not show
func test_empty_tokens_rejected() -> void:
	# Act
	dd.show_line([])
	# Mark expected push_error
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	# Assert
	assert_eq(dd.get_state(), LVDialogueDisplay.DialogueState.HIDDEN)

# AC-3 — Typewriter rate (we test that visible_characters increments per process)
func test_typewriter_advances_over_time() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	assert_false(dd.is_typewriter_complete())
	# Act: simulate process with delta
	dd._process(0.5)  # at CHARS_PER_SECOND=30, 0.5s = 15 chars
	# Assert: visible characters has advanced (TEST_LINE = "mura." = 5 chars max)
	# 0.5s × 30 = 15 chars, but full line is only 5 chars, so completes
	assert_true(dd.is_typewriter_complete())

# AC-5 — advance() skips typewriter when not complete
func test_advance_skips_typewriter() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	assert_false(dd.is_typewriter_complete())
	# Act
	dd.advance()
	# Assert
	assert_true(dd.is_typewriter_complete())

# AC-5 — advance() after typewriter complete emits advance signal
func test_advance_after_complete_emits_signal() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	dd.advance()  # skip typewriter
	watch_signals(dd)
	# Act
	dd.advance()
	# Assert
	assert_signal_emitted(dd, "advance_pressed")

# AC-12 — hide_dialogue sets state to HIDDEN
func test_hide_dialogue_sets_state_hidden() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	watch_signals(dd)
	# Act
	dd.hide_dialogue()
	# Assert
	assert_eq(dd.get_state(), LVDialogueDisplay.DialogueState.HIDDEN)
	assert_false(dd.visible)
	assert_signal_emitted(dd, "dialogue_hidden")

# AC-12 — hide pushes current line to history
func test_hide_pushes_to_history() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	# Act
	dd.hide_dialogue()
	# Assert
	var history: Array = dd.get_history()
	assert_eq(history.size(), 1)

# AC-13 — History capacity cap
func test_history_capacity_cap() -> void:
	# Arrange: push more than HISTORY_CAPACITY lines
	for i in LVDialogueDisplay.HISTORY_CAPACITY + 5:
		dd.show_line(TEST_LINE)
		dd.hide_dialogue()
	# Assert
	assert_eq(dd.get_history().size(), LVDialogueDisplay.HISTORY_CAPACITY)

# show_line transitions: showing one line then another pushes first to history
func test_consecutive_show_line_pushes_first_to_history() -> void:
	# Arrange
	dd.show_line(TEST_LINE)
	# Act
	dd.show_line(TEST_LINE_2)
	# Assert
	assert_eq(dd.get_history().size(), 1)
	# Current tokens should be the second line
	var cur: Array = dd.get_current_tokens()
	assert_eq(cur.size(), 3)

# advance() when HIDDEN is no-op
func test_advance_when_hidden_no_op() -> void:
	# Arrange (HIDDEN)
	watch_signals(dd)
	# Act
	dd.advance()
	# Assert
	assert_signal_emit_count(dd, "advance_pressed", 0)

# show_line emits line_shown signal
func test_show_line_emits_signal() -> void:
	# Arrange
	watch_signals(dd)
	# Act
	dd.show_line(TEST_LINE)
	# Assert
	assert_signal_emitted(dd, "line_shown")

# AC-3 typewriter constant value
func test_chars_per_second_is_30() -> void:
	# Assert
	assert_eq(LVDialogueDisplay.CHARS_PER_SECOND, 30.0)
