## Typhoon wind / debris overlay (v0.45).
##
## Drifts a handful of small "leaves" horizontally across the viewport on
## typhoon days, layered above the world but below the rain so the storm
## reads as wind-driven rather than just heavy precipitation.
##
## Pure visual — no game-state interaction. Set persistent=true and the
## overlay sticks for the whole scene; otherwise it self-frees after a
## short hold. The level only spawns this when current_weather() == TYPHOON.
class_name WindOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## Number of leaves drifting at any moment. Sparser than rain so the eye
## still reads each one as an individual leaf rather than a streak.
const LEAF_COUNT: int = 8

## Horizontal speed range — wind blows roughly left-to-right across the
## market. Negative speeds aren't supported; we just choose direction at
## construction time via the `direction` field.
const SPEED_MIN: float = 60.0
const SPEED_MAX: float = 110.0

## Vertical drift — leaves rise and fall on a slow sin so they look like
## they're being lifted by gusts rather than falling straight.
const VDRIFT_AMP: float = 6.0
const VDRIFT_FREQ: float = 1.4

## Leaf palette — autumn browns + market debris (paper bag, plastic bag).
const LEAF_COLORS: Array[Color] = [
	Color("#8A4A22"),  ## brown leaf
	Color("#A86420"),  ## copper leaf
	Color("#D8C040"),  ## yellow leaf
	Color("#E8E4D8"),  ## white plastic bag scrap
]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

class _Leaf:
	var x: float = 0.0
	var y: float = 0.0
	var base_y: float = 0.0
	var speed: float = 80.0
	var color: Color = Color.WHITE
	var phase: float = 0.0
	var size: int = 2  ## 2 or 3 px wide blob


var _leaves: Array[_Leaf] = []
var _t: float = 0.0
var _control: Control = null

## +1 = wind blows right, -1 = blows left. Set by spawner before add_child
## so the overall direction reads consistent across all leaves.
@export var direction: int = 1


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Layer 9 — above world (0) and rain (8) but under HUD (10).
	layer = 9
	for i in LEAF_COUNT:
		var lf: _Leaf = _Leaf.new()
		# Pre-distribute across the screen so the first frame is alive.
		lf.x = randf() * float(VIEWPORT_W)
		lf.base_y = randf_range(20.0, float(VIEWPORT_H) - 30.0)
		lf.y = lf.base_y
		lf.speed = randf_range(SPEED_MIN, SPEED_MAX)
		lf.color = LEAF_COLORS[randi() % LEAF_COLORS.size()]
		lf.phase = randf() * TAU
		lf.size = 3 if randf() < 0.4 else 2
		_leaves.append(lf)
	_control = Control.new()
	_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_control.draw.connect(_draw_leaves)
	add_child(_control)


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	for lf in _leaves:
		lf.x += lf.speed * delta * float(direction)
		# Wrap horizontally based on direction so leaves loop forever.
		if direction > 0 and lf.x > float(VIEWPORT_W) + 6.0:
			lf.x = -6.0
			lf.base_y = randf_range(20.0, float(VIEWPORT_H) - 30.0)
		elif direction < 0 and lf.x < -6.0:
			lf.x = float(VIEWPORT_W) + 6.0
			lf.base_y = randf_range(20.0, float(VIEWPORT_H) - 30.0)
		# Vertical drift — sin wobble around base_y.
		lf.y = lf.base_y + sin(_t * VDRIFT_FREQ + lf.phase) * VDRIFT_AMP
	if _control != null:
		_control.queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw_leaves() -> void:
	if _control == null:
		return
	for lf in _leaves:
		var s: float = float(lf.size)
		_control.draw_rect(Rect2(lf.x, lf.y, s, s), lf.color)
		# 1px shadow under the leaf for tiny depth — same colour darkened.
		var shadow: Color = lf.color.darkened(0.40)
		_control.draw_rect(Rect2(lf.x, lf.y + s, s, 1.0), shadow)
