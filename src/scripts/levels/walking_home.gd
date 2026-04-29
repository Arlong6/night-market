## 回家路上 — Walking-home interlude (v0.28).
##
## A short parallax cutscene that sits between the mom-bump win and the
## kitchen scene. The kid walks home through the quiet post-market street
## with the shopping bags. Layers scroll right-to-left at different speeds
## (sky still, distant skyline slow, mid buildings medium, lampposts fast,
## street fastest) to sell the depth and travel.
##
## Auto-advances to "kitchen" after WALK_DURATION seconds. SPACE skips.
## In test_mode the auto-timer is suppressed so unit tests can assert the
## scene boots without a 5-second wait.
class_name WalkingHome
extends Node2D

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## How long the cutscene plays before auto-advancing to kitchen.
const WALK_DURATION: float = 4.5

# ---------------------------------------------------------------------------
# Layer scroll speeds (px/sec). Slowest = farthest. Sky doesn't scroll
# because nothing in the sky has parallax cues.
# ---------------------------------------------------------------------------

const SCROLL_SKYLINE: float = 4.0
const SCROLL_BUILDING: float = 16.0
const SCROLL_OVERHEAD: float = 18.0  # market lanterns trailing behind us
const SCROLL_LAMP: float = 42.0
const SCROLL_GROUND: float = 56.0

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_SKY: Color = Color("#1A1428")
const COLOR_SKYLINE: Color = Color("#0E0820")
const COLOR_BUILDING: Color = Color("#2A2030")
const COLOR_BUILDING_TOP: Color = Color("#3A2A40")
const COLOR_WINDOW_LIT: Color = Color("#F2A227")
const COLOR_WINDOW_DARK: Color = Color("#1A1208")
const COLOR_SIDEWALK: Color = Color("#3A3038")
const COLOR_SIDEWALK_LINE: Color = Color("#5A4848")
const COLOR_CURB: Color = Color("#1A1208")
const COLOR_ASPHALT: Color = Color("#1E1818")
const COLOR_LANE_LINE: Color = Color("#E8C870")
const COLOR_LAMPPOST: Color = Color("#2A1A0A")
const COLOR_LAMP_GLOW: Color = Color("#F2D8A0")
const COLOR_STAR: Color = Color("#F5EDDA")
const COLOR_LANTERN_BODY: Color = Color("#C2241A")
const COLOR_LANTERN_RIM: Color = Color("#F2A227")
const COLOR_BAG: Color = Color("#F5EDDA")
const COLOR_BAG_RIM: Color = Color("#888888")
const COLOR_VEGGIE: Color = Color("#7AC940")
const COLOR_HINT: Color = Color("#5A5060")

# ---------------------------------------------------------------------------
# Layout anchors
# ---------------------------------------------------------------------------

const HORIZON_Y: int = 120
const SIDEWALK_TOP: int = 120
const SIDEWALK_BOTTOM: int = 132
const ASPHALT_TOP: int = 134
const KID_X: int = 144
const KID_GROUND_Y: int = 130
const ROPE_Y: int = 4

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _t: float = 0.0
var _done: bool = false
var _hint_label: Label = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "walking_home"
	# Lift any leftover dialogue lock so the kitchen below opens cleanly.
	Game.in_dialogue = false
	set_process_unhandled_input(true)
	_build_skip_hint()
	if not Game.test_mode:
		# Defer auto-advance via a tree timer so SPACE can pre-empt it.
		get_tree().create_timer(WALK_DURATION).timeout.connect(_advance)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


## Single-shot transition to the kitchen — guarded so SPACE + the auto
## timer can both fire without double-loading the next scene.
func _advance() -> void:
	if _done:
		return
	_done = true
	Game.goto_level("kitchen")


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_skip_hint() -> void:
	_hint_label = Label.new()
	_hint_label.text = "空白鍵 略過"
	_hint_label.add_theme_font_override("font", _make_cjk_font())
	_hint_label.add_theme_font_size_override("font_size", 8)
	_hint_label.add_theme_color_override("font_color", COLOR_HINT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.size = Vector2(60, 10)
	_hint_label.position = Vector2(VIEWPORT_W - 64, VIEWPORT_H - 12)
	add_child(_hint_label)


func _make_cjk_font() -> FontFile:
	var f: FontFile = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


# ---------------------------------------------------------------------------
# Drawing — back to front
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_skyline()
	_draw_buildings()
	_draw_overhead_lanterns()
	_draw_lampposts()
	_draw_street()
	_draw_kid()


func _draw_sky() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, HORIZON_Y), COLOR_SKY)


func _draw_stars() -> void:
	# Static — stars are "infinitely distant" so they don't parallax.
	var positions: Array = [
		[12, 18], [45, 8], [78, 24], [112, 14], [156, 10],
		[198, 28], [234, 16], [268, 22], [298, 12], [202, 6],
		[34, 32], [88, 36], [142, 32], [248, 6], [314, 26],
	]
	for p in positions:
		draw_rect(Rect2(int(p[0]), int(p[1]), 1, 1), COLOR_STAR)


## Distant skyline silhouettes — slowest scroll. Pattern repeats every
## 320 px and is drawn twice for seamless wrap.
func _draw_skyline() -> void:
	var pattern_w: int = 320
	var off: float = fmod(_t * SCROLL_SKYLINE, float(pattern_w))
	var heights: Array = [40, 28, 35, 22, 30, 18, 25, 32, 20, 26, 38, 24]
	var widths: Array = [32, 28, 24, 30, 26, 22, 28, 30, 24, 28, 26, 22]
	for tile in 2:
		var base_x: float = float(tile * pattern_w) - off
		var x: float = base_x
		for i in heights.size():
			var h: int = int(heights[i])
			var w: int = int(widths[i])
			draw_rect(Rect2(x, HORIZON_Y - h, w, h), COLOR_SKYLINE)
			x += float(w)


## Mid-distance shop fronts with lit windows. Window pattern is a stable
## hash on (x, y) so adjacent windows look organic instead of striped.
func _draw_buildings() -> void:
	var pattern_w: int = 320
	var off: float = fmod(_t * SCROLL_BUILDING, float(pattern_w))
	# (x_offset, width, height) within one 320 px tile
	var blocks: Array = [
		[0, 50, 40], [54, 38, 50], [96, 56, 35], [156, 36, 55],
		[196, 44, 45], [244, 50, 40], [298, 22, 50],
	]
	for tile in 2:
		var base_x: float = float(tile * pattern_w) - off
		for b in blocks:
			var bx: float = float(int(b[0])) + base_x
			var bw: int = int(b[1])
			var bh: int = int(b[2])
			var by: int = HORIZON_Y - bh
			draw_rect(Rect2(bx, by, bw, bh), COLOR_BUILDING)
			# Roof highlight — 1 px lighter top edge
			draw_rect(Rect2(bx, by, bw, 1), COLOR_BUILDING_TOP)
			# Windows — 2×2 dots in a 6 px grid, lit/dark via stable hash
			var wy: int = by + 4
			while wy < by + bh - 4:
				var wx: int = int(bx) + 3
				while wx < int(bx) + bw - 4:
					var lit: bool = ((wx + wy * 7) % 13) < 5
					var wc: Color = COLOR_WINDOW_LIT if lit else COLOR_WINDOW_DARK
					draw_rect(Rect2(wx, wy, 2, 2), wc)
					wx += 6
				wy += 6


## Market lanterns trailing behind on a string at the very top — these
## are the night-market lanterns we just left, slowly receding. Same
## scroll speed as the buildings so they read as "near distance".
func _draw_overhead_lanterns() -> void:
	var spacing: int = 56
	var off: float = fmod(_t * SCROLL_OVERHEAD, float(spacing))
	draw_rect(Rect2(0, ROPE_Y, VIEWPORT_W, 1), Color("#3A1A0A"))
	var i: int = -1
	while i < VIEWPORT_W / spacing + 2:
		var x: float = float(i * spacing) - off
		i += 1
		if x < -10.0 or x > VIEWPORT_W + 10.0:
			continue
		# Tassel string
		draw_rect(Rect2(x, ROPE_Y, 1, 4), Color("#3A1A0A"))
		# Body
		draw_rect(Rect2(x - 3, ROPE_Y + 5, 7, 5), COLOR_LANTERN_BODY)
		# Rims
		draw_rect(Rect2(x - 3, ROPE_Y + 4, 7, 1), COLOR_LANTERN_RIM)
		draw_rect(Rect2(x - 3, ROPE_Y + 10, 7, 1), COLOR_LANTERN_RIM)
		# Tassel below
		draw_rect(Rect2(x, ROPE_Y + 11, 1, 2), Color("#F5EDDA"))


## Lampposts every 80 px — fast scroll. Each post casts a soft glow cone
## on the sidewalk so the street feels actually lit.
func _draw_lampposts() -> void:
	var spacing: int = 80
	var off: float = fmod(_t * SCROLL_LAMP, float(spacing))
	var i: int = -1
	while i < VIEWPORT_W / spacing + 2:
		var x: float = float(i * spacing) - off + 40.0
		i += 1
		if x < -10.0 or x > VIEWPORT_W + 10.0:
			continue
		# Post — vertical line from y=68 down to sidewalk
		draw_rect(Rect2(x, 68, 1, SIDEWALK_TOP - 68), COLOR_LAMPPOST)
		# Lamp head
		draw_rect(Rect2(x - 2, 65, 5, 4), COLOR_LAMPPOST)
		# Lamp glow inside the head
		draw_rect(Rect2(x - 1, 67, 3, 2), COLOR_LAMP_GLOW)
		# Light cone on sidewalk — semi-transparent
		var cone: Color = COLOR_LAMP_GLOW
		cone.a = 0.35
		draw_rect(Rect2(x - 5, SIDEWALK_TOP + 1, 11, 8), cone)


func _draw_street() -> void:
	# Sidewalk
	draw_rect(Rect2(0, SIDEWALK_TOP, VIEWPORT_W, SIDEWALK_BOTTOM - SIDEWALK_TOP),
		COLOR_SIDEWALK)
	# Sidewalk paving lines — short verticals scrolling fast
	var paving_spacing: int = 24
	var paving_off: float = fmod(_t * SCROLL_GROUND, float(paving_spacing))
	var pi: int = -1
	while pi < VIEWPORT_W / paving_spacing + 2:
		var x: float = float(pi * paving_spacing) - paving_off
		pi += 1
		draw_rect(Rect2(x, SIDEWALK_TOP + 2, 1, SIDEWALK_BOTTOM - SIDEWALK_TOP - 4),
			COLOR_SIDEWALK_LINE)
	# Curb
	draw_rect(Rect2(0, SIDEWALK_BOTTOM, VIEWPORT_W, 2), COLOR_CURB)
	# Asphalt
	draw_rect(Rect2(0, ASPHALT_TOP, VIEWPORT_W, VIEWPORT_H - ASPHALT_TOP),
		COLOR_ASPHALT)
	# Center lane line — dashed yellow, scrolls fastest
	var dash_spacing: int = 16
	var off: float = fmod(_t * SCROLL_GROUND, float(dash_spacing))
	var i: int = -1
	while i < VIEWPORT_W / dash_spacing + 2:
		var x: float = float(i * dash_spacing) - off
		i += 1
		draw_rect(Rect2(x, 158, 8, 2), COLOR_LANE_LINE)


## Kid silhouette walks in place at center. 2-frame leg cycle synced to
## the ground-scroll cadence so the legs match the street motion.
func _draw_kid() -> void:
	var x: float = float(KID_X)
	var y: int = KID_GROUND_Y
	var leg_phase: bool = (int(_t * 4.0) % 2) == 0
	var bob: int = -1 if leg_phase else 0
	# Hair
	draw_rect(Rect2(x - 3.0, float(y - 7 + bob), 6.0, 2.0), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3.0, float(y - 5 + bob), 6.0, 4.0), Color("#F2D6A8"))
	# Eyes (looking forward — into the dark, headed home)
	draw_rect(Rect2(x - 1.0, float(y - 3 + bob), 1.0, 1.0), Color("#2A1A0A"))
	draw_rect(Rect2(x + 2.0, float(y - 3 + bob), 1.0, 1.0), Color("#2A1A0A"))
	# Yellow shirt
	draw_rect(Rect2(x - 4.0, float(y - 1 + bob), 8.0, 5.0), Color("#E8F542"))
	# Shirt shadow under collar
	draw_rect(Rect2(x - 4.0, float(y - 1 + bob), 8.0, 1.0),
		Color("#E8F542").darkened(0.25))
	# Blue shorts
	draw_rect(Rect2(x - 3.0, float(y + 4 + bob), 2.0, 3.0), Color("#3A4A8A"))
	draw_rect(Rect2(x + 1.0, float(y + 4 + bob), 2.0, 3.0), Color("#3A4A8A"))
	# Legs alternate — one foot forward, one back, swap on phase
	if leg_phase:
		draw_rect(Rect2(x - 3.0, float(y + 7), 2.0, 2.0), Color("#F2D6A8"))
		draw_rect(Rect2(x + 1.0, float(y + 6), 2.0, 3.0), Color("#F2D6A8"))
	else:
		draw_rect(Rect2(x - 3.0, float(y + 6), 2.0, 3.0), Color("#F2D6A8"))
		draw_rect(Rect2(x + 1.0, float(y + 7), 2.0, 2.0), Color("#F2D6A8"))
	# Shopping bags — one in each hand, swing slightly with the bob
	var bag_y: int = y + 1 + bob
	# Left bag
	draw_rect(Rect2(x - 8.0, float(bag_y), 4.0, 6.0), COLOR_BAG)
	draw_rect(Rect2(x - 8.0, float(bag_y), 4.0, 1.0), COLOR_BAG_RIM)
	draw_rect(Rect2(x - 7.0, float(bag_y - 1), 2.0, 1.0), COLOR_VEGGIE)
	# Right bag
	draw_rect(Rect2(x + 4.0, float(bag_y), 4.0, 6.0), COLOR_BAG)
	draw_rect(Rect2(x + 4.0, float(bag_y), 4.0, 1.0), COLOR_BAG_RIM)
	draw_rect(Rect2(x + 5.0, float(bag_y - 1), 2.0, 1.0), COLOR_VEGGIE)
