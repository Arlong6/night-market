## Rain weather event for Night Market Shopping (v0.21).
##
## Purely visual CanvasLayer that draws ~30 diagonal rain streaks raining
## across the screen for a fixed duration. Spawned by ShilinMarket with a
## 30% chance per run. Fades in / out so it doesn't pop.
##
## Drawn at layer 8 — above the world (player layer 0) but under the HUD
## (layer 10) and dialogue (layer 15). Self-frees once the duration is up.
class_name RainOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## Total duration of the event in seconds (fade-in + steady + fade-out).
const TOTAL_DURATION: float = 8.0
const FADE_IN: float = 0.6
const FADE_OUT: float = 1.0

## Number of streaks rendered each frame.
const STREAK_COUNT: int = 30

## Each streak is `STREAK_LEN` pixels long, falling at ~80px/sec.
const STREAK_LEN: int = 6
const STREAK_SPEED: float = 110.0
const STREAK_SLANT: float = 2.0  ## px of horizontal drift per pixel of fall

const COLOR_RAIN: Color = Color("#A0C4E0")  ## pale cyan

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

class _Streak:
	var x: float = 0.0
	var y: float = 0.0


var _streaks: Array[_Streak] = []
var _t: float = 0.0
var _control: Control = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 8
	# Spawn the streaks pre-distributed across the screen so the first frame
	# is already raining (no "delay until first streak appears" feel).
	for i in STREAK_COUNT:
		var s: _Streak = _Streak.new()
		s.x = randf() * float(VIEWPORT_W)
		s.y = randf() * float(VIEWPORT_H)
		_streaks.append(s)
	# Use a Control + draw via _draw so the rain renders on the canvas layer.
	_control = Control.new()
	_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_control.draw.connect(_draw_rain)
	add_child(_control)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	if _t >= TOTAL_DURATION:
		queue_free()
		return
	# Advance every streak; wrap when it leaves the bottom.
	for s in _streaks:
		s.y += STREAK_SPEED * delta
		s.x += STREAK_SLANT * STREAK_SPEED * delta * 0.1
		if s.y > float(VIEWPORT_H) + float(STREAK_LEN):
			s.y = -float(STREAK_LEN) - randf() * 30.0
			s.x = randf() * float(VIEWPORT_W)
	if _control != null:
		_control.queue_redraw()


# ---------------------------------------------------------------------------
# Drawing — diagonal streak per entry, faded by overall envelope.
# ---------------------------------------------------------------------------

func _draw_rain() -> void:
	if _control == null:
		return
	var alpha: float = _envelope_alpha()
	var c: Color = COLOR_RAIN
	c.a = alpha * 0.65
	for s in _streaks:
		# Slanted streak drawn as a short vertical line offset diagonally.
		# Approximate with 2 rectangles for thickness.
		_control.draw_rect(Rect2(s.x, s.y, 1.0, float(STREAK_LEN)), c)
		var c2: Color = COLOR_RAIN
		c2.a = alpha * 0.35
		_control.draw_rect(Rect2(s.x + 1.0, s.y + 2.0, 1.0, float(STREAK_LEN) - 2.0), c2)


## 0..1 envelope over the lifetime: ramps in over FADE_IN, holds at 1, ramps
## out over FADE_OUT before queue_free.
func _envelope_alpha() -> float:
	if _t < FADE_IN:
		return _t / FADE_IN
	var hold_end: float = TOTAL_DURATION - FADE_OUT
	if _t < hold_end:
		return 1.0
	var fade_t: float = (TOTAL_DURATION - _t) / FADE_OUT
	return clampf(fade_t, 0.0, 1.0)
