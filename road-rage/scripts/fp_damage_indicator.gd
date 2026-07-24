## FPDamageIndicator — a red arc at screen centre showing the DIRECTION an
## incoming hit came from, relative to where the player is looking. FPMain sets
## `arc_angle` (radians: 0 = dead ahead, +clockwise / to the right) and `alpha`
## each frame; this node just draws the wedge. Works in both car and foot modes
## because FPMain derives the angle from the active camera's forward vector.
class_name FPDamageIndicator
extends Control

const CX: float = 480.0    ## screen centre (960x540 HUD space)
const CY: float = 270.0
const R0: float = 88.0     ## inner radius of the arc
const R1: float = 150.0    ## outer radius (the pointed edge)
const HALF: float = 0.44   ## half the arc's angular width (radians)
const SEGMENTS: int = 10

var arc_angle: float = 0.0
var alpha: float = 0.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if alpha <= 0.01:
		return
	var a0: float = clampf(alpha, 0.0, 1.0)
	var pts := PackedVector2Array()
	# Outer arc left -> right.
	for i in SEGMENTS + 1:
		var a: float = arc_angle - HALF + (2.0 * HALF) * (float(i) / float(SEGMENTS))
		pts.append(Vector2(CX + sin(a) * R1, CY - cos(a) * R1))
	# Inner arc right -> left (closes the ring segment).
	for i in SEGMENTS + 1:
		var a: float = arc_angle + HALF - (2.0 * HALF) * (float(i) / float(SEGMENTS))
		pts.append(Vector2(CX + sin(a) * R0, CY - cos(a) * R0))
	draw_colored_polygon(pts, Color(0.95, 0.12, 0.10, 0.72 * a0))
