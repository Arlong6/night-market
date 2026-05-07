## Inner Control that does the actual lantern drawing.
## Separated from Lanterns CanvasLayer so we can rely on Control._draw.
extends Control

const VIEWPORT_W: int = 320
const LANTERN_SPACING: int = 36
const LANTERN_RADIUS: float = 4.0
const LANTERN_BASE_Y: float = 8.0
const ROPE_LENGTH: float = 6.0
const BOB_AMPLITUDE: float = 1.0
const BOB_PERIOD: float = 1.6

const COLOR_LANTERN: Color = Color("#C2241A")
const COLOR_LANTERN_RIM: Color = Color("#F2A227")
const COLOR_ROPE: Color = Color("#2A1A0A")

## v0.51: warm halo drawn around each lantern as session_time advances.
## At 0s: halo invisible. At NIGHT_END+: halo at full alpha. Sells the
## "the lanterns light up as the night deepens" beat.
const HALO_COLOR: Color = Color("#F2A227", 0.0)
const HALO_PEAK_ALPHA: float = 0.50

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Continuous rope along the top
	draw_rect(Rect2(0.0, 1.0, VIEWPORT_W, 1.0), COLOR_ROPE)
	# v0.51: derive halo intensity from session_time. Stays at 0 in tests
	# where Game isn't running so deterministic snapshots don't shift.
	var halo_alpha: float = _halo_alpha_for_session_time()
	# Lanterns at evenly-spaced x positions, with each lantern's bob phase
	# offset by its index so they look chaotic, not synchronised.
	var idx: int = 0
	var x: float = LANTERN_SPACING / 2.0
	while x < float(VIEWPORT_W):
		var phase: float = (_t / BOB_PERIOD + float(idx) * 0.25) * TAU
		var bob_y: float = roundf(sin(phase) * BOB_AMPLITUDE)
		var cx: float = x
		var cy: float = LANTERN_BASE_Y + bob_y
		# Rope down to lantern top
		draw_rect(Rect2(cx, 2.0, 1.0, ROPE_LENGTH + bob_y), COLOR_ROPE)
		# v0.51: warm halo behind the lantern body — only visible at night.
		if halo_alpha > 0.0:
			var halo: Color = COLOR_LANTERN_RIM
			halo.a = halo_alpha * 0.5
			draw_rect(Rect2(cx - 4.0, cy - 4.0, 8.0, 8.0), halo)
			halo.a = halo_alpha
			draw_rect(Rect2(cx - 3.0, cy - 3.0, 6.0, 6.0), halo)
		# Lantern body — solid red square approximation (4×4 with gold rim)
		var r: float = LANTERN_RADIUS
		draw_rect(Rect2(cx - r / 2.0, cy - r / 2.0, r, r), COLOR_LANTERN)
		# Gold rim top + bottom
		draw_rect(Rect2(cx - r / 2.0, cy - r / 2.0, r, 1.0), COLOR_LANTERN_RIM)
		draw_rect(Rect2(cx - r / 2.0, cy + r / 2.0 - 1.0, r, 1.0), COLOR_LANTERN_RIM)
		idx += 1
		x += float(LANTERN_SPACING)


## Maps the current Game.session_time onto a [0, HALO_PEAK_ALPHA] envelope
## so the halo fades in over the dusk → night arc.
func _halo_alpha_for_session_time() -> float:
	var g: Node = get_node_or_null("/root/Game")
	if g == null:
		return 0.0
	var t: float = float(g.get("session_time"))
	if t <= 0.0:
		return 0.0
	# Reach peak alpha at NIGHT_END (matches SkyOverlay phase model).
	const NIGHT_END: float = 90.0
	var k: float = clampf(t / NIGHT_END, 0.0, 1.0)
	return HALO_PEAK_ALPHA * k
