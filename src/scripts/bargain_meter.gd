## Skill-based bargaining minigame for Night Market Shopping (v0.22).
##
## When the player picks 殺價, instead of the old single 60% random roll,
## a horizontal coloured bar appears with a cursor zipping back and forth.
## The player presses interact to lock the cursor; landing zone determines
## the tier of the bargain:
##
##   tier 0 (RED):    fail    → vendor charges +10% (current penalty)
##   tier 1 (YELLOW): partial → -10% off the listed price
##   tier 2 (GREEN):  jackpot → -20% off (matches the old success rate)
##
## Locks Game.in_dialogue while active so the player can't walk away mid-
## bargain. Self-frees 0.6s after resolving so the player sees the result.
class_name BargainMeter
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted with the resolved tier (0 / 1 / 2).
signal resolved(tier: int)

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const BAR_W: int = 100
const BAR_H: int = 14
const BAR_X: int = (VIEWPORT_W - BAR_W) / 2
const BAR_Y: int = 96     # mid-screen so dialogue (bottom) doesn't overlap

## Zone fractions across the bar (0..1 from left).
const RED_END_LEFT: float = 0.30
const YELLOW_END_LEFT: float = 0.42
const GREEN_END: float = 0.58
const YELLOW_END_RIGHT: float = 0.70
# (1.0 - YELLOW_END_RIGHT) fraction is the right red zone.

const CURSOR_W: int = 3
const CURSOR_H: int = 18

const CURSOR_SPEED: float = 130.0
## Auto-fail if the player just stares at the bar for this many seconds.
const TIMEOUT: float = 5.0
## How long the cursor freezes at the resolution position before despawn.
const RESULT_HOLD: float = 0.6

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_BG: Color = Color(0.0, 0.0, 0.0, 0.7)
const COLOR_FRAME: Color = Color("#F5EDDA")
const COLOR_RED: Color = Color("#C2241A")
const COLOR_YELLOW: Color = Color("#F2A227")
const COLOR_GREEN: Color = Color("#7AC940")
const COLOR_CURSOR: Color = Color("#F5EDDA")
const COLOR_LABEL: Color = Color("#F5EDDA")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _cursor_x: float = 0.0
var _direction: float = 1.0
var _t: float = 0.0
var _control: Control = null
var _resolved: bool = false
var _lock_x: float = 0.0
var _result_color: Color = COLOR_RED
var _was_dialogue_locked: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 16   # above dialogue (15) and HUD (10)
	# Lock player movement while the bar is up.
	_was_dialogue_locked = Game.in_dialogue
	Game.in_dialogue = true
	# Cursor starts at left and walks right.
	_cursor_x = 0.0
	_direction = 1.0
	_control = Control.new()
	_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_control.draw.connect(_draw_meter)
	add_child(_control)
	set_process_unhandled_input(true)


func _exit_tree() -> void:
	# Restore the previous in_dialogue state on despawn.
	Game.in_dialogue = _was_dialogue_locked


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	if _resolved:
		if _t >= RESULT_HOLD:
			queue_free()
		if _control != null:
			_control.queue_redraw()
		return
	if _t >= TIMEOUT:
		_resolve(_cursor_x)
		return
	_cursor_x += _direction * CURSOR_SPEED * delta
	if _cursor_x >= float(BAR_W):
		_cursor_x = float(BAR_W)
		_direction = -1.0
	elif _cursor_x <= 0.0:
		_cursor_x = 0.0
		_direction = 1.0
	if _control != null:
		_control.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _resolved:
		return
	if event.is_action_pressed("interact"):
		_resolve(_cursor_x)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Resolution — figure out the landing tier
# ---------------------------------------------------------------------------

## Returns the tier index for a cursor x position (in 0..BAR_W).
##   2 = GREEN (jackpot), 1 = YELLOW (partial), 0 = RED (fail)
static func tier_for_x(x: float) -> int:
	var fraction: float = clampf(x / float(BAR_W), 0.0, 1.0)
	if fraction < RED_END_LEFT:
		return 0
	if fraction < YELLOW_END_LEFT:
		return 1
	if fraction < GREEN_END:
		return 2
	if fraction < YELLOW_END_RIGHT:
		return 1
	return 0


func _resolve(x: float) -> void:
	_resolved = true
	_lock_x = x
	_t = 0.0
	var tier: int = tier_for_x(x)
	_result_color = COLOR_RED
	if tier == 2:
		_result_color = COLOR_GREEN
	elif tier == 1:
		_result_color = COLOR_YELLOW
	# Audio on the core mechanic: bright chime for a green clutch, a soft tick for
	# a yellow partial, a denial blip for a red miss. The bargain landing was
	# silent before — half its dopamine was missing.
	if tier == 2:
		Sfx.play_chime()
	elif tier == 1:
		Sfx.play_choice()
	else:
		Sfx.play_denial()
	resolved.emit(tier)


# ---------------------------------------------------------------------------
# Drawing — coloured zone bar + locking cursor
# ---------------------------------------------------------------------------

func _draw_meter() -> void:
	if _control == null:
		return
	var w: float = float(BAR_W)
	# Backdrop
	_control.draw_rect(
		Rect2(BAR_X - 6, BAR_Y - 14, BAR_W + 12, BAR_H + 26), COLOR_BG
	)
	# Frame around the bar
	_control.draw_rect(
		Rect2(BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2), COLOR_FRAME
	)
	# 5 zones (red / yellow / green / yellow / red)
	_control.draw_rect(Rect2(BAR_X, BAR_Y, RED_END_LEFT * w, BAR_H), COLOR_RED)
	_control.draw_rect(Rect2(
		BAR_X + RED_END_LEFT * w, BAR_Y,
		(YELLOW_END_LEFT - RED_END_LEFT) * w, BAR_H
	), COLOR_YELLOW)
	_control.draw_rect(Rect2(
		BAR_X + YELLOW_END_LEFT * w, BAR_Y,
		(GREEN_END - YELLOW_END_LEFT) * w, BAR_H
	), COLOR_GREEN)
	_control.draw_rect(Rect2(
		BAR_X + GREEN_END * w, BAR_Y,
		(YELLOW_END_RIGHT - GREEN_END) * w, BAR_H
	), COLOR_YELLOW)
	_control.draw_rect(Rect2(
		BAR_X + YELLOW_END_RIGHT * w, BAR_Y,
		(1.0 - YELLOW_END_RIGHT) * w, BAR_H
	), COLOR_RED)
	# Cursor — frozen on resolve, otherwise live position
	var cx: float = _lock_x if _resolved else _cursor_x
	var cursor_color: Color = _result_color if _resolved else COLOR_CURSOR
	_control.draw_rect(Rect2(
		float(BAR_X) + cx - float(CURSOR_W) / 2.0,
		float(BAR_Y) - 2.0, float(CURSOR_W), float(CURSOR_H)
	), cursor_color)
	# Tiny instruction label above the bar
	if not _resolved:
		# Hint: just three dots indicating "press SPACE in the green zone"
		# Drawn as 1-pixel marks above the green zone for readability without
		# needing a font load on this CanvasLayer.
		var hint_y: float = float(BAR_Y) - 6.0
		var center: float = float(BAR_X) + float(BAR_W) / 2.0
		_control.draw_rect(Rect2(center - 5.0, hint_y, 1.0, 2.0), COLOR_GREEN)
		_control.draw_rect(Rect2(center, hint_y, 1.0, 2.0), COLOR_GREEN)
		_control.draw_rect(Rect2(center + 4.0, hint_y, 1.0, 2.0), COLOR_GREEN)
