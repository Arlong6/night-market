## LVBoot — Lexicon Village #1 Boot & Scene Flow
##
## Owns scene lifecycle. Single scene-swap authority — no other system may call
## get_tree().change_scene_*() directly. Manages 5 states: BOOTING / TITLE /
## GAME / ENDING / TRANSITION. Generates language seed at game-start.
##
## See: design/gdd/boot-scene-flow.md
## ADR: ADR-TBD-scene-management
extends Node

# ─── Constants ────────────────────────────────────────────────────────────────

## Per AC-15: maximum acceptable scene transition latency on desktop.
const SCENE_TRANSITION_MAX_MS: int = 300

## Per AC-15: Web HTML5 first-load budget. Above 12s = Known Limitation.
const WEB_FIRST_LOAD_MAX_S: int = 8

enum BootState { BOOTING, TITLE, GAME, ENDING, TRANSITION }

## Default placeholder scene paths. Real scenes (Title #17, Game village #6, Ending #18)
## will replace these when authored. For MVP shell + tests, can be overridden via
## [method set_scene_paths] (used by tests).
const DEFAULT_TITLE_SCENE: String = "res://lexicon/scenes/lv_title.tscn"
const DEFAULT_GAME_SCENE: String = "res://lexicon/scenes/lv_game.tscn"
const DEFAULT_ENDING_SCENE: String = "res://lexicon/scenes/lv_ending.tscn"

# ─── State ────────────────────────────────────────────────────────────────────

var _state: int = BootState.BOOTING

var _title_scene_path: String = DEFAULT_TITLE_SCENE
var _game_scene_path: String = DEFAULT_GAME_SCENE
var _ending_scene_path: String = DEFAULT_ENDING_SCENE

## When true, scene-swap is a no-op (used by tests + boot-error halt).
var _scene_swap_inhibited: bool = false

## Tracks whether session_ended has been received but ENDING transition deferred
## due to active cascade-shimmer (per AC-4 of #1).
var _pending_ending_transition: bool = false

# ─── Signals ──────────────────────────────────────────────────────────────────

signal boot_state_changed(new_state: int)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Listen to session_ended from #19 (per #1 GDD § Interactions)
	# Use call_deferred since LVSessionState may not yet have completed _ready.
	call_deferred("_wire_session_listener")
	call_deferred("_wire_input_listener")

func _wire_session_listener() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss and ss.has_signal("session_ended"):
		if not ss.session_ended.is_connected(_on_session_ended):
			ss.session_ended.connect(_on_session_ended)

func _wire_input_listener() -> void:
	# Title's confirm_pressed bubbles up via LVInput (per AC-2 contract).
	# We listen here so that boot can drive Title → Game transition.
	var inp = get_node_or_null("/root/LVInput")
	if inp and inp.has_signal("confirm_pressed"):
		if not inp.confirm_pressed.is_connected(_on_confirm_pressed):
			inp.confirm_pressed.connect(_on_confirm_pressed)

# ─── Public API ───────────────────────────────────────────────────────────────

## Transition from BOOTING to TITLE. Called by app start logic.
func boot_complete() -> void:
	if _state != BootState.BOOTING:
		return
	_set_state(BootState.TITLE)
	_swap_scene(_title_scene_path)

## Initiate Title → Game transition. Called when player confirms Start.
## Generates a fresh language seed, init's #19 session, swaps scene.
## [param correct_table_in] and [param slots_in_vignette_in] are content data
## from #12 generator and #13 vignette authoring.
func start_game(correct_table_in: Dictionary, slots_in_vignette_in: Dictionary) -> void:
	if _state != BootState.TITLE:
		return
	_set_state(BootState.TRANSITION)
	var seed: int = _generate_seed()
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.init_session(seed, correct_table_in, slots_in_vignette_in)
	_swap_scene(_game_scene_path)
	_set_state(BootState.GAME)

## Initiate Game → Ending transition. Called by listener for session_ended.
## Defers if cascade-shimmer is active (caller can re-trigger via [method finalize_ending]).
func go_to_ending() -> void:
	if _state != BootState.GAME:
		return
	_set_state(BootState.TRANSITION)
	_swap_scene(_ending_scene_path)
	_set_state(BootState.ENDING)

## Initiate Ending → Title transition (restart). Destroys session state.
func return_to_title() -> void:
	if _state == BootState.TRANSITION:
		# Queue per AC-9; for MVP we honor immediately on completion of current TX.
		# Conservative: just defer one frame.
		call_deferred("return_to_title")
		return
	if _state != BootState.ENDING:
		return
	_set_state(BootState.TRANSITION)
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.destroy_session()
	_swap_scene(_title_scene_path)
	_set_state(BootState.TITLE)

## Current boot state.
func get_state() -> int:
	return _state

# ─── Test/override hooks ──────────────────────────────────────────────────────

## Override scene paths (used by tests to avoid loading real scenes).
func set_scene_paths(title: String, game: String, ending: String) -> void:
	_title_scene_path = title
	_game_scene_path = game
	_ending_scene_path = ending

## Disable actual scene swapping (used by tests so we can verify state transitions
## without needing scene files). When true, _swap_scene becomes a no-op.
func set_scene_swap_inhibited(inhibited: bool) -> void:
	_scene_swap_inhibited = inhibited

# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_session_ended() -> void:
	# Per AC-3: Game → Ending fires on session_ended.
	# Per AC-4: deferred if cascade-shimmer is animating.
	# For MVP without shimmer impl, we transition immediately.
	if _state == BootState.GAME:
		go_to_ending()

func _on_confirm_pressed() -> void:
	# Title's confirm is the start trigger; Game-state confirms go elsewhere.
	# For MVP: only act on confirm if we're in TITLE.
	# (Real start_game requires content data which must be passed by caller.
	# This handler is the framework hook; actual start_game call happens from
	# Title scene with its content references.)
	pass  # Title scene itself handles wiring confirm → start_game

# ─── Internal ─────────────────────────────────────────────────────────────────

func _set_state(new_state: int) -> void:
	_state = new_state
	boot_state_changed.emit(new_state)

func _swap_scene(path: String) -> void:
	if _scene_swap_inhibited:
		return
	if path == "":
		return
	var tree := get_tree()
	if tree == null:
		return
	# Use change_scene_to_file for MVP; ADR may revise to PackedScene preload later.
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("LVBoot: failed to change_scene_to_file(%s) err=%d" % [path, err])

## Seed generation strategy. MVP: hard-coded constant for repeatable testing.
## VS+: switch to time-based via [method _generate_seed_time_based].
## Full Vision: optional user-input seed.
func _generate_seed() -> int:
	# MVP: hard-coded for repeatability. Will change to time-based at VS.
	return 12345

func _generate_seed_time_based() -> int:
	# VS+ implementation: derive from current time. Not currently called.
	return Time.get_unix_time_from_system() as int
