## Hanging hazard for Night Market Runner.
## A sign suspended from an awning that the player must duck under.
## Origin is at the CENTRE of the sign body.
## Default top_y=78, height=20 → sign occupies world y=78..98.
## Standing player (head at y=80, feet y=120) overlaps → blocked.
## Ducking player (head at y=100, feet y=120): sign bottom y=98 → 2px gap, clears.
## Ropes are visual-only lines drawn upward from the sign's top edge — no colliders.
class_name ObstacleHanging
extends StaticBody2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Width of the sign body and its collision box (px).
@export var sign_width: float = 40.0
## Height of the sign body and its collision box (px).
@export var sign_height: float = 20.0
## World-y of the sign's TOP edge. Origin (node position.y) = top_y + sign_height/2.
@export var top_y: float = 78.0
## How far upward the rope lines extend from the sign's top edge (px).
@export var rope_length: float = 100.0

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const BODY_COLOUR: Color = Color("#D4920A")
const HAZARD_COLOUR: Color = Color("#D94F2B")
const ROPE_COLOUR: Color = Color("#2A1A0A")
const HAZARD_EDGE_H: float = 2.0   ## height of hazard tint stripe on bottom edge
const ROPE_X_OFFSET: float = 4.0   ## horizontal distance from centre to each rope

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

var _collision_shape: CollisionShape2D

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Position origin at sign centre (top_y + half height).
	position.y = top_y + sign_height / 2.0
	position = position.round()

	_collision_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(sign_width, sign_height)
	_collision_shape.shape = rect
	# Origin is centre → no offset needed.
	add_child(_collision_shape)


func _draw() -> void:
	var half_w: float = sign_width / 2.0
	var half_h: float = sign_height / 2.0

	# Sign body: centred on origin.
	draw_rect(Rect2(-half_w, -half_h, sign_width, sign_height), BODY_COLOUR)

	# Hazard stripe on BOTTOM edge (Godot y+ = down).
	draw_rect(
		Rect2(-half_w, half_h - HAZARD_EDGE_H, sign_width, HAZARD_EDGE_H),
		HAZARD_COLOUR
	)

	# Ropes: 1px wide, drawn from sign top edge upward by rope_length.
	# In local coords sign top is at y = -half_h.
	var rope_top_y: float = -half_h - rope_length
	draw_line(Vector2(-ROPE_X_OFFSET, -half_h), Vector2(-ROPE_X_OFFSET, rope_top_y), ROPE_COLOUR, 1.0)
	draw_line(Vector2(ROPE_X_OFFSET, -half_h), Vector2(ROPE_X_OFFSET, rope_top_y), ROPE_COLOUR, 1.0)
