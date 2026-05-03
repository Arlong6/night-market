## Wandering night-market cat (v0.36).
##
## Pure atmosphere — like WanderShopper, but with a 2-state behaviour
## (walking ↔ sitting) so the cat looks like it has its own agenda
## rather than being a clone of the human shoppers. Stops every few
## seconds to sit, twitches its tail, then strolls again. Looks the
## direction it's heading.
##
## Spawned by `ShilinMarket._spawn_cat()`. No interaction.
class_name NightMarketCat
extends Node2D

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

const WALK_SPEED: float = 14.0    ## px / s while strolling
const WALK_DURATION_MIN: float = 2.4
const WALK_DURATION_MAX: float = 4.6
const SIT_DURATION_MIN: float = 1.8
const SIT_DURATION_MAX: float = 3.5
const STEP_PERIOD: float = 0.28   ## walk-cycle alternation

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Lane y in world px. Cat stays at this Y the whole time.
@export var lane_y: float = 124.0

## Horizontal travel range. Wraps when leaving this band.
@export var x_min: float = 16.0
@export var x_max: float = 384.0

## 1 = walking right, -1 = walking left. Flips on edge wrap.
@export var direction: int = 1

## Body / fur colour. Default is tabby orange.
@export var body_color: Color = Color("#C8843A")

## Stripe colour drawn on top of the body for tabby texture.
@export var stripe_color: Color = Color("#5A2A12")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

enum State { WALKING, SITTING }
var _state: State = State.WALKING
var _state_t: float = 0.0           ## time spent in current state
var _state_duration: float = 0.0    ## how long this state will last
var _x: float = 0.0
var _t: float = 0.0                 ## global accumulator (walk cycle, tail)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_x = x_min if direction > 0 else x_max
	position = Vector2(roundf(_x), lane_y)
	_pick_new_state_duration()


func _process(delta: float) -> void:
	# Test mode: freeze so unit tests aren't time-dependent.
	if Game.test_mode:
		return
	_t += delta
	_state_t += delta
	if _state == State.WALKING:
		_x += WALK_SPEED * delta * float(direction)
		if direction > 0 and _x > x_max:
			_x = x_min
		elif direction < 0 and _x < x_min:
			_x = x_max
		position = Vector2(roundf(_x), lane_y)
	# State transition?
	if _state_t >= _state_duration:
		_toggle_state()
	queue_redraw()


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func _toggle_state() -> void:
	_state = State.SITTING if _state == State.WALKING else State.WALKING
	_state_t = 0.0
	_pick_new_state_duration()
	# Occasionally flip direction when standing up so the cat doesn't always
	# go the same way after a sit.
	if _state == State.WALKING and randi() % 3 == 0:
		direction = -direction


func _pick_new_state_duration() -> void:
	if _state == State.WALKING:
		_state_duration = randf_range(WALK_DURATION_MIN, WALK_DURATION_MAX)
	else:
		_state_duration = randf_range(SIT_DURATION_MIN, SIT_DURATION_MAX)


# ---------------------------------------------------------------------------
# Drawing — small cat silhouette, faces direction of travel
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Tail twitches with a sine wave; sitting amplifies the twitch.
	var tail_amp: float = 1.5 if _state == State.SITTING else 0.6
	var tail_offset: int = int(round(sin(_t * 4.0) * tail_amp))
	# Walking-step bob alternates the back leg height.
	var step_phase: int = int(_t / STEP_PERIOD * 2.0) % 2
	var bob: float = -1.0 if (_state == State.WALKING and step_phase == 0) else 0.0
	# Mirror coordinates for left-facing.
	var dir: int = direction
	# Body dimensions: 8 wide × 4 tall when walking, 5 wide × 5 tall sitting.
	if _state == State.WALKING:
		_draw_walking(dir, bob, step_phase, tail_offset)
	else:
		_draw_sitting(dir, tail_offset)


func _draw_walking(dir: int, bob: float, step_phase: int, tail_offset: int) -> void:
	# Body — horizontal blob.
	# Front of body sits at +x of front_dir; head perches on the front.
	var front_dx: float = 3.0 * float(dir)
	# Body block (centred on origin)
	draw_rect(Rect2(-4, -2 + bob, 8, 3), body_color)
	# Tabby stripes
	draw_rect(Rect2(-3, -2 + bob, 1, 3), stripe_color)
	draw_rect(Rect2(0, -2 + bob, 1, 3), stripe_color)
	# Head — 3×3 in front, with two ears.
	var hx: float = front_dx
	draw_rect(Rect2(hx - 1, -3 + bob, 3, 3), body_color)
	# Ears (two 1×1 triangles approximated by single pixels)
	draw_rect(Rect2(hx - 1, -4 + bob, 1, 1), body_color)
	draw_rect(Rect2(hx + 1, -4 + bob, 1, 1), body_color)
	# Eye (single pixel facing front)
	draw_rect(Rect2(hx + float(dir), -3 + bob, 1, 1), Color("#1A0F0A"))
	# Legs — alternate (4 legs total)
	var leg_color: Color = body_color.darkened(0.25)
	if step_phase == 0:
		draw_rect(Rect2(-3, 1 + bob, 1, 2), leg_color)  # back-rear
		draw_rect(Rect2(0, 1 + bob, 1, 2), leg_color)   # back-front
		draw_rect(Rect2(2, 1 + bob, 1, 1), leg_color)   # front-rear (lifted)
		draw_rect(Rect2(-1, 1 + bob, 1, 1), leg_color)  # front-front (lifted)
	else:
		draw_rect(Rect2(-3, 1 + bob, 1, 1), leg_color)
		draw_rect(Rect2(0, 1 + bob, 1, 1), leg_color)
		draw_rect(Rect2(2, 1 + bob, 1, 2), leg_color)
		draw_rect(Rect2(-1, 1 + bob, 1, 2), leg_color)
	# Tail — at the back.
	var tail_x: float = -5.0 * float(dir)
	draw_rect(Rect2(tail_x, -2 + bob + float(tail_offset), 1, 1), body_color)
	draw_rect(Rect2(tail_x + float(dir), -3 + bob + float(tail_offset),
		1, 1), body_color)


func _draw_sitting(dir: int, tail_offset: int) -> void:
	# Compact upright posture — body curves up, head stacked.
	# Lower body / haunches
	draw_rect(Rect2(-3, 0, 6, 3), body_color)
	# Tabby haunch stripe
	draw_rect(Rect2(-2, 0, 1, 3), stripe_color)
	draw_rect(Rect2(1, 0, 1, 3), stripe_color)
	# Upper torso / chest
	draw_rect(Rect2(-2, -3, 4, 3), body_color)
	# Head 3×3 centred on top
	var hx: float = float(dir)
	draw_rect(Rect2(hx - 2, -5, 3, 2), body_color)
	# Ears (triangles)
	draw_rect(Rect2(hx - 2, -6, 1, 1), body_color)
	draw_rect(Rect2(hx, -6, 1, 1), body_color)
	# Eyes — two pixels
	draw_rect(Rect2(hx - 1, -4, 1, 1), Color("#1A0F0A"))
	draw_rect(Rect2(hx + 1, -4, 1, 1), Color("#1A0F0A"))
	# Front paws (folded together below chest)
	draw_rect(Rect2(-1, 1, 2, 1), body_color.darkened(0.25))
	# Tail curling behind, twitching
	var tail_x: float = -4.0 * float(dir)
	draw_rect(Rect2(tail_x, 1 + float(tail_offset), 1, 1), body_color)
	draw_rect(Rect2(tail_x + float(dir), 0 + float(tail_offset),
		1, 1), body_color)
	draw_rect(Rect2(tail_x + 2.0 * float(dir), -1 + float(tail_offset),
		1, 1), body_color)
