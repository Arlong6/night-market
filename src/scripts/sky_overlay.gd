## Sky / time-of-day overlay for Night Market Shopping (v0.51).
##
## Draws a translucent navy tint over the world that deepens as
## Game.session_time advances. Three phases:
##
##   * 黃昏 (0..DUSK_END):       alpha 0 → DUSK_PEAK_ALPHA   (warm undertone)
##   * 夜晚 (DUSK_END..NIGHT_END): alpha climbs to NIGHT_PEAK
##   * 深夜 (NIGHT_END+):          stays at NIGHT_PEAK
##
## CanvasLayer at layer 1 — above the world (default 0), below lanterns (5)
## / rain (8) / wind (9) / HUD (10) / dialogue (15) so weather + UI stay
## crisp on top of the deepening sky.
class_name SkyOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## Phase boundaries in seconds of session_time. Designed so a casual run
## (~60s) ends in 夜晚 and a slow exploratory run (~120s) reaches 深夜.
const DUSK_END: float = 30.0
const NIGHT_END: float = 90.0

## Peak alphas per phase. Kept low so gameplay stays readable; the player
## should feel atmospheric, not blinded.
const DUSK_PEAK_ALPHA: float = 0.06
const NIGHT_PEAK_ALPHA: float = 0.20

## Phase tint hues. Dusk is warm orange; night is cool deep navy.
const COLOR_DUSK: Color = Color(0.40, 0.10, 0.05, 1.0)
const COLOR_NIGHT: Color = Color(0.05, 0.05, 0.20, 1.0)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _control: Control = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 1
	_control = Control.new()
	_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_control.draw.connect(_draw_sky)
	add_child(_control)


func _process(_delta: float) -> void:
	if _control != null:
		_control.queue_redraw()


# ---------------------------------------------------------------------------
# Drawing — single rect over the viewport, colour + alpha derived from time
# ---------------------------------------------------------------------------

func _draw_sky() -> void:
	if _control == null:
		return
	var t: float = current_session_time()
	var tint: Color = compute_tint(t)
	if tint.a <= 0.0:
		return
	_control.draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), tint)


# ---------------------------------------------------------------------------
# Public helpers (also used by lanterns + tests)
# ---------------------------------------------------------------------------

## Resolves the current session_time, defaulting to 0 when Game isn't loaded
## (eg. in isolated unit tests).
func current_session_time() -> float:
	var g: Node = get_node_or_null("/root/Game")
	if g == null:
		return 0.0
	return float(g.get("session_time"))


## Phase index for the given session_time. 0 = 黃昏, 1 = 夜晚, 2 = 深夜.
static func phase_index(t: float) -> int:
	if t < DUSK_END:
		return 0
	if t < NIGHT_END:
		return 1
	return 2


## Lerps between dusk and night colour + ramps alpha so the transition is
## smooth instead of snapping at phase boundaries.
static func compute_tint(t: float) -> Color:
	if t <= 0.0:
		return Color(0, 0, 0, 0)
	if t < DUSK_END:
		var k: float = clampf(t / DUSK_END, 0.0, 1.0)
		var c: Color = COLOR_DUSK
		c.a = DUSK_PEAK_ALPHA * k
		return c
	if t < NIGHT_END:
		var k: float = clampf(
			(t - DUSK_END) / (NIGHT_END - DUSK_END), 0.0, 1.0
		)
		var c: Color = COLOR_DUSK.lerp(COLOR_NIGHT, k)
		c.a = lerpf(DUSK_PEAK_ALPHA, NIGHT_PEAK_ALPHA, k)
		return c
	# 深夜 — hold at peak.
	var c: Color = COLOR_NIGHT
	c.a = NIGHT_PEAK_ALPHA
	return c
