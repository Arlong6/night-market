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


func _draw() -> void:
	# Lanterns drawn on the Control's own canvas behind the labels.
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

	var quest: Label = _make_label("媽媽叫你去夜市買 5 樣食材", 10, COLOR_QUEST)
	quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(quest)

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

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Blinking start prompt — replaces the focusable button. Pressing space
	# (or arrows in case of confusion) launches the game via _unhandled_input.
	_start_label = _make_label("按 SPACE 開始", 12, COLOR_TITLE)
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_start_label)

	# Bottom hint pinned at bottom of viewport, NOT in the vbox flow.
	var hint: Label = _make_label(
		"方向鍵 移動 　空白鍵 互動 　M 靜音 　 試試 殺價 ！", 8, COLOR_HINT
	)
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
