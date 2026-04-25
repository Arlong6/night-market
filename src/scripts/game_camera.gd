## Camera that follows the player's x-position for Night Market Runner.
## Clamps to level boundaries and pixel-snaps each frame to prevent sub-pixel jitter.
## Vertical position is fixed (no vertical camera movement for MVP).
## Story 006: Camera System
class_name GameCamera
extends Camera2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Width of the game viewport in pixels. Clamp math keeps the camera view
## within [0, level_width] by keeping the camera centre at least VIEWPORT_W/2
## from each edge.
const VIEWPORT_W: int = 320

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## The node to follow. Assign to the Player in each level scene.
## Accepts any Node2D so tests can use a stand-in without a full Player instance.
@export var target: Node2D

## Total width of the level in pixels. Must be >= VIEWPORT_W (320).
## Each level scene overrides this via the Inspector or a level script.
@export var level_width: int = 960

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Locked y position. Set once in _ready; never mutated afterward.
var _locked_y: float = 0.0

## Max ± offset applied by the current shake (px). 0 = no shake active.
var _shake_amount: float = 0.0

## Seconds remaining on the current shake.
var _shake_time_left: float = 0.0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_locked_y = position.y
	make_current()


func _process(delta: float) -> void:
	if target == null:
		return

	var half_vp: float = VIEWPORT_W / 2.0
	var clamped_x: float = clampf(
		target.position.x,
		half_vp,
		float(level_width) - half_vp
	)
	var shake_offset: Vector2 = _update_shake(delta)
	position = Vector2(
		roundf(clamped_x + shake_offset.x),
		roundf(_locked_y + shake_offset.y)
	)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Applies a camera shake. Takes the strongest of any active + requested shake
## so rapid-fire calls can't cancel each other down.
##   amount    — max ± offset in pixels
##   duration  — seconds until shake decays to zero
func shake(amount: float, duration: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time_left = maxf(_shake_time_left, duration)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _update_shake(delta: float) -> Vector2:
	if _shake_time_left <= 0.0:
		return Vector2.ZERO
	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	var amt: float = _shake_amount
	if _shake_time_left <= 0.0:
		_shake_amount = 0.0
	return Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
