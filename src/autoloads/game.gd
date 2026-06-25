## Global game state singleton for Night Market Shopping.
##
## Holds shared state used across scenes (current area, dialogue lock,
## session timer) and the level-routing helper. R-001 set up the stub;
## R-008 extends with session_time + goto_level + reset_run.
extends Node

# ---------------------------------------------------------------------------
# Per-run state
# ---------------------------------------------------------------------------

## Identifier of the currently-loaded scene/area.
var current_area: String = ""

## True while a dialogue is active. PlayerGrid checks this to gate input.
var in_dialogue: bool = false

## Seconds since the current run began. Reset by `reset_run()`. Accumulates
## only while the market scene is loaded (not on title or end screens).
var session_time: float = 0.0

## True iff the most recent successful run set a new HiScore record.
## Read by the end screen to show "新紀錄！" badge. Cleared by reset_run().
var last_run_was_record: bool = false

## v0.12: true iff the most recent successful run bought ALL 7 ingredients
## (滿漢全席 perfect run). Cleared by reset_run().
var last_run_perfect: bool = false

## v0.12: number of times the player invoked 殺價 during this run. Used by
## the no-bargain achievement. Cleared by reset_run().
var bargain_count: int = 0

## True once the one-time "try bargaining" nudge has fired this run (shown at
## the first stall that still has 殺價 available). Cleared by reset_run().
var bargain_hint_shown: bool = false

## v0.14: true iff the most recent run finished without all required
## ingredients — kid came home anyway. Drives the "messy cooking" path in
## the kitchen and suppresses HiScore recording. Cleared by reset_run().
var last_run_incomplete: bool = false

## v0.25: dishes the player cooked for the first time ever during this run.
## Populated in kitchen at PLATE stage by checking HiScore.cook_count BEFORE
## recording. Drives celebration lines + the end screen "新解鎖" badge.
## Cleared by reset_run().
var last_run_new_dishes: PackedStringArray = PackedStringArray()

# ---------------------------------------------------------------------------
# Test-mode flag — when true, scene-changing helpers no-op so unit tests
# can call them without unloading the test harness scene.
# ---------------------------------------------------------------------------

var test_mode: bool = false

# ---------------------------------------------------------------------------
# Level paths
# ---------------------------------------------------------------------------

const LEVEL_PATHS: Dictionary[String, String] = {
	"title": "res://scenes/menus/title.tscn",
	"home_intro": "res://scenes/levels/home_intro.tscn",
	"shilin": "res://scenes/levels/shilin_market.tscn",
	"walking_home": "res://scenes/levels/walking_home.tscn",
	"kitchen": "res://scenes/levels/kitchen.tscn",
	"end_win": "res://scenes/menus/end_screen.tscn",
	"bedroom": "res://scenes/levels/bedroom.tscn",
	"dream": "res://scenes/levels/dream.tscn",
	"cookbook": "res://scenes/menus/cookbook.tscn",
}

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Accumulate session time only while playing the market.
	if current_area == "shilin":
		session_time += delta


## Global hotkeys handled at autoload level so they work across every scene
## without per-scene wiring:
##   * M  — toggle audio mute (v0.12)
##   * ESC — abandon current run, return to title (v0.14)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event
	if not ke.pressed or ke.echo:
		return
	match ke.physical_keycode:
		KEY_M:
			HiScore.toggle_mute()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			# Skip ESC handling on the title itself (no run to abandon).
			if current_area == "title":
				return
			# v0.24: cookbook ESC returns to title without touching run state.
			if current_area == "cookbook":
				goto_level("title")
				get_viewport().set_input_as_handled()
				return
			# v0.33: dream ESC skips out of the platformer to title, but
			# leaves the per-run state alone (the run was already over —
			# bedroom routed us here).
			if current_area == "dream":
				goto_level("title")
				get_viewport().set_input_as_handled()
				return
			Inventory.reset()
			reset_run()
			goto_level("title")
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Switches to the named level. Skips the actual scene change in test_mode
## so unit tests can verify the call without unloading the test harness.
func goto_level(key: String) -> void:
	if not LEVEL_PATHS.has(key):
		push_warning("goto_level: unknown key '%s'" % key)
		return
	current_area = key
	if test_mode:
		return
	get_tree().change_scene_to_file(LEVEL_PATHS[key])


## Resets all per-run state. Inventory.reset() is called separately by the
## title screen so each autoload manages its own state.
func reset_run() -> void:
	session_time = 0.0
	current_area = ""
	in_dialogue = false
	last_run_was_record = false
	last_run_perfect = false
	last_run_incomplete = false
	bargain_count = 0
	bargain_hint_shown = false
	last_run_new_dishes = PackedStringArray()
