## Ground obstacle for Night Market Runner.
## A static wall the player must jump over (scooter / trash bag / crate).
## Origin at foot-centre (bottom-centre of the body) — matches Player convention.
## Visual drawn via _draw(); no sprite assets needed.
class_name ObstacleGround
extends StaticBody2D

# ---------------------------------------------------------------------------
# Exports — configurable per-instance in the editor or via code in tests
# ---------------------------------------------------------------------------

## Width of the collision box (px). Also drives the visual width.
@export var width: float = 24.0
## Height of the collision box (px). Also drives the visual height.
@export var height: float = 24.0

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const BODY_COLOUR: Color = Color("#555555")
const HAZARD_COLOUR: Color = Color("#D94F2B")
const HAZARD_EDGE_H: float = 2.0   ## height of hazard tint stripe on top edge

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

var _collision_shape: CollisionShape2D

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_collision_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width, height)
	_collision_shape.shape = rect
	# Offset so bottom edge sits at local y=0 (foot-centre convention).
	_collision_shape.position = Vector2(0.0, -height / 2.0)
	add_child(_collision_shape)

	# Snap to integer pixel position on spawn.
	position = position.round()


func _draw() -> void:
	# Body rectangle: top-left at (-w/2, -h), width×height.
	draw_rect(Rect2(-width / 2.0, -height, width, height), BODY_COLOUR)

	# Hazard stripe: 2px band across the very top edge.
	draw_rect(Rect2(-width / 2.0, -height, width, HAZARD_EDGE_H), HAZARD_COLOUR)
