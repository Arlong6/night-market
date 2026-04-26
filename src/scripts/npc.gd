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

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Grid cell this NPC occupies. position is set from this in `_ready`.
@export var cell: Vector2i = Vector2i(0, 0)

## Dialogue lines shown on bump. Subclasses can override or extend.
@export var lines: Array[String] = ["..."]

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _ready() -> void:
	position = GridWorld.cell_to_px(cell)


func _draw() -> void:
	var half: float = NPC_SIZE / 2.0
	draw_rect(Rect2(-half, -half, NPC_SIZE, NPC_SIZE), _draw_color())


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
