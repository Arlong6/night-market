## Player character for Night Market Runner.
## Implements run, jump (with coyote time + jump buffer + jump-cut), and duck.
## Physics constants are LOCKED from prototype playtest — do not retune.
class_name Player
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the player falls below y = 240 (off the world).
signal died

## Emitted on the physics frame the player leaves the ground via jump or walk-off.
## Parent scene uses this to spawn jump-dust VFX.
signal jumped

## Emitted on the physics frame the player transitions from airborne to grounded.
## Parent scene uses this to spawn landing-dust VFX + optional camera land shake.
signal landed

# ---------------------------------------------------------------------------
# Physics constants — LOCKED from prototype playtest ("完美"). Do not retune.
# ---------------------------------------------------------------------------

const MOVE_SPEED: float = 110.0       ## px/s horizontal run speed
const JUMP_VELOCITY: float = -250.0   ## px/s initial jump velocity (up = negative)
const GRAVITY: float = 800.0          ## px/s² downward acceleration
const JUMP_CUT_MULT: float = 0.5      ## multiplier applied to vy on early jump release
const COYOTE_TIME: float = 0.10       ## seconds player may still jump after leaving ground
const JUMP_BUFFER: float = 0.10       ## seconds a pre-landing jump press is remembered
const DUCK_MOVE_MULT: float = 0.6     ## horizontal speed multiplier while ducking
const STAND_H: float = 40.0           ## collision height when standing (px)
const DUCK_H: float = 20.0            ## collision height when ducking (px)
const PLAYER_W: float = 24.0          ## collision / visual width (px)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Timer counting down time remaining where coyote jump is still valid.
## Refreshed to COYOTE_TIME on floor contact; decrements while airborne.
var _coyote_timer: float = 0.0

## Timer counting down the jump-buffer window.
## Set to JUMP_BUFFER on jump press; jump fires when this > 0 AND landing occurs.
var _jump_buffer_timer: float = 0.0

## Whether the player is currently in the ducked state.
var _is_ducking: bool = false

## Previous frame's jump pressed state, for edge detection.
## Used instead of Input.is_action_just_*_pressed/released because those
## engine flags depend on InputEvent flow which is not always exercised
## in test environments (Input.action_press() alone does not set them).
var _was_jump_pressed: bool = false

## Previous frame's on-floor state, for landed/jumped edge detection.
var _was_on_floor: bool = false

## Active squash intensity applied to _draw only (does not affect physics).
## X, Y offsets from 1.0 (e.g. Vector2(-0.15, 0.20) = thinner + taller).
var _squash_intensity: Vector2 = Vector2.ZERO

## Seconds elapsed into the current squash animation. >= SQUASH_DURATION = idle.
var _squash_elapsed: float = 99.0

## Accumulated ground-run time, used to drive the step bob.
var _run_time: float = 0.0

# ---------------------------------------------------------------------------
# Animation constants
# ---------------------------------------------------------------------------

## Total time for a squash-and-stretch to play out and return to rest.
const SQUASH_DURATION: float = 0.18
## Stretch shape applied on takeoff: thinner + taller.
const SQUASH_TAKEOFF: Vector2 = Vector2(-0.18, 0.22)
## Squash shape applied on landing: wider + shorter.
const SQUASH_LAND: Vector2 = Vector2(0.30, -0.30)
## Steps per second during the run bob cycle.
const RUN_BOB_HZ: float = 6.0

# ---------------------------------------------------------------------------
# Node references — set in _ready, NOT in the scene tree (programmatic scene)
# ---------------------------------------------------------------------------

var _collision_shape: CollisionShape2D

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Collision shape.
	# Anchor strategy: CharacterBody2D origin = foot centre.
	# CollisionShape2D offset = -(height/2) so its bottom edge always sits
	# at local y=0 (the foot point). Changing height only requires updating
	# size.y and offset.y — the feet never move in world space.
	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PLAYER_W, STAND_H)
	_collision_shape.shape = rect
	_collision_shape.position = Vector2(0.0, -STAND_H / 2.0)
	add_child(_collision_shape)


func _physics_process(delta: float) -> void:
	# Snapshot jump input state once per frame for edge-detection.
	var jump_pressed_now: bool = Input.is_action_pressed("jump")
	var jump_just_pressed: bool = jump_pressed_now and not _was_jump_pressed
	var jump_just_released: bool = not jump_pressed_now and _was_jump_pressed
	_was_jump_pressed = jump_pressed_now

	_apply_gravity(delta)
	_update_coyote(delta)
	_handle_duck()
	_handle_horizontal()

	# Snapshot vy before _handle_jump so _handle_jump_cut can distinguish
	# "player was already mid-rise" (cut applies) from "jump fired this frame
	# from buffered input" (cut must NOT apply — would halve a fresh jump).
	var vy_before_jump: float = velocity.y
	var was_on_floor_pre_move: bool = _was_on_floor
	_handle_jump(delta, jump_just_pressed)
	_handle_jump_cut(jump_just_released, vy_before_jump)

	move_and_slide()

	# Belt-and-suspenders pixel snap (project.godot already has
	# snap_2d_transforms_to_pixel=true but sub-pixel drift is still possible
	# at certain velocities — explicit round() eliminates it).
	position = position.round()

	_update_ground_transition(was_on_floor_pre_move)
	_update_run_bob(delta)
	_update_squash(delta)
	queue_redraw()

	if position.y > 240.0:
		died.emit()


func _draw() -> void:
	# All coordinates are in local space with origin = foot centre.
	# Feet stay planted at y=0 under every animation (squash, bob).
	var base_h: float = DUCK_H if _is_ducking else STAND_H
	var base_straw_h: float = 3.0 if _is_ducking else 6.0

	# Squash-and-stretch is _visual only_ — scale about the foot line so the
	# feet never leave the floor. Intensity decays sin-shaped over SQUASH_DURATION.
	var current: Vector2 = _current_squash_intensity()
	var scale_x: float = 1.0 + current.x
	var scale_y: float = 1.0 + current.y
	var h: float = base_h * scale_y
	var w: float = PLAYER_W * scale_x
	var straw_h: float = base_straw_h * scale_y

	# Run-bob: on alternating steps, drop the body 1px. Pure visual; feet unchanged
	# (we draw the body 1px shorter, so its TOP is 1px lower while its bottom still
	# lives at y=0).
	var run_bob_y: float = _get_run_bob_offset()
	var visual_h: float = maxf(h + run_bob_y, 1.0)

	# Body: yellow rectangle, top-left at (-w/2, -visual_h)
	draw_rect(Rect2(-w / 2.0, -visual_h, w, visual_h), Color("#E8F542"))

	# Straw: 2×straw_h ink-black spike, -6px from centre horizontally, sitting
	# on top of the body. Scales x with the body so it slides inward on squash.
	var straw_x: float = -6.0 * scale_x
	draw_rect(
		Rect2(straw_x, -visual_h - straw_h, 2.0 * scale_x, straw_h),
		Color("#2A1A0A")
	)

# ---------------------------------------------------------------------------
# Public accessors (used by tests to inspect internal state)
# ---------------------------------------------------------------------------

## Whether the player is currently ducking.
func is_ducking() -> bool:
	return _is_ducking

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta


func _update_coyote(delta: float) -> void:
	if is_on_floor():
		# On the floor — refresh coyote window.
		_coyote_timer = COYOTE_TIME
	else:
		# Airborne — drain the coyote window.
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _handle_duck() -> void:
	# Duck is only permitted on the ground.
	var wants_duck: bool = Input.is_action_pressed("duck") and is_on_floor()

	if wants_duck and not _is_ducking:
		_set_collision_height(DUCK_H)
		_is_ducking = true
		queue_redraw()
	elif not wants_duck and _is_ducking:
		_try_stand()


func _handle_horizontal() -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")
	var speed: float = MOVE_SPEED * (DUCK_MOVE_MULT if _is_ducking else 1.0)
	velocity.x = input_dir * speed


func _handle_jump(delta: float, just_pressed: bool) -> void:
	# Feed the jump buffer on a fresh press (not while ducking).
	if just_pressed and not _is_ducking:
		_jump_buffer_timer = JUMP_BUFFER
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Fire the jump when both windows are open and we are not ducking.
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not _is_ducking:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _handle_jump_cut(just_released: bool, vy_before_jump: float) -> void:
	# Apply once on the exact frame the jump key is released while still rising,
	# AND only if the player was already mid-rise BEFORE _handle_jump ran this
	# frame. This prevents a buffered-on-landing jump (which fires this frame)
	# from being immediately halved by the same-frame jump release.
	if just_released and vy_before_jump < 0.0:
		velocity.y *= JUMP_CUT_MULT


func _set_collision_height(h: float) -> void:
	# Update both size and offset so the bottom edge (feet) stays at local y=0.
	var rect := _collision_shape.shape as RectangleShape2D
	rect.size = Vector2(PLAYER_W, h)
	_collision_shape.position = Vector2(0.0, -h / 2.0)


## Detects edges between airborne and grounded states and fires visual cues.
##   takeoff → squash_takeoff shape + `jumped` signal
##   landing → squash_land shape + `landed` signal
## Arg: whether player was on the floor at the START of this physics frame
## (before jump/move), to avoid same-frame thrash on a buffered jump.
func _update_ground_transition(was_on_floor_pre_move: bool) -> void:
	var on_floor_now: bool = is_on_floor()
	if was_on_floor_pre_move and not on_floor_now:
		_start_squash(SQUASH_TAKEOFF)
		jumped.emit()
	elif not was_on_floor_pre_move and on_floor_now:
		_start_squash(SQUASH_LAND)
		landed.emit()
	_was_on_floor = on_floor_now


## Advances the run-bob time only while the player is running on the ground.
## Decays to 0 instantly when the player stops moving.
func _update_run_bob(delta: float) -> void:
	if is_on_floor() and absf(velocity.x) > 1.0 and not _is_ducking:
		_run_time += delta
	else:
		_run_time = 0.0


## Advances the squash animation. sin(PI*t/dur) gives a smooth rise-and-fall
## so the effect peaks mid-duration and returns cleanly to rest.
func _update_squash(_delta: float) -> void:
	if _squash_elapsed >= SQUASH_DURATION:
		return
	_squash_elapsed += _delta


## Pure visual y-offset added to the body height during the run bob.
## Returns -1 on every second step phase, else 0. Feet stay planted.
func _get_run_bob_offset() -> float:
	if _run_time <= 0.0:
		return 0.0
	var phase: int = int(_run_time * RUN_BOB_HZ) % 2
	return -1.0 if phase == 0 else 0.0


func _start_squash(intensity: Vector2) -> void:
	_squash_intensity = intensity
	_squash_elapsed = 0.0


## Visual scale multiplier at the current moment in the squash animation.
## Used by _draw. Returns Vector2.ZERO intensity once the animation has ended.
func _current_squash_intensity() -> Vector2:
	if _squash_elapsed >= SQUASH_DURATION:
		return Vector2.ZERO
	var t: float = _squash_elapsed / SQUASH_DURATION
	var falloff: float = sin(t * PI)
	return _squash_intensity * falloff


func _try_stand() -> void:
	# Probe whether the full stand height fits using test_move.
	# Strategy: expand shape to STAND_H at current feet position, then test
	# a small upward motion. If anything collides, revert to duck.
	var height_delta: float = STAND_H - DUCK_H          # = 20.0 px
	var probe_offset: float = height_delta / 2.0         # = 10.0 px upward

	_set_collision_height(STAND_H)
	var blocked: bool = test_move(global_transform, Vector2(0.0, -probe_offset))

	if blocked:
		# Ceiling overhead — revert to duck, stay ducked.
		_set_collision_height(DUCK_H)
	else:
		# Clear — commit stand.
		_is_ducking = false
		queue_redraw()
