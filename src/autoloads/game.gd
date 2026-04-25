## Game state singleton for Night Market Runner.
## Tracks score, deaths, current_level, and session_time across the run.
## Autoload name: Game — access globally as Game.score, Game.add_score(), etc.
## Story 007.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Slug-to-scene-path map. Add new levels here as they are built.
const LEVEL_PATHS: Dictionary = {
	"shilin":       "res://scenes/levels/level_shilin.tscn",
	"fengjia":      "res://scenes/levels/level_fengjia.tscn",
	"liouho":       "res://scenes/levels/level_liouho.tscn",
	"title":        "res://scenes/menus/title.tscn",
	"level_select": "res://scenes/menus/level_select.tscn",
	"level_end":    "res://scenes/menus/level_end.tscn",
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever the score changes. Carries the new total.
signal score_changed(new_score: int)

## Emitted whenever the death count changes. Carries the new total.
signal deaths_changed(new_deaths: int)

## Emitted whenever the active level changes. Carries the new slug.
signal level_changed(new_level: String)

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Running score for the current session.
var score: int = 0

## Total deaths accumulated this session.
var deaths: int = 0

## Slug identifying the currently active (or last loaded) level.
var current_level: String = "shilin"

## Elapsed play time in seconds since the last reset_run().
var session_time: float = 0.0

## When true, restart_level() and goto_level() skip actual scene-tree
## operations. Set to true in GUT tests to prevent scene reloads.
var test_mode: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	session_time += delta

# ---------------------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------------------

## Adds [param points] to the score and emits [signal score_changed].
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


## Increments the death counter, emits [signal deaths_changed], then
## calls restart_level() to reload the current scene.
## Score and deaths are NOT reset — only reset_run() resets them.
func record_death() -> void:
	deaths += 1
	deaths_changed.emit(deaths)
	restart_level()


## Reloads the current scene without resetting score or deaths.
## In test_mode, the actual reload is skipped.
func restart_level() -> void:
	if test_mode:
		return
	get_tree().reload_current_scene()


## Loads the level identified by [param slug], updates current_level,
## and emits [signal level_changed].
## If the slug is not in LEVEL_PATHS, logs a warning and does nothing.
## In test_mode, the actual scene change is skipped.
func goto_level(slug: String) -> void:
	if not LEVEL_PATHS.has(slug):
		push_warning("Game.goto_level: unknown slug '%s' — no scene loaded." % slug)
		return
	current_level = slug
	level_changed.emit(current_level)
	if test_mode:
		return
	get_tree().change_scene_to_file(LEVEL_PATHS[slug])


## Resets score, deaths, and session_time to zero.
## Does NOT change current_level or trigger a scene reload.
func reset_run() -> void:
	score = 0
	deaths = 0
	session_time = 0.0
