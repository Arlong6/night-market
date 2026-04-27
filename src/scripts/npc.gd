## Base NPC class for Night Market Shopping (R-004).
##
## Sits on a single grid cell and emits a dialogue when the player bumps it.
## Subclasses (StallNPC, MomNPC) override `on_bumped()` to add purchase /
## win-check behaviour.
class_name NPC
extends Node2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const NPC_SIZE: float = 14.0
const COLOR_BODY: Color = Color("#7A3A2A")  ## vendor brown placeholder
const COLOR_SKIN: Color = Color("#F2D6A8")  ## warm skin tone
const COLOR_HAIR: Color = Color("#2A1A0A")  ## near-black hair / outline
const COLOR_EYE: Color = Color("#2A1A0A")   ## near-black eyes

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Grid cell this NPC occupies. position is set from this in `_ready`.
@export var cell: Vector2i = Vector2i(0, 0)

## Dialogue lines shown on bump. Subclasses can override or extend.
@export var lines: Array[String] = ["..."]

## Per-NPC bob period (seconds per cycle). Slightly randomised in _ready so
## crowds don't sway in lockstep.
const BOB_PERIOD: float = 0.55

## Time accumulator for the idle Y bob.
var _bob_time: float = 0.0

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _ready() -> void:
	position = GridWorld.cell_to_px(cell)
	# Stagger the bob phase so adjacent NPCs don't bob in unison.
	_bob_time = randf() * BOB_PERIOD


func _process(delta: float) -> void:
	_bob_time += delta
	queue_redraw()


func _draw() -> void:
	var bob: float = _idle_bob_offset()
	_draw_person(_draw_color(), bob)


## Multi-rect "person" silhouette — head, body, legs, eyes — centred on the
## cell origin. Subclasses can override _draw() entirely for non-humanoid
## shapes (StallNPC) or override _draw_color() to recolour the shirt.
##
## Pixel layout in a 14×14 footprint (origin centre):
##   y=-7..-2: 6px head (skin) with hair stripe + eye dots
##   y=-2..+3: 5px torso (body color)
##   y=+3..+7: 4px legs split
func _draw_person(body_color: Color, bob: float) -> void:
	# Head — 6×6 skin square at top
	draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 6.0), COLOR_SKIN)
	# Hair stripe — 6×2 dark band capping the head
	draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 2.0), COLOR_HAIR)
	# Eyes — 1px dots, symmetric
	draw_rect(Rect2(-2.0, -4.0 + bob, 1.0, 1.0), COLOR_EYE)
	draw_rect(Rect2(1.0, -4.0 + bob, 1.0, 1.0), COLOR_EYE)
	# Torso — 8×5 body color
	draw_rect(Rect2(-4.0, -1.0 + bob, 8.0, 5.0), body_color)
	# Legs — two 2×4 rects split by 2px gap, slightly darker than body
	var legs: Color = body_color.darkened(0.35)
	draw_rect(Rect2(-3.0, 4.0 + bob, 2.0, 3.0), legs)
	draw_rect(Rect2(1.0, 4.0 + bob, 2.0, 3.0), legs)


## Pixel-snapped sin-based bob — rounds to {-1, 0, 1} so motion stays crisp.
func _idle_bob_offset() -> float:
	var phase: float = (_bob_time / BOB_PERIOD) * TAU
	return roundf(sin(phase))


# ---------------------------------------------------------------------------
# Public API — override points for subclasses
# ---------------------------------------------------------------------------

## Called by the level when the player bumps this NPC's cell.
## Default behaviour: show `lines`. Subclasses override for shop / win logic.
func on_bumped() -> void:
	if lines.is_empty():
		return
	Dialogue.show(lines)


## Subclasses can override to render in a different colour.
func _draw_color() -> Color:
	return COLOR_BODY
