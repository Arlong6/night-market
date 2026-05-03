## Title screen for Night Market Shopping.
##
## v0.9 polish: hanging lantern row across the top with per-lantern bob,
## sin-wave bouncing title, blinking start prompt, control hint at bottom.
class_name TitleScreen
extends Control

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const COLOR_TITLE: Color = Color("#F5EDDA")
const COLOR_SUBTITLE: Color = Color("#888888")
const COLOR_QUEST: Color = Color("#F2A227")
const COLOR_HINT: Color = Color("#888888")

# Lantern row constants
const LANTERN_COUNT: int = 9
const LANTERN_Y: int = 22
const LANTERN_SPACING: int = 36
const COLOR_LANTERN_BODY: Color = Color("#C2241A")
const COLOR_LANTERN_RIM: Color = Color("#F2A227")
const COLOR_LANTERN_TASSEL: Color = Color("#F5EDDA")
const COLOR_ROPE: Color = Color("#3A1A0A")

# v0.30: atmospheric layers
const COLOR_STAR: Color = Color("#F5EDDA")
const COLOR_STAR_DIM: Color = Color("#888888")
const COLOR_SILHOUETTE_DARK: Color = Color("#1A0F18")
const COLOR_SILHOUETTE_MID: Color = Color("#2A1A28")
const COLOR_SILHOUETTE_LANTERN: Color = Color("#5A2418")
const COLOR_SILHOUETTE_LANTERN_LIT: Color = Color("#C2241A")
const COLOR_SILHOUETTE_GLOW: Color = Color("#F2A227")

# Silhouette strip (low market band drawn above the hint line)
const SILHOUETTE_TOP_Y: int = 138
const SILHOUETTE_BOTTOM_Y: int = 160

# Walking-kid loop
const KID_Y: int = 154
const KID_SPEED: float = 18.0  # px/sec

# Twinkling-star pattern. Each entry is (x, y, phase_offset, brightness_seed).
const STAR_DATA: Array = [
	[ 12,  6,  0.0, 0],
	[ 30, 10,  0.4, 1],
	[ 56,  4,  0.8, 0],
	[ 88,  8,  1.2, 1],
	[122,  5,  1.6, 0],
	[148, 12,  2.0, 1],
	[176,  3,  2.4, 0],
	[204, 11,  2.8, 1],
	[228,  7,  3.2, 0],
	[256,  4,  3.6, 1],
	[286, 13,  4.0, 0],
	[306,  9,  4.4, 1],
	[ 70, 14,  4.8, 0],
	[200, 16,  5.2, 1],
]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _t: float = 0.0  # accumulator for animations
var _title_label: Label = null
var _start_label: Label = null
var _mute_indicator: Label = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	Game.current_area = "title"
	Music.stop()
	_build_ui()
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# Title bounce: sin-wave Y offset on the title label itself.
	if _title_label != null:
		var bob: float = sin(_t * 2.4) * 1.5
		_title_label.position.y = roundf(bob)
	# Start prompt blink: 0.6s on, 0.6s off via floored modulo.
	if _start_label != null:
		_start_label.visible = (int(_t * 2.0) % 2) == 0
	# Mute indicator follows current mute state (M key may flip it any time).
	if _mute_indicator != null:
		_mute_indicator.visible = HiScore.muted


func _unhandled_input(event: InputEvent) -> void:
	# Any "interact" press starts the game (matches in-game key).
	if event.is_action_pressed("interact"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()
		return
	# v0.24: 'C' opens the cookbook journal — only meaningful once the player
	# has unlocked at least one dish, but always responsive so the hint isn't
	# a lie.
	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo and ke.physical_keycode == KEY_C:
			Game.goto_level("cookbook")
			get_viewport().set_input_as_handled()


func _draw() -> void:
	# v0.30: layered title atmosphere — back to front:
	#   1. starry sky in the gap between lanterns
	#   2. market silhouette strip above the bottom hint
	#   3. animated kid walking across the strip
	#   4. lantern row hanging at the top (existing)
	# Labels are added as children and draw on top automatically.
	_draw_starry_sky()
	_draw_market_silhouette()
	_draw_walking_kid()
	_draw_lantern_row()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	vbox.position = Vector2.ZERO
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Top spacer to clear the lantern row.
	var top_spacer: Control = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(top_spacer)

	_title_label = _make_label("夜市採購大作戰", 16, COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var subtitle: Label = _make_label("Night Market Shopping", 8, COLOR_SUBTITLE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# v0.19: today's day + theme replaces the old static quest line.
	var theme: Dictionary = Inventory.current_theme()
	var quest_text: String = "第 %d 天 · %s · %s" % [
		HiScore.day, theme["label"], theme["name"]
	]
	var quest: Label = _make_label(quest_text, 10, COLOR_QUEST)
	quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(quest)
	var blurb: Label = _make_label(
		String(theme["blurb"]), 8, Color("#C8E66D")
	)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(blurb)

	# v0.23: festival badge — only when today is a festival day.
	var fest_label: String = Inventory.festival_label()
	if not fest_label.is_empty():
		var fest_line: Label = _make_label(
			"%s — +NT$%d" % [fest_label, Inventory.festival_bonus()],
			10, Color("#C2241A")  # festival red
		)
		fest_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(fest_line)

	# v0.31: weekend banner — every Sat / Sun the world feels different.
	# Mum's chattier, the market drops a 紅包, mum's intro is special.
	# Hide on festival days so the festival badge keeps its prominence.
	if Inventory.is_weekend() and fest_label.is_empty():
		var weekend_line: Label = _make_label(
			"★ 週末！紅包等你撿 ★", 10, Color("#F2A227")
		)
		weekend_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(weekend_line)

	# v0.40: 媽媽特別交代 banner — fires on a 7-day cycle (suppressed on
	# festival days so the festival badge keeps priority).
	var sr_label: String = Inventory.special_request_label()
	if not sr_label.is_empty():
		var sr_line: Label = _make_label(
			"%s — %s（+NT$%d）" % [
				sr_label,
				Inventory.special_request_blurb(),
				Inventory.special_request_bonus(),
			],
			9, Color("#C2548A")  # rose pink, distinct from festival red / weekend gold
		)
		sr_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sr_line)

	if HiScore.has_record():
		var best: Label = _make_label(
			"最佳記錄 %s" % HiScore.format_best(), 8, Color("#C8E66D")
		)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(best)

	# v0.12: stats panel — only shows once the player has at least one win.
	if HiScore.has_stats():
		var stats_text: String = "通關 %d 次　滿漢全席 %d 次　不殺價 %d 次" % [
			HiScore.total_wins, HiScore.perfect_runs, HiScore.no_bargain_wins
		]
		var stats: Label = _make_label(stats_text, 8, Color("#888888"))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats)

	# v0.34: dream-sequence stats — only after the player has played a dream.
	# (Either dream_best_kills > 0 or dream_boss_clears > 0 means they did.)
	if HiScore.dream_best_kills > 0 or HiScore.dream_boss_clears > 0:
		var dream_text: String = "夢境最高擊倒 %d 隻　打倒大魔王 %d 次" % [
			HiScore.dream_best_kills, HiScore.dream_boss_clears
		]
		var dream_stats: Label = _make_label(dream_text, 8, Color("#7AC940"))
		dream_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(dream_stats)

	# v0.35: pending dream bonus — appears the morning after a boss clear.
	# Disappears as soon as Inventory.reset() consumes it on START.
	if HiScore.pending_dream_bonus > 0:
		var bonus_line: Label = _make_label(
			"夢境餘韻：明天加菜金 NT$%d" % HiScore.pending_dream_bonus,
			10, Color("#F2A227")
		)
		bonus_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(bonus_line)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Blinking start prompt — replaces the focusable button. Pressing space
	# (or arrows in case of confusion) launches the game via _unhandled_input.
	_start_label = _make_label("按 SPACE 開始", 12, COLOR_TITLE)
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_start_label)

	# Bottom hint pinned at bottom of viewport, NOT in the vbox flow.
	# v0.24: append C 圖鑑 hint once the player has unlocked at least one dish
	# so it doesn't clutter a brand-new player's title screen.
	var hint_text: String = "方向鍵 移動 　空白鍵 互動 　M 靜音"
	if HiScore.unlocked_dish_count() > 0:
		hint_text += " 　C 圖鑑"
	hint_text += " 　 試試 殺價 ！"
	var hint: Label = _make_label(hint_text, 8, COLOR_HINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(VIEWPORT_W, 12)
	hint.position = Vector2(0, VIEWPORT_H - 14)
	add_child(hint)

	# Tiny mute indicator pinned top-right, only when muted.
	_mute_indicator = _make_label("🔇 靜音", 8, Color("#F2A227"))
	_mute_indicator.position = Vector2(VIEWPORT_W - 50, 4)
	_mute_indicator.size = Vector2(46, 12)
	_mute_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mute_indicator.visible = HiScore.muted
	add_child(_mute_indicator)


# ---------------------------------------------------------------------------
# Lantern animation
# ---------------------------------------------------------------------------

## v0.30: scattered stars in the strip between the lantern row and the
## title text. Each star twinkles on its own phase — alternating between
## bright cream and dim grey — so the sky feels alive.
func _draw_starry_sky() -> void:
	for s in STAR_DATA:
		var x: int = int(s[0])
		var y: int = int(s[1])
		var phase: float = float(s[2])
		var seed: int = int(s[3])
		# Twinkle at ~0.6 Hz; offset per-star by phase.
		var lit: bool = sin(_t * 0.8 + phase) > -0.2
		var c: Color = COLOR_STAR if (lit != bool(seed)) else COLOR_STAR_DIM
		draw_rect(Rect2(x, y, 1, 1), c)


## v0.30: low market-stall silhouette band above the hint line — telegraphs
## the market the kid is heading to. A few stalls glow with a tiny lantern
## dot, suggesting they're still open. Sits behind the walking kid.
func _draw_market_silhouette() -> void:
	# Backdrop band — a deeper shadow stripe behind the silhouettes
	draw_rect(Rect2(0, SILHOUETTE_BOTTOM_Y - 4, VIEWPORT_W, 4),
		COLOR_SILHOUETTE_DARK)
	# Stall blocks — varying widths/heights, alternating shades
	var x: int = 0
	var widths: Array = [38, 32, 44, 28, 36, 30, 42, 26, 34, 32]
	var heights: Array = [16, 20, 14, 22, 17, 19, 15, 23, 18, 16]
	var shades: Array = [
		COLOR_SILHOUETTE_DARK, COLOR_SILHOUETTE_MID,
	]
	var i: int = 0
	while x < VIEWPORT_W:
		var w: int = int(widths[i % widths.size()])
		var h: int = int(heights[i % heights.size()])
		var c: Color = shades[i % shades.size()]
		draw_rect(Rect2(x, SILHOUETTE_BOTTOM_Y - h, w, h), c)
		# Awning hint — 1 px lighter top edge
		draw_rect(Rect2(x, SILHOUETTE_BOTTOM_Y - h, w, 1),
			COLOR_SILHOUETTE_LANTERN)
		# Every other stall has a lit lantern dot above the awning
		if i % 2 == 0:
			var lit_x: int = x + w / 2
			var lit_y: int = SILHOUETTE_BOTTOM_Y - h - 4
			# Lantern body
			draw_rect(Rect2(lit_x - 1, lit_y, 2, 3),
				COLOR_SILHOUETTE_LANTERN_LIT)
			# Glow halo (semi-transparent)
			var glow: Color = COLOR_SILHOUETTE_GLOW
			glow.a = 0.35
			draw_rect(Rect2(lit_x - 3, lit_y - 1, 6, 5), glow)
		x += w
		i += 1


## v0.30: animated kid walking left-to-right across the silhouette strip.
## Loops continuously with screen-wrap. 2-frame leg cycle synced to the
## walk speed so steps land on the ground every ~0.25 s.
func _draw_walking_kid() -> void:
	# Wrap kid X across (-12, VIEWPORT_W + 12) so the sprite slides off the
	# right edge cleanly and reappears on the left.
	var pad: float = 12.0
	var span: float = float(VIEWPORT_W) + pad * 2.0
	var raw_x: float = -pad + fmod(_t * KID_SPEED, span)
	var x: int = int(raw_x)
	var y: int = KID_Y
	var leg_phase: bool = (int(_t * 4.0) % 2) == 0
	var bob: int = -1 if leg_phase else 0
	# Hair
	draw_rect(Rect2(x - 3, y - 7 + bob, 6, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3, y - 5 + bob, 6, 4), Color("#F2D6A8"))
	# Eyes — looking right (in the direction of travel)
	draw_rect(Rect2(x - 1, y - 3 + bob, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 2, y - 3 + bob, 1, 1), Color("#2A1A0A"))
	# Yellow shirt
	draw_rect(Rect2(x - 4, y - 1 + bob, 8, 5), Color("#E8F542"))
	draw_rect(Rect2(x - 4, y - 1 + bob, 8, 1),
		Color("#E8F542").darkened(0.25))
	# Blue shorts
	draw_rect(Rect2(x - 3, y + 4 + bob, 2, 3), Color("#3A4A8A"))
	draw_rect(Rect2(x + 1, y + 4 + bob, 2, 3), Color("#3A4A8A"))
	# Legs alternate
	if leg_phase:
		draw_rect(Rect2(x - 3, y + 7, 2, 2), Color("#F2D6A8"))
		draw_rect(Rect2(x + 1, y + 6, 2, 3), Color("#F2D6A8"))
	else:
		draw_rect(Rect2(x - 3, y + 6, 2, 3), Color("#F2D6A8"))
		draw_rect(Rect2(x + 1, y + 7, 2, 2), Color("#F2D6A8"))


## Draws a row of N lanterns hanging from a horizontal rope at the top.
## Each lantern has its own phase so the swaying looks alive, not in sync.
func _draw_lantern_row() -> void:
	# Rope across the screen at LANTERN_Y - 4
	draw_rect(Rect2(0, LANTERN_Y - 5, VIEWPORT_W, 1.0), COLOR_ROPE)
	var start_x: int = (VIEWPORT_W - (LANTERN_COUNT - 1) * LANTERN_SPACING) / 2
	for i in LANTERN_COUNT:
		var phase: float = float(i) * 0.7
		var bob: float = sin(_t * 1.6 + phase) * 1.0
		var x: float = float(start_x + i * LANTERN_SPACING)
		var y: float = float(LANTERN_Y) + bob
		_draw_lantern(x, y)


func _draw_lantern(cx: float, cy: float) -> void:
	# Tassel string from rope down to lantern top
	draw_rect(Rect2(cx - 0.5, cy - 6, 1.0, 4.0), COLOR_ROPE)
	# Top rim
	draw_rect(Rect2(cx - 4, cy - 2, 8, 1), COLOR_LANTERN_RIM)
	# Body
	draw_rect(Rect2(cx - 4, cy - 1, 8, 6), COLOR_LANTERN_BODY)
	# Bottom rim
	draw_rect(Rect2(cx - 4, cy + 5, 8, 1), COLOR_LANTERN_RIM)
	# Tassel hanging below
	draw_rect(Rect2(cx - 0.5, cy + 6, 1.0, 3.0), COLOR_LANTERN_TASSEL)
	# Single-pixel highlight glint on the body
	draw_rect(Rect2(cx - 3, cy, 1, 2), Color("#F2A227"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _on_start_pressed() -> void:
	Inventory.reset()
	Game.reset_run()
	# v0.11: route through the home intro before the market.
	Game.goto_level("home_intro")


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _make_cjk_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_cjk_font() -> FontFile:
	var f: FontFile = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f
