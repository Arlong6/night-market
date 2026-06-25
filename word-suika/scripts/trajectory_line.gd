## TrajectoryLine — draws a soft dashed vertical line from the spawn
## cursor straight down to the floor of the field.
##
## Position x is set by Main each frame to follow the cursor.
extends Node2D

var from_y: float = 0.0
var to_y: float = 0.0

func _draw() -> void:
	# Dashed segments: 8 px on, 6 px off
	var y: float = from_y
	var seg_on: float = 8.0
	var seg_off: float = 6.0
	while y < to_y:
		var y2: float = min(y + seg_on, to_y)
		# Fade with depth so the bottom is fainter than the top
		var depth: float = (y - from_y) / max(1.0, to_y - from_y)
		var alpha: float = lerp(0.35, 0.08, depth)
		draw_line(Vector2(0, y), Vector2(0, y2), Color(0.95, 0.85, 0.55, alpha), 2.0)
		y = y2 + seg_off
