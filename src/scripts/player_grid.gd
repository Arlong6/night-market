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

## v0.23: hold Shift to sprint at ~1.8× speed. Useful for backtracking
## across the market without padding the run timer.
const SPRINT_STEP_DURATION: float = 0.10

const PLAYER_SIZE: float = 14.0       ## drawn body edge length (px)
const PLAYER_COLOR: Color = Color("#E8F542")  ## same yellow shirt as v0.1 kid
const PLAYER_SKIN: Color = Color("#F2D6A8")
const PLAYER_HAIR: Color = Color("#3A1A0A")
const PLAYER_PANTS: Color = Color("#3A4A8A")  ## blue shorts

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

## v0.37: free-running accumulator for idle breathing animation when the
## player is not moving. Drives a slow 1-px shoulders-rise via sin(_t * 2).
var _idle_t: float = 0.0

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


func _process(delta: float) -> void:
	# v0.37: idle accumulator — only ticks when stationary so breathing
	# doesn't fight the walk-cycle bob.
	if not is_stepping and _pressed_dirs.is_empty():
		_idle_t += delta
	_update_pressed_dirs()

	# Don't accept new movement while a step is in flight or a dialogue is open.
	if is_stepping:
		return
	if _is_dialogue_blocking():
		return
	if _pressed_dirs.is_empty():
		return

	_attempt_step(_pressed_dirs[-1])


## v0.37 sprite — 4-direction facing + walk cycle + idle breathing.
##
## Layers (back→front, drawn vertically aligned with player at y=0):
##   - Hair (varies by facing — back of head when looking up, sweeping
##     fringe + side hair when looking down)
##   - Skin head (face shape unchanged across directions)
##   - Eyes (pair of dots when facing down/left/right; absent when up)
##   - Shirt (with collar accent + tiny side detail when facing left/right)
##   - Arms (small 1×2 rects that swing forward/back during walk)
##   - Shorts (alternating foot-lift on walk cycle)
##
## When stationary, _idle_t drives a 1-px shoulder rise on a slow sine so
## the player still looks alive while the world ticks around them.
func _draw() -> void:
	var step_phase: bool = is_stepping and (_step_count % 2 == 0)
	var bob: float = -1.0 if step_phase else 0.0
	# Idle breathing — only when not stepping and no input held.
	var idle_bob: float = 0.0
	if not is_stepping and _pressed_dirs.is_empty():
		# 0.6 Hz breathing → noticeable but calm. Floor to int so the head
		# either lifts a full pixel or sits flat (no sub-pixel shimmer).
		var s: float = sin(_idle_t * 1.6)
		idle_bob = -1.0 if s > 0.4 else 0.0
	bob += idle_bob

	# --- Hair / head per facing direction ----------------------------------
	if facing.y < 0:
		_draw_head_back(bob)
	else:
		_draw_head_front(bob, facing.x)

	# --- Body --------------------------------------------------------------
	draw_rect(Rect2(-4.0, -1.0 + bob, 8.0, 5.0), PLAYER_COLOR)
	# Shirt collar accent — 1px darker strip across the top of the torso
	draw_rect(Rect2(-4.0, -1.0 + bob, 8.0, 1.0), PLAYER_COLOR.darkened(0.25))
	# Side accent — tiny 1px shadow on the trailing side when facing
	# left/right so the body has a "front vs back" hint.
	if facing.x != 0:
		var side_x: float = -4.0 if facing.x > 0 else 3.0
		draw_rect(Rect2(side_x, 0.0 + bob, 1.0, 4.0),
			PLAYER_COLOR.darkened(0.35))

	# --- Arms — small swinging blocks during walk --------------------------
	# Stationary: arms hang flush with body. Walking: opposite arms forward
	# from opposite legs (left arm forward when right leg lifts).
	var arm_lift: float = 0.0
	if is_stepping:
		arm_lift = -1.0 if step_phase else 0.0
	# Only draw arm visibly on the side that doesn't get hidden by a
	# left/right facing offset (cleaner profile when facing horizontal).
	if facing.y < 0:
		# Facing up → both arms behind body, draw as small bumps at
		# shoulder line in skin tone.
		draw_rect(Rect2(-5.0, 0.0 + bob, 1.0, 2.0), PLAYER_SKIN)
		draw_rect(Rect2(4.0, 0.0 + bob, 1.0, 2.0), PLAYER_SKIN)
	else:
		# Facing down/horizontal: 1×2 arms beside body, opposite-phase to
		# legs for a natural walk feel.
		draw_rect(Rect2(-5.0, 0.0 + bob - arm_lift, 1.0, 2.0), PLAYER_SKIN)
		draw_rect(Rect2(4.0, 0.0 + bob + arm_lift, 1.0, 2.0), PLAYER_SKIN)

	# --- Legs / shorts -----------------------------------------------------
	# Alternating foot lift drives the walk cadence; idle = both flat.
	var left_lift: float = 0.0
	var right_lift: float = 0.0
	if is_stepping:
		left_lift = -1.0 if step_phase else 0.0
		right_lift = 0.0 if step_phase else -1.0
	draw_rect(Rect2(-3.0, 4.0 + bob + left_lift,
		2.0, 3.0 + (1.0 if left_lift == 0.0 else 0.0)), PLAYER_PANTS)
	draw_rect(Rect2(1.0, 4.0 + bob + right_lift,
		2.0, 3.0 + (1.0 if right_lift == 0.0 else 0.0)), PLAYER_PANTS)

	queue_redraw()


## Front / side head — visible face with eyes biased toward facing.x.
## face_x is signf(facing.x): -1 left, 0 down, +1 right.
func _draw_head_front(bob: float, face_x: int) -> void:
	# Head — 6×6 skin square
	draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 6.0), PLAYER_SKIN)
	# Hair — cap (2px stripe) + a tiny fringe sweeping toward the facing side
	draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 2.0), PLAYER_HAIR)
	if face_x != 0:
		# Side fringe — 1×1 bit dropping down from cap on the trailing side
		var fringe_x: float = -3.0 if face_x > 0 else 2.0
		draw_rect(Rect2(fringe_x, -5.0 + bob, 1.0, 1.0), PLAYER_HAIR)
	else:
		# Centre fringe — 2×1 bit hanging from the cap
		draw_rect(Rect2(-1.0, -5.0 + bob, 2.0, 1.0), PLAYER_HAIR)
	# Eyes — pair of dots, biased toward facing.x for left/right look.
	var face_shift: float = float(face_x) * 1.0
	draw_rect(Rect2(-2.0 + face_shift, -4.0 + bob, 1.0, 1.0),
		Color("#2A1A0A"))
	draw_rect(Rect2(1.0 + face_shift, -4.0 + bob, 1.0, 1.0),
		Color("#2A1A0A"))


## Back of head — solid hair cap covering the whole head silhouette.
## No eyes drawn (we're looking at the back).
func _draw_head_back(bob: float) -> void:
	# Hair fully covers the head when facing away; one small skin strip
	# at the bottom hints at the neck.
	draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 5.0), PLAYER_HAIR)
	# Neck — 1px skin sliver at the bottom of the head silhouette
	draw_rect(Rect2(-2.0, -2.0 + bob, 4.0, 1.0), PLAYER_SKIN)

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
	# v0.23: Shift held → sprint cadence; otherwise walk cadence.
	var dur: float = (
		SPRINT_STEP_DURATION if Input.is_key_pressed(KEY_SHIFT)
		else STEP_DURATION
	)
	# v0.32: footstep tick — alternate L/R foot via _step_count parity so
	# the click sounds like a walk pattern, not a single repeated tone.
	var sfx: Node = get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play_footstep()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", GridWorld.cell_to_px(target), dur)
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
