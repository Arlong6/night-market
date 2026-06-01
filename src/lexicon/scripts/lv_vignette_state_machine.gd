## LVVignetteStateMachine — Lexicon Village #8 Vignette State Machine
##
## One instance per NPC. Orchestrates the 6-state per-NPC vignette lifecycle:
## DORMANT → INTRO → ACTION → CLOSING → COMPLETE_PENDING → CASCADED.
##
## NOT an Autoload — instantiated by the NPC sprite scene or a vignette manager.
##
## See: design/gdd/vignette-state-machine.md
class_name LVVignetteStateMachine
extends RefCounted

enum VignetteState {
	DORMANT,
	INTRO,
	ACTION,
	CLOSING,
	COMPLETE_PENDING,
	CASCADED,
}

## Per AC-11: safety force-advance if tableau animation never completes.
const ACTION_TIMEOUT_SEC: float = 8.0

# ─── Identity ─────────────────────────────────────────────────────────────────

## NPC id (matches the vignette_id used by #19 + keystone §3 §4).
var vignette_id: StringName = &""

## Reference to LVSessionState (for ENDING phase checks + signal listening).
var _session_state: Object = null

## Content provider — Callable that returns Dictionary with keys:
## intro_tokens: Array, action_tokens: Array of Arrays (per ACTION line),
## closing_tokens: Array, idle_tokens: Array (post-cascade revisit line).
## Test-friendly — caller injects.
var _content_provider: Callable = Callable()

# ─── State ────────────────────────────────────────────────────────────────────

var _state: int = VignetteState.DORMANT

## Index into the current state's line list (for INTRO with multiple lines, etc.)
var _line_index: int = 0

## Snapshot of action lines (set on entering ACTION).
var _action_lines: Array = []

## Snapshot of intro lines.
var _intro_lines: Array = []

## Snapshot of closing lines.
var _closing_lines: Array = []

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted when state machine wants dialogue to show a line.
## Listener: #11 Dialogue display.
signal show_line_requested(tokens: Array)

## Emitted when state machine wants dialogue to dismiss.
signal hide_dialogue_requested

## Emitted when sprite tableau animation should play. Listener: #7 NPC sprite.
signal play_tableau_requested

## Emitted on state change (for debugging / UI affordances).
signal state_changed(new_state: int)

# ─── Construction ─────────────────────────────────────────────────────────────

func _init(npc_vignette_id: StringName = &"", session_state: Object = null, content_provider: Callable = Callable()) -> void:
	vignette_id = npc_vignette_id
	_session_state = session_state
	_content_provider = content_provider
	if _session_state and _session_state.has_signal("vignette_completed"):
		if not _session_state.vignette_completed.is_connected(_on_vignette_completed):
			_session_state.vignette_completed.connect(_on_vignette_completed)

# ─── Public API ───────────────────────────────────────────────────────────────

## Called when player clicks the NPC. Per AC-1.
func on_npc_clicked() -> void:
	if _is_phase_locked():
		return  # AC-14: ENDING locks
	# CASCADED → show idle line (per #14)
	if _state == VignetteState.CASCADED:
		var content: Dictionary = _get_content()
		var idle: Array = content.get(&"idle_tokens", [])
		if not idle.is_empty():
			show_line_requested.emit(idle)
		return
	# Any other state → replay from INTRO (per AC-6)
	_enter_intro()

## Called when player advances dialogue (Enter/Space/click). Per AC-2, AC-4.
func on_advance_pressed() -> void:
	match _state:
		VignetteState.INTRO:
			_advance_intro()
		VignetteState.CLOSING:
			_advance_closing()
		# ACTION advances on tableau_complete, not on player advance
		# DORMANT / COMPLETE_PENDING / CASCADED ignore advance

## Called when NPC tableau animation completes. Per AC-3.
func on_tableau_complete() -> void:
	if _state != VignetteState.ACTION:
		return
	_enter_closing()

## Called when player closes dialogue (Esc) mid-INTRO/CLOSING. Per AC-5.
func on_dialogue_cancelled() -> void:
	if _state == VignetteState.INTRO or _state == VignetteState.CLOSING:
		hide_dialogue_requested.emit()
		_set_state(VignetteState.DORMANT)

## Current state.
func get_state() -> int:
	return _state

## Force-advance from ACTION (safety net per AC-11; called by an external timer).
func force_advance_action_timeout() -> void:
	if _state == VignetteState.ACTION:
		push_error("LVVignetteStateMachine: ACTION timeout for %s — forcing CLOSING" % vignette_id)
		_enter_closing()

# ─── State transition internals ───────────────────────────────────────────────

func _enter_intro() -> void:
	var content: Dictionary = _get_content()
	_intro_lines = content.get(&"intro_tokens", [])
	_action_lines = content.get(&"action_tokens", [])
	_closing_lines = content.get(&"closing_tokens", [])
	if _intro_lines.is_empty():
		# AC-13: missing authoring data
		push_error("LVVignetteStateMachine: %s has no intro_tokens — authoring error" % vignette_id)
		return
	_line_index = 0
	_set_state(VignetteState.INTRO)
	show_line_requested.emit(_intro_lines[0])

func _advance_intro() -> void:
	_line_index += 1
	if _line_index < _intro_lines.size():
		show_line_requested.emit(_intro_lines[_line_index])
	else:
		_enter_action()

func _enter_action() -> void:
	_line_index = 0
	_set_state(VignetteState.ACTION)
	play_tableau_requested.emit()
	# Show first action line (if any) concurrently with tableau
	if not _action_lines.is_empty():
		show_line_requested.emit(_action_lines[0])

func _enter_closing() -> void:
	if _closing_lines.is_empty():
		# Skip CLOSING if no closing line
		_enter_complete_pending()
		return
	_line_index = 0
	_set_state(VignetteState.CLOSING)
	show_line_requested.emit(_closing_lines[0])

func _advance_closing() -> void:
	_line_index += 1
	if _line_index < _closing_lines.size():
		show_line_requested.emit(_closing_lines[_line_index])
	else:
		hide_dialogue_requested.emit()
		_enter_complete_pending()

func _enter_complete_pending() -> void:
	_set_state(VignetteState.COMPLETE_PENDING)
	# Check if vignette is ALREADY cascaded — per AC-10
	# (player may have bound all slots before/during interaction)
	if _session_state and _session_state.is_vignette_cascaded(vignette_id):
		_set_state(VignetteState.CASCADED)

func _on_vignette_completed(completed_id: StringName) -> void:
	if completed_id != vignette_id:
		return
	if _state == VignetteState.COMPLETE_PENDING:
		_set_state(VignetteState.CASCADED)
	# If we're still in INTRO/ACTION/CLOSING (player bound mid-flow), we stay
	# in current state; CASCADED transition happens on next _enter_complete_pending.
	# Wait — if vignette validates mid-ACTION, the player has the bind complete
	# but dialogue is still playing. Spec says cascade is deferred via notebook-closed
	# gate (#10 EC-10), so this should generally not fire until dialogue is closed.
	# Defensive: if we get here in any non-COMPLETE_PENDING state, mark for transition
	# at the next CLOSING completion.

func _set_state(new_state: int) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(new_state)

func _get_content() -> Dictionary:
	if _content_provider.is_valid():
		var result = _content_provider.call(vignette_id)
		if result is Dictionary:
			return result
	return {}

func _is_phase_locked() -> bool:
	if _session_state == null:
		return false
	return _session_state.get_game_phase() != 0  # 0 = PLAYING
