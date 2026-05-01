## 睡前 — Bedroom bookend (v0.29).
##
## A short scene that plays after the end_screen, before returning to the
## title. The kid is in bed in a dark bedroom with the moon visible
## through the window; a thought bubble above their head cycles through
## reflection beats — today's cooked dish, the day count + "晚安" — before
## a fade-out advances to the title.
##
## Reuses DishRenderer (v0.24) so today's plate art shows up unchanged.
##
## Auto-advances to "title" after CYCLE_TOTAL seconds. SPACE skips. In
## test_mode the auto-timer is suppressed and DishRenderer art is skipped
## so headless tests don't depend on font/scene assets.
class_name Bedroom
extends Node2D

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

# ---------------------------------------------------------------------------
# Bubble cycle pacing — total = stage[0] + stage[1] + fade
# ---------------------------------------------------------------------------

const STAGE_DISH: float = 2.4    ## thought bubble shows today's dish
const STAGE_NIGHT: float = 2.4   ## bubble shows day count + 晚安
const FADE_DURATION: float = 0.6 ## hold black before goto_level
const CYCLE_TOTAL: float = STAGE_DISH + STAGE_NIGHT + FADE_DURATION

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_WALL: Color = Color("#1A0F20")
const COLOR_WALL_TRIM: Color = Color("#2A1830")
const COLOR_FLOOR: Color = Color("#2A1828")
const COLOR_FLOOR_LINE: Color = Color("#1A0F18")
const COLOR_WINDOW_FRAME: Color = Color("#3A1A0A")
const COLOR_WINDOW_NIGHT: Color = Color("#1A2A4A")
const COLOR_WINDOW_MOON: Color = Color("#F5EDDA")
const COLOR_WINDOW_STAR: Color = Color("#F5EDDA")
const COLOR_BED_FRAME: Color = Color("#5A3220")
const COLOR_BED_FRAME_DARK: Color = Color("#3A1A0A")
const COLOR_PILLOW: Color = Color("#F5EDDA")
const COLOR_PILLOW_SHADOW: Color = Color("#C8B8A0")
const COLOR_BLANKET: Color = Color("#3A4A8A")  ## blue blanket
const COLOR_BLANKET_HIGHLIGHT: Color = Color("#5A6AAA")
const COLOR_BLANKET_PATTERN: Color = Color("#E8C870") ## yellow squares
const COLOR_LAMP_BODY: Color = Color("#5A3220")
const COLOR_LAMP_SHADE: Color = Color("#F2A227")
const COLOR_LAMP_GLOW: Color = Color("#F2D8A0")
const COLOR_BUBBLE: Color = Color("#F5EDDA")
const COLOR_BUBBLE_BORDER: Color = Color("#3A1A0A")
const COLOR_TEXT_NIGHT: Color = Color("#F5EDDA")
const COLOR_HINT: Color = Color("#5A5060")

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

const FLOOR_Y: int = 130
const WALL_TRIM_Y: int = 30
const WINDOW_X: int = 220
const WINDOW_Y: int = 38
const WINDOW_W: int = 60
const WINDOW_H: int = 50
const BED_X: int = 70
const BED_Y: int = 110
const BED_W: int = 90
const KID_HEAD_X: int = 110
const KID_HEAD_Y: int = 102
const LAMP_X: int = 180
const LAMP_Y: int = 110
const BUBBLE_W: int = 64
const BUBBLE_H: int = 36

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _t: float = 0.0
var _done: bool = false
var _fade_overlay: ColorRect = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "bedroom"
	Game.in_dialogue = false
	# v0.32: lullaby track plays softly under the bookend (-16 dB pentatonic
	# loop, half-tempo of the market track). Stops naturally on goto_level.
	Music.play_lullaby()
	set_process_unhandled_input(true)
	_build_overlays()
	if not Game.test_mode:
		# Schedule the fade-out partway in, then the level swap at total.
		get_tree().create_timer(CYCLE_TOTAL - FADE_DURATION).timeout.connect(
			_start_fade
		)
		get_tree().create_timer(CYCLE_TOTAL).timeout.connect(_advance)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


## Single-shot transition out of the bedroom — guarded so SPACE + the
## auto timer can't both fire and double-load the next scene.
##
## v0.33: weekends route to the 夢境 platformer first; the dream scene
## then routes onward to "title" once the kid wakes up. Other days go
## straight to title as before.
func _advance() -> void:
	if _done:
		return
	_done = true
	var next: String = "dream" if Inventory.is_weekend() else "title"
	Game.goto_level(next)


# ---------------------------------------------------------------------------
# UI overlays
# ---------------------------------------------------------------------------

func _build_overlays() -> void:
	# Skip hint pinned bottom-right
	var hint: Label = Label.new()
	hint.text = "空白鍵 略過"
	hint.add_theme_font_override("font", _make_cjk_font())
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", COLOR_HINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size = Vector2(60, 10)
	hint.position = Vector2(VIEWPORT_W - 64, VIEWPORT_H - 12)
	add_child(hint)

	# Fade overlay (alpha=0 initially, ramps up during _start_fade)
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	_fade_overlay.position = Vector2.ZERO
	add_child(_fade_overlay)


## Tweens the fade overlay to fully opaque over FADE_DURATION. Called by
## the timer so the level swap lands on a black frame, not on a popping cut.
func _start_fade() -> void:
	if _fade_overlay == null:
		return
	var t: Tween = create_tween()
	t.tween_property(_fade_overlay, "color",
		Color(0, 0, 0, 1.0), FADE_DURATION)


# ---------------------------------------------------------------------------
# Drawing — back to front
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_room()
	_draw_window()
	_draw_lamp()
	_draw_bed()
	_draw_kid_head()
	_draw_thought_bubble()


func _draw_room() -> void:
	# Wall fill
	draw_rect(Rect2(0, 0, VIEWPORT_W, FLOOR_Y), COLOR_WALL)
	# Wall trim — a horizontal accent stripe
	draw_rect(Rect2(0, WALL_TRIM_Y, VIEWPORT_W, 1), COLOR_WALL_TRIM)
	# Floor
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, VIEWPORT_H - FLOOR_Y), COLOR_FLOOR)
	# Skirting board / floor line
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1), COLOR_FLOOR_LINE)
	# Floor planks — 3 vertical lines for parquet hint
	for x in [80, 160, 240]:
		draw_rect(Rect2(x, FLOOR_Y + 4, 1, VIEWPORT_H - FLOOR_Y - 6),
			COLOR_FLOOR_LINE)


func _draw_window() -> void:
	# Frame
	draw_rect(Rect2(WINDOW_X - 2, WINDOW_Y - 2, WINDOW_W + 4, WINDOW_H + 4),
		COLOR_WINDOW_FRAME)
	# Night-sky glass
	draw_rect(Rect2(WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H), COLOR_WINDOW_NIGHT)
	# Crossbars
	draw_rect(Rect2(WINDOW_X + WINDOW_W / 2 - 1, WINDOW_Y, 2, WINDOW_H),
		COLOR_WINDOW_FRAME)
	draw_rect(Rect2(WINDOW_X, WINDOW_Y + WINDOW_H / 2 - 1, WINDOW_W, 2),
		COLOR_WINDOW_FRAME)
	# Moon — top-right pane
	draw_rect(Rect2(WINDOW_X + WINDOW_W - 18, WINDOW_Y + 6, 10, 8),
		COLOR_WINDOW_MOON)
	# Moon shadow (crescent hint) — 2-pixel darker bite
	draw_rect(Rect2(WINDOW_X + WINDOW_W - 14, WINDOW_Y + 7, 5, 5),
		COLOR_WINDOW_NIGHT)
	# Stars
	for s in [[6, 4], [22, 8], [10, 18], [38, 30], [16, 36]]:
		draw_rect(Rect2(WINDOW_X + int(s[0]), WINDOW_Y + int(s[1]), 1, 1),
			COLOR_WINDOW_STAR)


func _draw_lamp() -> void:
	# Bedside lamp — squat body + warm glow shade
	# Body (post)
	draw_rect(Rect2(LAMP_X, LAMP_Y, 4, 14), COLOR_LAMP_BODY)
	# Shade (trapezoid approximation: 2 stacked rects)
	draw_rect(Rect2(LAMP_X - 4, LAMP_Y - 8, 12, 5), COLOR_LAMP_SHADE)
	draw_rect(Rect2(LAMP_X - 2, LAMP_Y - 11, 8, 3), COLOR_LAMP_SHADE)
	# Warm glow — 1 px highlight on the shade lip
	draw_rect(Rect2(LAMP_X - 4, LAMP_Y - 4, 12, 1), COLOR_LAMP_GLOW)
	# Base
	draw_rect(Rect2(LAMP_X - 2, LAMP_Y + 14, 8, 2), COLOR_LAMP_BODY)


func _draw_bed() -> void:
	# Frame backing — under the headboard / mattress for depth
	draw_rect(Rect2(BED_X - 2, BED_Y - 2, BED_W + 4, 30), COLOR_BED_FRAME_DARK)
	# Mattress
	draw_rect(Rect2(BED_X, BED_Y, BED_W, 28), COLOR_BED_FRAME)
	# Headboard (left edge, taller)
	draw_rect(Rect2(BED_X - 4, BED_Y - 12, 6, 40), COLOR_BED_FRAME)
	draw_rect(Rect2(BED_X - 4, BED_Y - 12, 6, 1), COLOR_BED_FRAME_DARK)
	# Pillow
	draw_rect(Rect2(BED_X + 6, BED_Y + 2, 26, 12), COLOR_PILLOW)
	draw_rect(Rect2(BED_X + 6, BED_Y + 12, 26, 2), COLOR_PILLOW_SHADOW)
	# Blanket — covers right ~60% of the bed, with patterned trim
	var blanket_x: int = BED_X + 36
	var blanket_w: int = BED_W - 38
	draw_rect(Rect2(blanket_x, BED_Y + 4, blanket_w, 22), COLOR_BLANKET)
	# Blanket highlight stripe
	draw_rect(Rect2(blanket_x, BED_Y + 4, blanket_w, 2), COLOR_BLANKET_HIGHLIGHT)
	# Patterned squares along the trim
	for i in 5:
		var px: int = blanket_x + 4 + i * 10
		draw_rect(Rect2(px, BED_Y + 22, 4, 2), COLOR_BLANKET_PATTERN)
	# Foot of bed darker shadow
	draw_rect(Rect2(BED_X + BED_W - 4, BED_Y + 4, 4, 24), COLOR_BED_FRAME_DARK)


func _draw_kid_head() -> void:
	var x: int = KID_HEAD_X
	var y: int = KID_HEAD_Y
	# Subtle breathing bob — sin wave on a slow period
	var breathe: int = int(sin(_t * 1.4) * 0.5)
	# Hair (back of head, peeking out from under blanket)
	draw_rect(Rect2(x - 3, y - 4 + breathe, 6, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3, y - 2 + breathe, 6, 4), Color("#F2D6A8"))
	# Closed eyes — 2 short horizontal lines (sleeping)
	draw_rect(Rect2(x - 2, y + breathe, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 1, y + breathe, 1, 1), Color("#2A1A0A"))


## Thought bubble cycles between two stages:
##   stage 1 (t < STAGE_DISH):           today's plated dish via DishRenderer
##   stage 2 (STAGE_DISH..total):        day count + 晚安
## Bubble has a wobble bob and 2 trailing dots toward the kid's head.
func _draw_thought_bubble() -> void:
	# Bubble center — to the upper-right of the kid's head
	var cx: int = KID_HEAD_X + 30
	var cy: int = KID_HEAD_Y - 28
	var bob: int = int(sin(_t * 1.8) * 1.0)
	cy += bob
	# Trailing dots from kid's head toward the bubble (3 stepped dots)
	for i in 3:
		var dx: int = KID_HEAD_X + 5 + i * 5
		var dy: int = KID_HEAD_Y - 6 - i * 4
		var r: int = 2 - i  # tapers
		draw_rect(Rect2(dx - r, dy - r, r * 2 + 1, r * 2 + 1),
			COLOR_BUBBLE_BORDER)
		draw_rect(Rect2(dx - r + 1, dy - r + 1, r * 2 - 1, r * 2 - 1),
			COLOR_BUBBLE)
	# Bubble border + body
	draw_rect(Rect2(cx - BUBBLE_W / 2 - 1, cy - BUBBLE_H / 2 - 1,
		BUBBLE_W + 2, BUBBLE_H + 2), COLOR_BUBBLE_BORDER)
	draw_rect(Rect2(cx - BUBBLE_W / 2, cy - BUBBLE_H / 2,
		BUBBLE_W, BUBBLE_H), COLOR_BUBBLE)

	# Stage content
	if _t < STAGE_DISH:
		_draw_bubble_dish(cx, cy)
	else:
		_draw_bubble_night(cx, cy)


## Renders today's headline dish on a small plate inside the bubble.
## Falls back gracefully when the run had no recipe match (messy run).
func _draw_bubble_dish(cx: int, cy: int) -> void:
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	# Plate inside the bubble
	var plate_w: int = 36
	var plate_h: int = 8
	var plate_x: int = cx - plate_w / 2
	var plate_y: int = cy - 4
	draw_rect(Rect2(plate_x, plate_y, plate_w, plate_h),
		Color("#888888"))
	draw_rect(Rect2(plate_x + 1, plate_y + 1, plate_w - 2, plate_h - 2),
		Color("#F5EDDA"))
	if not dishes.is_empty() and not Game.test_mode:
		# Dish art — same renderer as the kitchen plate.
		DishRenderer.draw_dish(self, dishes[0],
			plate_x + 3, plate_y + 1, plate_w - 6, plate_h - 2)
	# "今天" header above the plate
	if _bubble_font != null:
		draw_string(_bubble_font,
			Vector2(cx - BUBBLE_W / 2 + 2, cy - BUBBLE_H / 2 + 9),
			"今天", HORIZONTAL_ALIGNMENT_CENTER, BUBBLE_W - 4, 8,
			COLOR_BUBBLE_BORDER)


## Renders the day count + a "晚安" closer — last beat before the fade.
## v0.31: on weekends, the closer becomes "週末晚安～" so the bookend
## acknowledges the special day instead of feeling identical to weekdays.
func _draw_bubble_night(cx: int, cy: int) -> void:
	if _bubble_font == null:
		return
	# "第 N 天" line
	draw_string(_bubble_font,
		Vector2(cx - BUBBLE_W / 2 + 2, cy - 6),
		"第 %d 天" % maxi(HiScore.day - 1, 1),
		HORIZONTAL_ALIGNMENT_CENTER, BUBBLE_W - 4, 9,
		COLOR_BUBBLE_BORDER)
	# "晚安" closer (with weekend variant)
	var goodnight: String = (
		"週末晚安～" if Inventory.is_weekend() else "晚安～"
	)
	draw_string(_bubble_font,
		Vector2(cx - BUBBLE_W / 2 + 2, cy + 8),
		goodnight, HORIZONTAL_ALIGNMENT_CENTER, BUBBLE_W - 4, 10,
		COLOR_BUBBLE_BORDER)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _bubble_font: FontFile = null


func _make_cjk_font() -> FontFile:
	if _bubble_font != null:
		return _bubble_font
	_bubble_font = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	if _bubble_font != null:
		_bubble_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_bubble_font.subpixel_positioning = (
			TextServer.SUBPIXEL_POSITIONING_DISABLED
		)
	return _bubble_font
