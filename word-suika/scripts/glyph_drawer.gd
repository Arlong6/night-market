## GlyphDrawer — draws the colored circle background for a Glyph.
##
## Sits beneath the Label so the character reads on top.
## Reads the tier from either `glyph.tier` (when attached to a real Glyph)
## or directly from `direct_tier` (used by the preview where there's no Glyph).
extends Node2D

const TierData = preload("res://scripts/tier_data.gd")

var glyph: Node = null  # parent Glyph reference (optional)
var direct_tier: int = -1  # fallback when glyph is null

func _draw() -> void:
	var t: int = direct_tier
	if t < 0 and glyph != null:
		t = int(glyph.tier)
	if t < 0:
		return
	var data: Dictionary = TierData.get_tier(t)
	var r: float = data.radius
	var c: Color = data.color
	# Soft shadow/outer glow
	draw_circle(Vector2.ZERO, r + 2.0, Color(0.0, 0.0, 0.0, 0.18))
	# Main body
	draw_circle(Vector2.ZERO, r, c)
	# Inner highlight (top-left lighter)
	var highlight: Color = c.lightened(0.18)
	draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(highlight.r, highlight.g, highlight.b, 0.4))
	# Rim outline (thin darker ring for definition)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.15, 0.10, 0.08, 0.85), 1.5, true)
