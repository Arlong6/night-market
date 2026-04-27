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
	"shilin": "res://scenes/levels/shilin_market.tscn",
	"end_win": "res://scenes/menus/end_screen.tscn",
}

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Accumulate session time only while playing the market.
	if current_area == "shilin":
		session_time += delta

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
