## LVInput — Lexicon Village #2 Input System
##
## Global input event hub + state observer. Routes raw input to consumer systems
## via named signals. Uses InputMap named actions (never hardcoded keys).
##
## State is observed/set by other systems (notebook, dialogue, cascade); LVInput
## does not directly own those overlays but tracks which is active for input gating.
##
## See: design/gdd/input-system.md
## ADR: ADR-TBD-input-routing
extends Node

# ─── Constants ────────────────────────────────────────────────────────────────

## Per AC-11: drag snap-back ease-in-out duration.
const DRAG_SNAP_BACK_DURATION_MS: int = 120

## Per AC-12: maximum acceptable keyboard navigation latency.
const NAVIGATION_RESPONSE_TARGET_MS: int = 80

## Touch long-press threshold (currently unused — touch is click-only per GDD).
const LONG_PRESS_THRESHOLD_MS: int = 350

## Input state enum (mutually exclusive per States table).
enum InputState {
	NORMAL,           ## Village scene, no dialogue, no notebook
	DIALOGUE_OPEN,    ## NPC dialogue panel visible
	NOTEBOOK_OPEN,    ## Notebook visible, no icon carried
	ICON_SELECTED,    ## Player has picked up icon, not yet placed
	DRAG_IN_PROGRESS, ## Mid-drag (post-SPIKE 2 only)
	CUTSCENE          ## Shimmer cascade animating; input locked
}

# ─── State ────────────────────────────────────────────────────────────────────

var _current_state: int = InputState.NORMAL

## Reduced-motion flag, observed by #22 Accessibility when implemented.
var _reduced_motion: bool = false

# ─── Signals ──────────────────────────────────────────────────────────────────

## NPC click in NORMAL state. Consumer: #7 NPC sprite & #8 Vignette state machine.
signal npc_interaction_requested(npc_id: StringName)

## Icon placed on slot. Consumer: #9 Symbol-binding → writes to #19.
signal slot_assignment_changed(slot_id: StringName, icon_id: StringName)

## Icon removed from a slot (pick-up from filled). Consumer: #9 → #19.
signal slot_cleared(slot_id: StringName)

## Tab/Shift-Tab cycles vignette pages. Direction +1 / -1.
signal notebook_page_changed(direction: int)

## Esc / explicit close while NOTEBOOK_OPEN.
signal notebook_close_requested

## Confirm action on menu (Title Start, dialogue advance, etc.)
signal confirm_pressed

## Cancel action (Esc in menus / dialogue).
signal cancel_pressed

## Arrow-key navigation. Direction is a unit Vector2i.
signal menu_navigate(direction: Vector2i)

## Esc during CUTSCENE — passes to #10 Cascade shimmer.
signal cutscene_skip_requested

## Toggle notebook open/close. Listened by #16 / #1 Boot scene flow.
signal notebook_toggle_requested

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_actions_exist()
	# This Autoload sits ABOVE the scene tree; receives unhandled input after scenes.
	# Most input routing is via _unhandled_input.

# ─── Public API ───────────────────────────────────────────────────────────────

## Set the current input state. Called by consumer systems (Notebook, Dialogue, Shimmer)
## when their modal layer opens/closes. State transitions are exclusive.
func set_state(new_state: int) -> void:
	_current_state = new_state

## Current state. Other systems read this for gating.
func get_state() -> int:
	return _current_state

## Set reduced-motion flag (called by #22 Accessibility or #20 Settings).
func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled

## Effective snap-back duration honoring reduced-motion (per AC-13 in #9).
func effective_snap_back_ms() -> int:
	if _reduced_motion:
		return 0
	return DRAG_SNAP_BACK_DURATION_MS

## Programmatic NPC interaction trigger. Called by #7 NPC sprite's click handler.
## (NPC sprites own their own click Control; they call this to fire the signal.)
func request_npc_interaction(npc_id: StringName) -> void:
	if _current_state == InputState.NORMAL:
		npc_interaction_requested.emit(npc_id)

## Programmatic slot-assignment trigger. Called by #16 Notebook UI when a placement gesture completes.
func emit_slot_assignment(slot_id: StringName, icon_id: StringName) -> void:
	# Gate: only valid during NOTEBOOK_OPEN or ICON_SELECTED
	if _current_state == InputState.NOTEBOOK_OPEN or _current_state == InputState.ICON_SELECTED:
		slot_assignment_changed.emit(slot_id, icon_id)

## Programmatic slot-clear trigger.
func emit_slot_clear(slot_id: StringName) -> void:
	if _current_state == InputState.NOTEBOOK_OPEN or _current_state == InputState.ICON_SELECTED:
		slot_cleared.emit(slot_id)

# ─── Input routing ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Per #2 State table — handle by state.
	# Routing here is FOR GLOBAL ACTIONS (Esc, Tab page nav, notebook toggle).
	# Per-Control gestures (NPC click, slot drop) are handled by their Control's _gui_input.

	if event.is_action_pressed(&"lv_cancel"):
		_handle_cancel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"lv_notebook_open"):
		_handle_notebook_toggle()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"lv_confirm"):
		# In CUTSCENE we don't fire confirm (per AC-10 of #2)
		if _current_state != InputState.CUTSCENE:
			confirm_pressed.emit()
			get_viewport().set_input_as_handled()
		return

	# Page nav (Tab / Shift+Tab) only meaningful in NOTEBOOK_OPEN / ICON_SELECTED
	if _current_state == InputState.NOTEBOOK_OPEN or _current_state == InputState.ICON_SELECTED:
		if event.is_action_pressed(&"lv_next_page"):
			notebook_page_changed.emit(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"lv_prev_page"):
			notebook_page_changed.emit(-1)
			get_viewport().set_input_as_handled()
			return

	# Arrow keys for menu/palette nav
	var nav: Vector2i = Vector2i.ZERO
	if event.is_action_pressed(&"lv_nav_up"): nav.y = -1
	elif event.is_action_pressed(&"lv_nav_down"): nav.y = 1
	elif event.is_action_pressed(&"lv_nav_left"): nav.x = -1
	elif event.is_action_pressed(&"lv_nav_right"): nav.x = 1
	if nav != Vector2i.ZERO:
		menu_navigate.emit(nav)
		get_viewport().set_input_as_handled()

func _handle_cancel() -> void:
	# State-dependent cancel behavior per #2 spec:
	# NORMAL → no-op (AC-17)
	# CUTSCENE → cutscene_skip_requested (AC-10)
	# DIALOGUE_OPEN → cancel_pressed (dialogue dismiss)
	# NOTEBOOK_OPEN → notebook_close_requested
	# ICON_SELECTED → cancel_pressed (deselect carried icon)
	match _current_state:
		InputState.NORMAL:
			pass  # AC-17 no-op
		InputState.CUTSCENE:
			cutscene_skip_requested.emit()
		InputState.DIALOGUE_OPEN, InputState.ICON_SELECTED:
			cancel_pressed.emit()
		InputState.NOTEBOOK_OPEN:
			notebook_close_requested.emit()

func _handle_notebook_toggle() -> void:
	# Gated by CUTSCENE (locked) and ENDING (handled at #19/#1 level)
	if _current_state == InputState.CUTSCENE:
		return
	notebook_toggle_requested.emit()

# ─── InputMap action setup ────────────────────────────────────────────────────

## Ensure all lv_* actions exist (defensive — also defined in project.godot).
func _ensure_actions_exist() -> void:
	_ensure_action(&"lv_confirm", [_key(KEY_ENTER), _key(KEY_SPACE)])
	_ensure_action(&"lv_cancel", [_key(KEY_ESCAPE)])
	_ensure_action(&"lv_notebook_open", [_key(KEY_N)])
	_ensure_action(&"lv_next_page", [_key(KEY_TAB)])
	_ensure_action(&"lv_prev_page", [_key_with_shift(KEY_TAB)])
	_ensure_action(&"lv_nav_up", [_key(KEY_UP), _key(KEY_W)])
	_ensure_action(&"lv_nav_down", [_key(KEY_DOWN), _key(KEY_S)])
	_ensure_action(&"lv_nav_left", [_key(KEY_LEFT), _key(KEY_A)])
	_ensure_action(&"lv_nav_right", [_key(KEY_RIGHT), _key(KEY_D)])
	_ensure_action(&"lv_clear_selection", [_key(KEY_BACKSPACE)])

func _ensure_action(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev in events:
		InputMap.action_add_event(action, ev)

func _key(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev

func _key_with_shift(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.shift_pressed = true
	return ev
