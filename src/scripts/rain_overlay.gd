## Rain weather event for Night Market Shopping (v0.21, extended in v0.42).
##
## Purely visual CanvasLayer that draws diagonal rain streaks across the
## viewport. Two operating modes:
##
##   * Transient (persistent=false, default) — fades in for FADE_IN, holds
##     for TOTAL_DURATION - FADE_IN - FADE_OUT, fades out, frees self.
##     v0.21 random-shower behaviour preserved for backward-compat.
##   * Persistent (persistent=true, v0.42 weather mode) — fades in and
##     holds at full alpha for the rest of the scene. Driven by
##     Inventory.current_weather() == RAINY / TYPHOON.
##
## Two intensity tiers control streak density + brightness + darkening tint:
##   * "light"  — 30 streaks, pale cyan, mild dimming (rain)
##   * "heavy"  — 70 streaks, brighter, stronger dimming (typhoon)
##
## Drawn at layer 8 — above the world (player layer 0) but under the HUD
## (layer 10) and dialogue (layer 15).
class_name RainOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## Total duration of the event in seconds (fade-in + steady + fade-out).
## Only consulted when `persistent` is false.
const TOTAL_DURATION: float = 8.0
const FADE_IN: float = 0.6
const FADE_OUT: float = 1.0

## Streak counts per intensity tier. v0.42 — heavy is for typhoon days.
const STREAK_COUNT_LIGHT: int = 30
const STREAK_COUNT_HEAVY: int = 70

## Each streak is `STREAK_LEN` pixels long, falling at ~110px/sec (light)
## or 160 (heavy) for visual difference.
const STREAK_LEN: int = 6
const STREAK_SPEED_LIGHT: float = 110.0
const STREAK_SPEED_HEAVY: float = 160.0
const STREAK_SLANT: float = 2.0  ## px of horizontal drift per pixel of fall

const COLOR_RAIN_LIGHT: Color = Color("#A0C4E0")  ## pale cyan
const COLOR_RAIN_HEAVY: Color = Color("#C8E0F0")  ## brighter, almost white

## Darkening tint drawn under the streaks so the wet world reads dimmer.
## v0.42 — only applied in persistent mode (transient shower stays clear).
const COLOR_TINT_LIGHT: Color = Color(0.0, 0.0, 0.05, 0.15)
const COLOR_TINT_HEAVY: Color = Color(0.0, 0.0, 0.10, 0.32)

## v0.42 — opt-in flags for weather-driven persistent rain.
@export var persistent: bool = false
@export_enum("light", "heavy") var intensity: String = "light"

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
	var n: int = STREAK_COUNT_HEAVY if intensity == "heavy" \
		else STREAK_COUNT_LIGHT
	# Spawn the streaks pre-distributed across the screen so the first frame
	# is already raining (no "delay until first streak appears" feel).
	for i in n:
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
	# v0.42: persistent rain never expires (sticks for the whole scene).
	# Transient shower keeps the original v0.21 fade-out → free path.
	if not persistent and _t >= TOTAL_DURATION:
		queue_free()
		return
	var speed: float = STREAK_SPEED_HEAVY if intensity == "heavy" \
		else STREAK_SPEED_LIGHT
	# Advance every streak; wrap when it leaves the bottom.
	for s in _streaks:
		s.y += speed * delta
		s.x += STREAK_SLANT * speed * delta * 0.1
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
	# v0.42: darkening tint behind the streaks (persistent mode only — the
	# transient shower from v0.21 stays clear so it doesn't dim the scene
	# during a brief one-shot event).
	if persistent:
		var tint: Color = COLOR_TINT_HEAVY if intensity == "heavy" \
			else COLOR_TINT_LIGHT
		var tint_clamped: Color = tint
		tint_clamped.a *= alpha
		_control.draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), tint_clamped)
	var streak_color: Color = COLOR_RAIN_HEAVY if intensity == "heavy" \
		else COLOR_RAIN_LIGHT
	var c: Color = streak_color
	c.a = alpha * 0.65
	for s in _streaks:
		# Slanted streak drawn as a short vertical line offset diagonally.
		# Approximate with 2 rectangles for thickness.
		_control.draw_rect(Rect2(s.x, s.y, 1.0, float(STREAK_LEN)), c)
		var c2: Color = streak_color
		c2.a = alpha * 0.35
		_control.draw_rect(Rect2(s.x + 1.0, s.y + 2.0, 1.0, float(STREAK_LEN) - 2.0), c2)


## 0..1 envelope over the lifetime. Persistent rain only fades IN — once at
## full alpha, it stays there for the rest of the scene. Transient rain
## also fades out over FADE_OUT before queue_free (v0.21 behaviour).
func _envelope_alpha() -> float:
	if _t < FADE_IN:
		return _t / FADE_IN
	if persistent:
		return 1.0
	var hold_end: float = TOTAL_DURATION - FADE_OUT
	if _t < hold_end:
		return 1.0
	var fade_t: float = (TOTAL_DURATION - _t) / FADE_OUT
	return clampf(fade_t, 0.0, 1.0)
