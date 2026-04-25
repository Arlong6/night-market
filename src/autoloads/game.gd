## Global game state singleton for Night Market Shopping.
##
## Holds shared state used across scenes (current area, dialogue lock,
## session timer) and the level-routing helper. Methods deliberately stay
## minimal at this stage — they expand story by story (R-004 wires
## `in_dialogue`, R-008 adds `goto_level` + session_time, R-009 adds reset_run).
extends Node

# ---------------------------------------------------------------------------
# Per-run state
# ---------------------------------------------------------------------------

## Identifier of the currently-loaded scene/area. Used by tests and HUD logic.
var current_area: String = ""

## True while a dialogue is active. PlayerGrid checks this to gate input.
## Set by Dialogue autoload in R-004.
var in_dialogue: bool = false

# ---------------------------------------------------------------------------
# Test-mode flag — when true, scene-changing helpers no-op so unit tests
# can call them without unloading the test harness scene.
# ---------------------------------------------------------------------------

var test_mode: bool = false
