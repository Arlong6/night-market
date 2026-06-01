## LVDialogueDisplay — Lexicon Village #11 Dialogue display
##
## Lean MVP scaffold. Renders dialogue lines as token sequences via
## LVVignetteContent.render_tokens(); per-token Label nodes for shimmer
## animation are a Vertical Slice refinement.
##
## API: show_line(tokens), advance(), hide(). Listens for typewriter completion.
##
## See: design/gdd/dialogue-display.md
class_name LVDialogueDisplay
extends Control

const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

## Per AC-3: CHARS_PER_SECOND
const CHARS_PER_SECOND: float = 30.0

## Per knobs: line dwell after typewriter completes
const LINE_DWELL_SEC: float = 0.5

## Per knobs: history capacity
const HISTORY_CAPACITY: int = 20

## Per knobs: retroactive (history reopen) glow-in fade duration
const RETROACTIVE_FADE_SEC: float = 0.3

# ─── State ────────────────────────────────────────────────────────────────────

enum DialogueState { HIDDEN, SHOWING, FREED }

var _state: int = DialogueState.HIDDEN

## Currently displayed tokens (for shimmer re-rendering when slots resolve).
var _current_tokens: Array = []

## Typewriter elapsed time (seconds).
var _typewriter_elapsed: float = 0.0

## Full text of current line (rendered).
var _full_text: String = ""

## Total characters in current line (cached).
var _full_text_length: int = 0

## True when typewriter has completed for the current line.
var _typewriter_complete: bool = false

## Reference to LVSessionState (for confirmed_slots query during render).
var _session_state: Object = null

## Reference to LVInput (for state observation).
var _input: Object = null

## Dialogue history — Array of past token sequences (capped at HISTORY_CAPACITY).
var _history: Array = []

## Label node for rendering current line. Created in _ready or injected.
var _label: Label = null

# ─── Signals ──────────────────────────────────────────────────────────────────

signal line_shown(tokens: Array)
signal line_completed  ## typewriter finished
signal advance_pressed
signal dialogue_hidden

# ─── Construction ─────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	_label = get_node_or_null("Label")
	if _label == null:
		# Auto-create a basic label if not provided by scene
		_label = Label.new()
		_label.name = "Label"
		_label.anchor_right = 1.0
		_label.anchor_bottom = 1.0
		add_child(_label)
	_session_state = get_node_or_null("/root/LVSessionState")
	_input = get_node_or_null("/root/LVInput")
	# Listen for cascade signal to re-render
	if _session_state and _session_state.has_signal("vignette_completed"):
		if not _session_state.vignette_completed.is_connected(_on_vignette_completed):
			_session_state.vignette_completed.connect(_on_vignette_completed)

func _process(delta: float) -> void:
	if _state != DialogueState.SHOWING:
		return
	if _typewriter_complete:
		return
	_typewriter_elapsed += delta
	var visible_chars: int = int(CHARS_PER_SECOND * _typewriter_elapsed)
	if visible_chars >= _full_text_length:
		visible_chars = _full_text_length
		_typewriter_complete = true
		line_completed.emit()
	if _label:
		_label.visible_characters = visible_chars

# ─── Public API ───────────────────────────────────────────────────────────────

## Show a dialogue line (per #8 calling this). Per AC-1/AC-2.
func show_line(tokens: Array) -> void:
	# AC-14: phase gate — if session is in ENDING, ignore
	if _session_state and _session_state.get_game_phase() != 0:  # 0 = PLAYING
		push_error("LVDialogueDisplay: show_line() called during non-PLAYING phase")
		return
	if tokens.is_empty():
		push_error("LVDialogueDisplay: show_line() called with empty tokens")
		return
	# Push previous line to history (if there was one and we're already showing)
	if _state == DialogueState.SHOWING and not _current_tokens.is_empty():
		_push_to_history(_current_tokens)
	_current_tokens = tokens
	_render_current()
	_typewriter_elapsed = 0.0
	_typewriter_complete = false
	_state = DialogueState.SHOWING
	visible = true
	if _input:
		_input.set_state(_input.InputState.DIALOGUE_OPEN)
	line_shown.emit(tokens)

## Advance to next line OR skip typewriter (per AC-5).
func advance() -> void:
	if _state != DialogueState.SHOWING:
		return
	if not _typewriter_complete:
		# Skip typewriter — show full line immediately
		_typewriter_complete = true
		_typewriter_elapsed = _full_text_length / CHARS_PER_SECOND
		if _label:
			_label.visible_characters = _full_text_length
		line_completed.emit()
		return
	advance_pressed.emit()

## Hide dialogue panel. Per AC-12.
func hide_dialogue() -> void:
	if _state == DialogueState.HIDDEN:
		return
	if not _current_tokens.is_empty():
		_push_to_history(_current_tokens)
	_current_tokens = []
	_full_text = ""
	_full_text_length = 0
	_typewriter_elapsed = 0.0
	_typewriter_complete = false
	_state = DialogueState.HIDDEN
	visible = false
	if _input and _input.get_state() == _input.InputState.DIALOGUE_OPEN:
		_input.set_state(_input.InputState.NORMAL)
	dialogue_hidden.emit()

## Current state.
func get_state() -> int:
	return _state

## Currently shown tokens (defensive copy).
func get_current_tokens() -> Array:
	return _current_tokens.duplicate(true)

## Dialogue history (defensive copy).
func get_history() -> Array:
	return _history.duplicate(true)

## Typewriter complete for current line?
func is_typewriter_complete() -> bool:
	return _typewriter_complete

# ─── Internal ─────────────────────────────────────────────────────────────────

func _render_current() -> void:
	if _session_state:
		_full_text = LVVignetteContent.render_tokens(_current_tokens, _session_state.get_confirmed_slots())
	else:
		_full_text = LVVignetteContent.render_tokens(_current_tokens, [])
	_full_text_length = _full_text.length()
	if _label:
		_label.text = _full_text
		_label.visible_characters = 0  # typewriter starts at 0

func _push_to_history(tokens: Array) -> void:
	_history.append(tokens.duplicate(true))
	if _history.size() > HISTORY_CAPACITY:
		_history.pop_front()

func _on_vignette_completed(_vignette_id: StringName) -> void:
	# A vignette has cascaded — re-render current line if it contains tokens
	# from the newly-confirmed slots. For MVP scaffold, just re-render whole line
	# (without ripple — that's #10's job, deferred). This implements the
	# "retroactive resolve" by updating the rendered string in-place.
	if _state == DialogueState.SHOWING:
		_render_current()
		# Keep typewriter position
		if _label and _typewriter_complete:
			_label.visible_characters = _full_text_length
