## Grid-snap player controller for Night Market Shopping.
##
## 4-direction movement: pressing a direction key tweens the visual position
## from the current cell to the adjacent cell over STEP_DURATION seconds.
## Holding the key continues stepping. Bumping an unwalkable cell does not
## move but does change facing direction.
##
## The walkability check is delegated via a Callable so PlayerGrid owns no
## map data — the level passes a closure that consults its own walkable array.
##
## Input edge-detection (rather than `Input.is_action_just_pressed`) follows
## the same pattern proven in v0.1-platformer's player.gd — `is_action_just_*`
## flags are unreliable in headless GUT tests because `Input.action_press()`
## alone does not flip them.
class_name PlayerGrid
extends Node2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a step finishes, after `cell` has been updated and the tween
## reaches the target pixel. Levels can listen to drive on-cell-enter triggers.
signal cell_changed(new_cell: Vector2i)

## Emitted when the player presses into an unwalkable cell. Levels listen
## to dispatch NPC bump-to-talk and similar interactions.
signal bumped(target_cell: Vector2i)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Seconds for one cell-to-cell tween. 0.18 ≈ Pokémon GBA walking pace.
const STEP_DURATION: float = 0.18

const PLAYER_SIZE: float = 14.0       ## drawn body edge length (px)
const PLAYER_COLOR: Color = Color("#E8F542")  ## same yellow as v0.1 kid

## Maps Godot input action names → cardinal direction vectors.
const DIRS: Dictionary = {
	"ui_up": Vector2i(0, -1),
	"ui_down": Vector2i(0, 1),
	"ui_left": Vector2i(-1, 0),
	"ui_right": Vector2i(1, 0),
}

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Returns true iff the given cell can be walked into. If unbound, all moves
## are accepted (handy for unit tests that don't need a level).
@export var walkable_check: Callable = Callable()

## Cell the player begins on. `position` is set to the matching pixel in `_ready`.
@export var start_cell: Vector2i = Vector2i(0, 0)

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Current grid cell. Updated at the START of a step (not the end), so the
## player is "committed" to the target as soon as the tween begins.
var cell: Vector2i

## Last direction the player tried to move. Updates even on blocked attempts
## (turn-on-spot behaviour).
var facing: Vector2i = Vector2i(0, 1)

## True while a tween is in flight; gates new step attempts.
var is_stepping: bool = false

## Counter incremented on every completed step. Drives alternating-foot bob
## visual so the walk cycle feels left-right-left.
var _step_count: int = 0

# ---------------------------------------------------------------------------
# Private state — input edge detection
# ---------------------------------------------------------------------------

## Direction vectors corresponding to currently-held keys, in press order.
## The last entry is the most-recently-pressed direction (used for tie-break).
var _pressed_dirs: Array[Vector2i] = []

## Previous-frame snapshot of each action's pressed state, keyed by action name.
## Used to detect press/release edges deterministically.
var _was_pressed: Dictionary = {}

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	cell = start_cell
	position = GridWorld.cell_to_px(start_cell)


func _process(_delta: float) -> void:
	_update_pressed_dirs()

	# Don't accept new movement while a step is in flight or a dialogue is open.
	if is_stepping:
		return
	if _is_dialogue_blocking():
		return
	if _pressed_dirs.is_empty():
		return

	_attempt_step(_pressed_dirs[-1])


func _draw() -> void:
	# Body centred on cell origin so the rect lands in the 1px gutter.
	var half: float = PLAYER_SIZE / 2.0

	# Walk bob: when stepping, alternating-foot lift via _step_count parity.
	# Body lifts 1px on even-numbered steps; stays low on odd ones. Combined
	# with the position tween it reads as a Pokémon-style 2-frame walk cycle.
	var bob_y: float = 0.0
	if is_stepping and _step_count % 2 == 0:
		bob_y = -1.0

	# Body
	draw_rect(Rect2(-half, -half + bob_y, PLAYER_SIZE, PLAYER_SIZE), PLAYER_COLOR)

	# Facing dot — small dark "eye" 4px towards facing direction. Lives on
	# the body so it inherits the walk bob.
	var eye_centre: Vector2 = Vector2(facing) * 4.0 + Vector2(0.0, bob_y)
	draw_rect(
		Rect2(eye_centre.x - 1.0, eye_centre.y - 1.0, 2.0, 2.0),
		Color("#2A1A0A")
	)
	queue_redraw()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Detects press/release edges this frame and updates `_pressed_dirs` so the
## last entry is the most-recently-pressed cardinal direction.
func _update_pressed_dirs() -> void:
	for action: String in DIRS.keys():
		var pressed_now: bool = Input.is_action_pressed(action)
		var was_down: bool = _was_pressed.get(action, false)
		var dir: Vector2i = DIRS[action]
		if pressed_now and not was_down:
			# Fresh press: append (becomes the new "most recent").
			_pressed_dirs.erase(dir)
			_pressed_dirs.append(dir)
		elif was_down and not pressed_now:
			# Release: drop from the held list.
			_pressed_dirs.erase(dir)
		_was_pressed[action] = pressed_now


## Tries to step one cell in `dir`. Always updates `facing`; only moves and
## fires `cell_changed` if the walkable callback returns true.
func _attempt_step(dir: Vector2i) -> void:
	facing = dir
	var target: Vector2i = cell + dir

	if walkable_check.is_valid() and not walkable_check.call(target):
		bumped.emit(target)
		return

	# Commit immediately so a held-input cascade reads the post-step cell next frame.
	cell = target
	is_stepping = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", GridWorld.cell_to_px(target), STEP_DURATION)
	tween.tween_callback(_on_step_finished)


func _on_step_finished() -> void:
	is_stepping = false
	_step_count += 1
	cell_changed.emit(cell)


## Reads the Game autoload's `in_dialogue` flag if it exists.
## Returns false if Game isn't loaded (e.g., in isolated tests).
func _is_dialogue_blocking() -> bool:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return false
	return bool(game.get("in_dialogue"))
