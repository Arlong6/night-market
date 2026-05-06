## Rain puddle for Night Market Shopping (v0.44).
##
## Pure visual decoration — small dark blob drawn at a walkable cell on
## rainy / typhoon days. Player cell_changed listener (in shilin_market.gd)
## triggers a splash burst when the player steps on the puddle cell, but
## the puddle itself doesn't move or block movement.
##
## A subtle ripple wobble (sin(time)) gives it a "rain still falling" feel
## so the market doesn't read as static between footsteps.
class_name Puddle
extends Node2D

## Grid cell where this puddle sits. ShilinMarket converts to pixel position.
@export var cell: Vector2i = Vector2i.ZERO

## Heavy puddles (typhoon days) are bigger + darker than the light tier.
@export var heavy: bool = false

const COLOR_LIGHT: Color = Color("#3A4A6A", 0.55)
const COLOR_HEAVY: Color = Color("#1A2A4A", 0.75)
const COLOR_HIGHLIGHT: Color = Color("#A0B8D8", 0.65)

var _t: float = 0.0


func _ready() -> void:
	# z_index puts puddles between the floor and the player so the player
	# walks "over" them rather than disappearing under them.
	z_index = -1


func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	queue_redraw()


## Two stacked rounded rects approximate an ellipse at low res. The
## highlight pixel scoots back and forth so the puddle visibly ripples.
func _draw() -> void:
	var base: Color = COLOR_HEAVY if heavy else COLOR_LIGHT
	var w: float = 9.0 if heavy else 7.0
	var w2: float = w + 2.0  ## widest middle row
	# Centred on cell pixel; sits low (y=2..4) so it reads as on the ground.
	draw_rect(Rect2(-w * 0.5, 2.0, w, 1.0), base)
	draw_rect(Rect2(-w2 * 0.5, 3.0, w2, 1.0), base)
	draw_rect(Rect2(-w * 0.5, 4.0, w, 1.0), base)
	# Ripple highlight — single bright pixel that drifts left/right.
	var phase: float = sin(_t * 2.0)
	var hx: float = phase * (w * 0.3)
	draw_rect(Rect2(roundf(hx) - 0.5, 3.0, 1.0, 1.0), COLOR_HIGHLIGHT)
