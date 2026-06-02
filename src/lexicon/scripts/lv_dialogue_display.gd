## LVDialogueDisplay — Lexicon Village #11 Dialogue display
##
## Renders dialogue lines as HBoxContainer-of-Labels (one Label per token).
## Per-token Labels are the canonical animation target for #10 Cascade Shimmer.
## Typewriter advances a global character count distributed across token Labels.
##
## API: show_line(tokens), advance(), hide(). Listens for typewriter completion.
## Shimmer-facing API: get_token_labels(), get_lexicon_slot_labels().
##
## See: design/gdd/dialogue-display.md
class_name LVDialogueDisplay
extends Control

const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
const LVGlyphFont = preload("res://lexicon/scripts/lv_glyph_font.gd")

## Per AC-3: CHARS_PER_SECOND
const CHARS_PER_SECOND: float = 30.0

## Per knobs: line dwell after typewriter completes
const LINE_DWELL_SEC: float = 0.5

## Per knobs: history capacity
const HISTORY_CAPACITY: int = 20

## Per knobs: retroactive (history reopen) glow-in fade duration
const RETROACTIVE_FADE_SEC: float = 0.3

## Default token Label font color (parchment ink). Matches COLOR_FADED visually
## but is the legible baseline; cascade shimmer drives modulate via its own palette.
const TOKEN_TEXT_COLOR: Color = Color(0.1, 0.05, 0.0, 1.0)

# ─── State ────────────────────────────────────────────────────────────────────

enum DialogueState { HIDDEN, SHOWING, FREED }

var _state: int = DialogueState.HIDDEN

## Currently displayed tokens (for shimmer re-rendering when slots resolve).
var _current_tokens: Array = []

## Typewriter elapsed time (seconds).
var _typewriter_elapsed: float = 0.0

## Full text of current line (joined token texts, including inter-token spaces).
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

## HBoxContainer hosting per-token Labels.
var _token_box: HBoxContainer = null

## Per-token Label list (parallel to _current_tokens). Shimmer-queryable.
var _token_labels: Array = []

# ─── Signals ──────────────────────────────────────────────────────────────────

signal line_shown(tokens: Array)
signal line_completed  ## typewriter finished
signal advance_pressed
signal dialogue_hidden

# ─── Construction ─────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	_setup_token_container()
	_session_state = get_node_or_null("/root/LVSessionState")
	_input = get_node_or_null("/root/LVInput")
	# Listen for cascade signal to re-render
	if _session_state and _session_state.has_signal("vignette_completed"):
		if not _session_state.vignette_completed.is_connected(_on_vignette_completed):
			_session_state.vignette_completed.connect(_on_vignette_completed)

func _setup_token_container() -> void:
	_token_box = get_node_or_null("TokenBox") as HBoxContainer
	if _token_box == null:
		_token_box = HBoxContainer.new()
		_token_box.name = "TokenBox"
		_token_box.anchor_right = 1.0
		_token_box.anchor_bottom = 1.0
		# Spacing handled via leading-space in token text; HBox separation = 0.
		_token_box.add_theme_constant_override("separation", 0)
		add_child(_token_box)
	# Legacy scene injection ("Label" child) — ignored; we own rendering now.

func _process(delta: float) -> void:
	if _state != DialogueState.SHOWING:
		return
	if _typewriter_complete:
		return
	_typewriter_elapsed += delta
	var total_visible: int = int(CHARS_PER_SECOND * _typewriter_elapsed)
	if total_visible >= _full_text_length:
		total_visible = _full_text_length
		_typewriter_complete = true
		line_completed.emit()
	_apply_typewriter(total_visible)

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
		_apply_typewriter(_full_text_length)
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
	_clear_token_labels()
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

## All per-token Labels (parallel to current tokens). Shimmer reads these.
func get_token_labels() -> Array:
	return _token_labels.duplicate()

## LEXICON_SLOT token Labels only — cascade shimmer's animation set.
func get_lexicon_slot_labels() -> Array:
	var out: Array = []
	for lbl in _token_labels:
		if not is_instance_valid(lbl):
			continue
		var token: Variant = lbl.get_meta("token", null)
		if token is Dictionary and String(token.get("type", "")) == "LEXICON_SLOT":
			out.append(lbl)
	return out

# ─── Internal ─────────────────────────────────────────────────────────────────

func _render_current() -> void:
	_clear_token_labels()
	var confirmed_set: Dictionary = {}
	if _session_state:
		for s in _session_state.get_confirmed_slots():
			confirmed_set[s] = true
	var full_text := ""
	for i in _current_tokens.size():
		var token: Dictionary = _current_tokens[i]
		var token_text: String = _render_token_text(token, confirmed_set)
		# Leading space for non-first non-punctuation-attached tokens.
		var prefix := ""
		if i > 0 and not _is_attached_to_prev(token_text):
			prefix = " "
		var label_text := prefix + token_text
		var lbl := Label.new()
		lbl.text = label_text
		lbl.visible_characters = 0
		lbl.add_theme_color_override("font_color", TOKEN_TEXT_COLOR)
		lbl.set_meta("token", token)
		# #5 Glyph font: unresolved LEXICON_SLOT renders in pixel-mode font;
		# confirmed (resolved Chinese) keeps the default CJK font. Other token
		# types (punctuation, particle, UI text) keep default.
		var t_type: String = String(token.get("type", ""))
		if t_type == "LEXICON_SLOT":
			var slot_id: StringName = token.get("value", &"") as StringName
			if not confirmed_set.has(slot_id):
				LVGlyphFont.apply_to_label(lbl)
		_token_box.add_child(lbl)
		_token_labels.append(lbl)
		full_text += label_text
	_full_text = full_text
	_full_text_length = _full_text.length()

func _render_token_text(token: Dictionary, confirmed_set: Dictionary) -> String:
	var t_type: String = String(token.get("type", ""))
	var t_value: Variant = token.get("value", "")
	match t_type:
		"LEXICON_SLOT":
			var slot: StringName = t_value as StringName
			var runtime_override: Dictionary = {}
			if _session_state and _session_state.has_method("get_runtime_glyphs"):
				runtime_override = _session_state.get_runtime_glyphs()
			return LVVignetteContent.render_slot_text(slot, confirmed_set.has(slot), runtime_override)
		"UI_TEXT", "PUNCTUATION", "PART_Q":
			return String(t_value)
		_:
			return "[?%s]" % t_type

func _is_attached_to_prev(token_text: String) -> bool:
	if token_text.is_empty():
		return false
	var first := token_text.substr(0, 1)
	return first in [".", "?", "!", ",", ";", ":"]

func _apply_typewriter(total_visible: int) -> void:
	var remaining: int = total_visible
	for lbl in _token_labels:
		if not is_instance_valid(lbl):
			continue
		var tlen: int = lbl.text.length()
		if remaining >= tlen:
			lbl.visible_characters = -1
			remaining -= tlen
		else:
			lbl.visible_characters = remaining
			remaining = 0

func _clear_token_labels() -> void:
	for lbl in _token_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_token_labels.clear()

func _push_to_history(tokens: Array) -> void:
	_history.append(tokens.duplicate(true))
	if _history.size() > HISTORY_CAPACITY:
		_history.pop_front()

func _on_vignette_completed(_vignette_id: StringName) -> void:
	# A vignette has cascaded — re-render current line so newly-confirmed slot
	# Labels render decoded. Cascade Shimmer (#10) animates the modulate; this
	# only updates the text content (and resets visible_characters appropriately).
	if _state != DialogueState.SHOWING:
		return
	var was_complete := _typewriter_complete
	_render_current()
	if was_complete:
		_apply_typewriter(_full_text_length)
		_typewriter_complete = true
