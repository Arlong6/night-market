## AimRenderer — draws the aim arrow + charge bar in LAUNCH mode.
##
## Origin is the spawn point. Aim target is the cursor position.
## Charge is 0..1 (filled by holding the mouse button).
extends Node2D

var origin: Vector2 = Vector2.ZERO
var aim_target: Vector2 = Vector2.ZERO
var charge: float = 0.0

func _draw() -> void:
	var dir: Vector2 = (aim_target - origin)
	var dist: float = dir.length()
	if dist < 8.0:
		return
	var n: Vector2 = dir / dist
	# Length of the visual arrow scales with charge (clamped)
	var arrow_len: float = lerp(60.0, 320.0, charge)
	arrow_len = min(arrow_len, dist)
	var end: Vector2 = origin + n * arrow_len
	# Dashed shaft
	var seg_on: float = 10.0
	var seg_off: float = 6.0
	var t: float = 0.0
	while t < arrow_len:
		var t2: float = min(t + seg_on, arrow_len)
		var a: Vector2 = origin + n * t
		var b: Vector2 = origin + n * t2
		var alpha: float = lerp(0.85, 0.35, t / arrow_len)
		var col: Color = Color(1.0, 0.85, 0.4, alpha)
		draw_line(a, b, col, 3.0)
		t = t2 + seg_off
	# Arrow head
	var head_size: float = 14.0
	var head_dir: Vector2 = -n
	var left: Vector2 = head_dir.rotated(0.45) * head_size
	var right: Vector2 = head_dir.rotated(-0.45) * head_size
	draw_colored_polygon([end, end + left, end + right], Color(1.0, 0.85, 0.4, 0.9))
	# Charge bar at origin
	var bar_w: float = 88.0
	var bar_h: float = 10.0
	var bar_pos: Vector2 = Vector2(origin.x - bar_w * 0.5, origin.y - 60.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.0, 0.0, 0.0, 0.4), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * charge, bar_h)),
		Color(1.0, 0.8, 0.35, 0.95), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)),
		Color(0.95, 0.85, 0.55, 0.85), false, 1.0)
