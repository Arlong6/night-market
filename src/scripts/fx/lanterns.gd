## Hanging-lantern decoration for Night Market Shopping (v0.2 polish).
##
## Thin CanvasLayer wrapper that hosts a Control whose `_draw` paints the
## actual lantern row. CanvasLayer pulls it out of world transforms so the
## lanterns stay fixed at the top of the viewport regardless of camera scroll.
class_name Lanterns
extends CanvasLayer

const VIEWPORT_W: int = 320


func _ready() -> void:
	layer = 5  # behind HUD (10) + dialogue (15), in front of world

	var canvas: Control = Control.new()
	canvas.set_script(preload("res://scripts/fx/lanterns_canvas.gd"))
	canvas.size = Vector2(VIEWPORT_W, 32.0)
	canvas.position = Vector2.ZERO
	add_child(canvas)
