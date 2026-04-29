## Kitchen scene — v0.10 expanded into a bigger space with a stir minigame.
##
## Stages: OPENING → DROP → STIR → PLATE → CLOSING → DONE
## - OPENING: mum's "讓我看看你買到什麼" line
## - DROP: each owned ingredient lands on the prep counter with sparkle + line
## - STIR: player presses SPACE 6 times to "翻炒" — each press rocks the wok,
##   puffs steam, fills a 6-cell meter
## - PLATE: dish renders on the dining table; mum's closing line plays
## - DONE: auto-transition to end_win
##
## All visuals programmatic. Skipping is intentionally limited during STIR
## (6 quick taps clears it) so the cooking beat lands.
class_name Kitchen
extends Node2D

# ---------------------------------------------------------------------------
# Layout — viewport 320×180. Pack a fridge / stove / prep / table all in.
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const FLOOR_Y: int = 130
const WALL_Y: int = 4

# X anchor points
const FRIDGE_X: int = 30
const STOVE_X: int = 100
const PREP_X: int = 160
const TABLE_X: int = 230

# Y anchor points
const STOVE_Y: int = 90
const PREP_Y: int = 100
const TABLE_Y: int = 110

# Character anchors
const MOM_X: int = 100
const MOM_Y: int = 75
const KID_X: int = 195
const KID_Y: int = 110

# Cooking pacing
const OPENING_DELAY: float = 0.6
const INGREDIENT_INTERVAL: float = 0.55
const STIR_TARGET: int = 6
const STIR_PROMPT_DELAY: float = 0.3
const PLATE_HOLD: float = 1.0
const CLOSING_HOLD: float = 1.4
const WOK_ROCK_DURATION: float = 0.18

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_BG: Color = Color("#2A1408")
const COLOR_WALL_TOP: Color = Color("#3A1A0A")
const COLOR_WALL_TILE: Color = Color("#4A2412")
const COLOR_FLOOR: Color = Color("#5A3220")
const COLOR_FLOOR_LINE: Color = Color("#3A1A0A")

# Fridge
const COLOR_FRIDGE_BODY: Color = Color("#A8C8E8")
const COLOR_FRIDGE_HANDLE: Color = Color("#888888")
const COLOR_FRIDGE_INK: Color = Color("#2A1A0A")

# Stove
const COLOR_STOVE_BODY: Color = Color("#5A3220")
const COLOR_BURNER: Color = Color("#2A1A0A")
const COLOR_FLAME_A: Color = Color("#F2A227")
const COLOR_FLAME_B: Color = Color("#C2241A")
const COLOR_WOK: Color = Color("#3A2A1A")
const COLOR_WOK_RIM: Color = Color("#1A1208")

# Prep counter
const COLOR_PREP_BODY: Color = Color("#7A4A2A")
const COLOR_BOARD: Color = Color("#A0784A")
const COLOR_KNIFE: Color = Color("#C8C8C8")

# Dining table
const COLOR_TABLE: Color = Color("#7A4A2A")
const COLOR_TABLE_EDGE: Color = Color("#3A1A0A")
const COLOR_PLATE: Color = Color("#F5EDDA")
const COLOR_PLATE_RIM: Color = Color("#888888")

# Misc
const COLOR_STEAM: Color = Color("#F5EDDA")
const COLOR_METER_FRAME: Color = Color("#F5EDDA")
const COLOR_METER_FILL: Color = Color("#F2A227")
const COLOR_WINDOW_FRAME: Color = Color("#3A1A0A")
const COLOR_WINDOW_NIGHT: Color = Color("#1A2A4A")
const COLOR_WINDOW_MOON: Color = Color("#F5EDDA")
const COLOR_UTENSIL: Color = Color("#888888")

# Stall food icon colours mirrored from StallNPC for dish composition.
const FOOD_COLOR: Dictionary = {
	"scallion":  Color("#7AC940"),
	"egg":       Color("#FFE9B0"),
	"cabbage":   Color("#9EE070"),
	"chicken":   Color("#C58A4A"),
	"soy_sauce": Color("#3A1A0A"),
	"tofu":      Color("#F8F0D8"),
	"mushroom":  Color("#7A4A2A"),
}

const FLAVOR_LINE: Dictionary = {
	"scallion":  "蔥！很新鮮～",
	"egg":       "雞蛋！打個蛋花。",
	"cabbage":   "高麗菜，脆脆的。",
	"chicken":   "雞肉！下鍋囉～",
	"soy_sauce": "醬油！畫龍點睛。",
	"tofu":      "豆腐！嫩嫩的。",
	"mushroom":  "香菇！增添香氣。",
}

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

enum Stage { OPENING, DROP, STIR_PROMPT, STIR, PLATE, CLOSING, DONE,
			 INTRO_OPENING, INTRO_KID_WALK, INTRO_DONE }
var _stage: Stage = Stage.OPENING

## v0.11: when true, scene runs the "home before market" intro instead of
## the post-shopping cook sequence. Set by the home_intro.tscn wrapper.
@export var is_intro: bool = false

# Drop
var _placed_ingredients: Array[Dictionary] = []  ## { id, x, y } each

# Stir
var _stir_count: int = 0
var _wok_rock_t: float = 0.0  ## decreases each frame; while > 0 wok visibly rocks

# Intro
var _kid_x_offset: float = 0.0  ## tween offset for kid walking out the right side

# Animation accumulators
var _flame_t: float = 0.0
var _steam_t: float = 0.0
var _kid_t: float = 0.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "home_intro" if is_intro else "kitchen"
	set_process_unhandled_input(true)
	if is_intro:
		_run_intro_sequence()
	else:
		_run_sequence()


func _process(delta: float) -> void:
	_flame_t += delta
	_steam_t += delta
	_kid_t += delta
	if _wok_rock_t > 0.0:
		_wok_rock_t = maxf(_wok_rock_t - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# During STIR, SPACE/Z/Enter advance the cook meter. Outside STIR, any
	# "interact" press skips ahead to the next stage's end.
	if not (event is InputEvent and event.is_pressed()):
		return
	if _stage == Stage.STIR and event.is_action_pressed("interact"):
		_do_stir()
		get_viewport().set_input_as_handled()
		return
	# Intro: any interact press fast-forwards through to the market.
	if is_intro and event.is_action_pressed("interact") and _stage != Stage.INTRO_DONE:
		_skip_intro()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Sequence
# ---------------------------------------------------------------------------

func _run_sequence() -> void:
	_stage = Stage.OPENING
	# v0.14: incomplete runs get a resigned opening line; full/perfect runs
	# get the cheery "let's see what you got" line.
	var opening_line: String = (
		"嗯…就這幾樣啊？湊合著煮吧～"
		if Game.last_run_incomplete
		else "終於回來了！讓我看看你買到什麼好東西…"
	)
	Dialogue.show([opening_line])
	await get_tree().create_timer(OPENING_DELAY).timeout

	_stage = Stage.DROP
	var owned: PackedStringArray = Inventory.owned_ingredients()
	for i in owned.size():
		_drop_ingredient(owned[i], i)
		await get_tree().create_timer(INGREDIENT_INTERVAL).timeout

	_stage = Stage.STIR_PROMPT
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show(["全部下鍋！按 SPACE 翻炒～"])
	await get_tree().create_timer(STIR_PROMPT_DELAY).timeout
	_stage = Stage.STIR
	# Wait until _stir_count reaches STIR_TARGET — driven by player input.
	while _stir_count < STIR_TARGET:
		await get_tree().process_frame

	_stage = Stage.PLATE
	# v0.24: cookbook journal — every dish that landed on the plate this run
	# permanently unlocks (and increments) in HiScore. Done at PLATE start so
	# the entry exists before the closing line / end_win.
	for d in Inventory.cooked_dishes():
		HiScore.record_cooked_dish(d)
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show(["完成！上桌囉～"])
	await get_tree().create_timer(PLATE_HOLD).timeout

	_stage = Stage.CLOSING
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show([_closing_line_for_time(Game.session_time)])
	await get_tree().create_timer(CLOSING_HOLD).timeout

	_stage = Stage.DONE
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Game.goto_level("end_win")


func _drop_ingredient(id: String, idx: int) -> void:
	# Land on the prep counter top in 2 staggered rows.
	var col: int = idx % 4
	var row: int = idx / 4
	var slot_x: float = float(PREP_X) - 14.0 + float(col) * 10.0
	var slot_y: float = float(PREP_Y) - 6.0 + float(row) * 6.0
	_placed_ingredients.append({"id": id, "x": slot_x, "y": slot_y})
	# Sparkle pop on landing
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2(slot_x, slot_y)
	burst.count = 4
	burst.color = Color("#F2A227")
	burst.speed_min = 28.0
	burst.speed_max = 55.0
	burst.particle_size = 1.5
	burst.lifetime = 0.32
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.7
	add_child(burst)
	Sfx.play_pickup()
	var flavor: String = FLAVOR_LINE.get(id, Inventory.display_name(id))
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show([flavor])


func _do_stir() -> void:
	if _stir_count >= STIR_TARGET:
		return
	_stir_count += 1
	_wok_rock_t = WOK_ROCK_DURATION
	Sfx.play_choice()
	# Steam puff out the wok on each stir.
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2(STOVE_X, STOVE_Y - 12)
	burst.count = 5
	burst.color = COLOR_STEAM
	burst.speed_min = 25.0
	burst.speed_max = 65.0
	burst.particle_size = 2.0
	burst.lifetime = 0.5
	burst.gravity_scale = 0.0
	burst.upward_bias = 0.95
	add_child(burst)


# ---------------------------------------------------------------------------
# Intro sequence (v0.11) — runs when is_intro=true, before the market.
# ---------------------------------------------------------------------------

func _run_intro_sequence() -> void:
	_stage = Stage.INTRO_OPENING
	Dialogue.show(["寶貝！幫媽媽去夜市買菜～"])
	await get_tree().create_timer(1.4).timeout
	if _stage == Stage.INTRO_DONE:
		return
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	# v0.23: festival days override the day theme line with a special blurb.
	var fest_blurb: String = Inventory.festival_blurb()
	var theme_line: String
	if not fest_blurb.is_empty():
		theme_line = "%s — %s" % [
			Inventory.festival_label(), fest_blurb
		]
	else:
		# v0.19: announce today's theme before the shopping list.
		var theme: Dictionary = Inventory.current_theme()
		theme_line = "第 %d 天 · %s · %s — %s" % [
			HiScore.day, theme["label"], theme["name"], theme["blurb"]
		]
	Dialogue.show([theme_line])
	await get_tree().create_timer(2.0).timeout
	if _stage == Stage.INTRO_DONE:
		return
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	# v0.13: list mum's actual random shopping list for this run.
	Dialogue.show(["今天要：%s ～" % _format_required_list()])
	await get_tree().create_timer(2.0).timeout
	if _stage == Stage.INTRO_DONE:
		return
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show(["給你 NT$%d… 記得試試 殺價！" % Inventory.STARTING_MONEY])
	await get_tree().create_timer(1.6).timeout
	if _stage == Stage.INTRO_DONE:
		return

	# Kid walks out toward the right edge.
	_stage = Stage.INTRO_KID_WALK
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	var tween: Tween = create_tween()
	tween.tween_property(self, "_kid_x_offset", 130.0, 1.4)
	await tween.finished

	if _stage != Stage.INTRO_DONE:
		_stage = Stage.INTRO_DONE
		Game.goto_level("shilin")


## Joins required-ingredient display names with 、 for mum's intro line.
## Falls back to a generic "5 樣食材" if the list is somehow empty.
func _format_required_list() -> String:
	var names: PackedStringArray = PackedStringArray()
	for id in Inventory.required_ingredients:
		names.append(Inventory.display_name(id))
	if names.is_empty():
		return "5 樣食材"
	return "、".join(names)


## Fast-forwards intro: closes any line + jumps the kid offscreen + transition.
func _skip_intro() -> void:
	if _stage == Stage.INTRO_DONE:
		return
	_stage = Stage.INTRO_DONE
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Game.goto_level("shilin")


# ---------------------------------------------------------------------------
# Outro helpers
# ---------------------------------------------------------------------------

func _closing_line_for_time(t: float) -> String:
	# v0.14: incomplete runs override everything — kid came home short, so
	# mum's closer reflects "made do" rather than praise.
	if Game.last_run_incomplete:
		return "勉強OK啦…下次認真點～"
	# v0.12: perfect runs override the time-tier line with the 滿漢全席 closer.
	if Game.last_run_perfect:
		return "滿漢全席！吃飽飽～"
	if t < 90.0:
		return "好快！馬上開動～"
	elif t < 240.0:
		return "好菜上桌囉～"
	return "等你好久了～開飯！"


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Backdrop wall fills first, then floor, then furniture stacked over it.
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_WALL_TOP)
	# Wall tile band — a few horizontal accent stripes for texture
	for y in [40, 60, 80]:
		draw_rect(Rect2(0, y, VIEWPORT_W, 1.0), COLOR_WALL_TILE)
	# Floor stripe
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, VIEWPORT_H - FLOOR_Y), COLOR_FLOOR)
	# Skirting board
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1.0), COLOR_FLOOR_LINE)

	_draw_window()
	_draw_hanging_utensils()
	_draw_fridge()
	_draw_stove()
	_draw_prep_counter()
	_draw_table()
	if is_intro:
		_draw_exit_door()
	_draw_mom()
	_draw_kid()
	if _stage == Stage.STIR:
		_draw_stir_meter()


## Draw a door on the right wall during intro — the kid's destination.
func _draw_exit_door() -> void:
	var dx: int = VIEWPORT_W - 28
	var dy: int = 75
	# Frame
	draw_rect(Rect2(dx - 1, dy - 1, 22, 56), COLOR_FRIDGE_INK)
	# Door panel
	draw_rect(Rect2(dx, dy, 20, 54), Color("#7A4A2A"))
	# Cross-panel relief
	draw_rect(Rect2(dx, dy + 26, 20, 1.0), COLOR_FRIDGE_INK)
	# Knob
	draw_rect(Rect2(dx + 2, dy + 28, 2, 2), Color("#F2A227"))
	# Sky strip beyond the door (only visible during the walk)
	if _stage == Stage.INTRO_KID_WALK:
		draw_rect(Rect2(dx, dy, 20, 54), Color("#1A2A4A"))
		# Tiny moon glimpse
		draw_rect(Rect2(dx + 12, dy + 8, 4, 3), Color("#F5EDDA"))


func _draw_window() -> void:
	# Window above the prep counter — small night-sky framed pane
	var wx: int = PREP_X - 16
	var wy: int = 26
	draw_rect(Rect2(wx - 2, wy - 2, 36, 28), COLOR_WINDOW_FRAME)
	draw_rect(Rect2(wx, wy, 32, 24), COLOR_WINDOW_NIGHT)
	# Crossbars
	draw_rect(Rect2(wx + 15, wy, 2, 24), COLOR_WINDOW_FRAME)
	draw_rect(Rect2(wx, wy + 11, 32, 2), COLOR_WINDOW_FRAME)
	# Moon (top-right pane)
	draw_rect(Rect2(wx + 22, wy + 3, 6, 5), COLOR_WINDOW_MOON)
	# Stars (pixel dots)
	draw_rect(Rect2(wx + 4, wy + 4, 1, 1), COLOR_WINDOW_MOON)
	draw_rect(Rect2(wx + 11, wy + 7, 1, 1), COLOR_WINDOW_MOON)
	draw_rect(Rect2(wx + 25, wy + 17, 1, 1), COLOR_WINDOW_MOON)


func _draw_hanging_utensils() -> void:
	# Above the stove — 3 utensils hanging from a ledge
	var lx: int = STOVE_X - 18
	var ly: int = 50
	draw_rect(Rect2(lx, ly, 36, 1.0), COLOR_FRIDGE_INK)
	for i in 3:
		var x: float = float(lx + 6 + i * 12)
		# Hook line
		draw_rect(Rect2(x, ly, 1.0, 4.0), COLOR_FRIDGE_INK)
		# Utensil head varies per slot — pan / spatula / ladle
		match i:
			0:
				# Pan circle (rect approximation)
				draw_rect(Rect2(x - 3, ly + 4, 7, 5), COLOR_UTENSIL)
				draw_rect(Rect2(x + 3, ly + 5, 4, 1), COLOR_UTENSIL)
			1:
				# Spatula
				draw_rect(Rect2(x - 1, ly + 4, 2, 6), COLOR_UTENSIL)
				draw_rect(Rect2(x - 2, ly + 9, 4, 2), COLOR_UTENSIL)
			2:
				# Ladle
				draw_rect(Rect2(x - 1, ly + 4, 2, 5), COLOR_UTENSIL)
				draw_rect(Rect2(x - 3, ly + 8, 5, 3), COLOR_UTENSIL)


func _draw_fridge() -> void:
	# Tall fridge on the far left
	draw_rect(Rect2(FRIDGE_X - 12, 60, 24, 70), COLOR_FRIDGE_INK)
	draw_rect(Rect2(FRIDGE_X - 11, 61, 22, 68), COLOR_FRIDGE_BODY)
	# Door split horizontal line
	draw_rect(Rect2(FRIDGE_X - 11, 88, 22, 1.0), COLOR_FRIDGE_INK)
	# Handles
	draw_rect(Rect2(FRIDGE_X + 7, 70, 2, 12), COLOR_FRIDGE_HANDLE)
	draw_rect(Rect2(FRIDGE_X + 7, 96, 2, 16), COLOR_FRIDGE_HANDLE)
	# Magnet decoration: a small note on the upper door
	draw_rect(Rect2(FRIDGE_X - 6, 70, 6, 4), Color("#F2A227"))
	draw_rect(Rect2(FRIDGE_X - 5, 71, 4, 2), COLOR_FRIDGE_INK)


func _draw_stove() -> void:
	# Stove body
	draw_rect(Rect2(STOVE_X - 18, STOVE_Y - 4, 36, 38), COLOR_STOVE_BODY)
	# Burner ring
	draw_rect(Rect2(STOVE_X - 12, STOVE_Y, 24, 4), COLOR_BURNER)
	# Wok rocks left/right when _wok_rock_t > 0; rock fades over its duration
	var rock_x: float = 0.0
	if _wok_rock_t > 0.0:
		var phase: float = (1.0 - _wok_rock_t / WOK_ROCK_DURATION) * TAU
		rock_x = sin(phase * 2.0) * 2.0
	# Wok body (wider than the old pot, with curved rim approximation)
	draw_rect(Rect2(STOVE_X - 14 + rock_x, STOVE_Y - 12, 28, 12), COLOR_WOK)
	# Wok rim — 1px darker top and bottom edges
	draw_rect(Rect2(STOVE_X - 14 + rock_x, STOVE_Y - 13, 28, 1.0), COLOR_WOK_RIM)
	# Wok handle (right side)
	draw_rect(Rect2(STOVE_X + 14 + rock_x, STOVE_Y - 8, 6, 2), COLOR_WOK_RIM)
	# Animated flame slits both sides of the burner — alternating colors
	var flame_phase: float = sin((_flame_t / 0.12) * TAU)
	var flame_h: float = 2.0 + (1.0 if flame_phase > 0.0 else 0.0)
	var flame_color: Color = COLOR_FLAME_A if flame_phase > 0.0 else COLOR_FLAME_B
	draw_rect(Rect2(STOVE_X - 11, STOVE_Y, 4, flame_h), flame_color)
	draw_rect(Rect2(STOVE_X + 7, STOVE_Y, 4, flame_h), flame_color)
	# Steam puffs cycling up while cooking
	if _stage == Stage.STIR or _stage == Stage.PLATE or _stage == Stage.CLOSING:
		var s_y0: float = float(STOVE_Y) - 18.0 - fmod(_steam_t * 16.0, 22.0)
		var s_y1: float = float(STOVE_Y) - 18.0 - fmod(_steam_t * 16.0 + 11.0, 22.0)
		var a0: float = clampf(1.0 - fmod(_steam_t * 16.0, 22.0) / 22.0, 0.0, 1.0)
		var a1: float = clampf(1.0 - fmod(_steam_t * 16.0 + 11.0, 22.0) / 22.0, 0.0, 1.0)
		var c0: Color = COLOR_STEAM
		var c1: Color = COLOR_STEAM
		c0.a = a0
		c1.a = a1
		draw_rect(Rect2(STOVE_X - 2, s_y0, 2, 2), c0)
		draw_rect(Rect2(STOVE_X + 2, s_y1, 2, 2), c1)


func _draw_prep_counter() -> void:
	# Counter under the window (where ingredients drop)
	draw_rect(Rect2(PREP_X - 22, PREP_Y - 4, 44, 30), COLOR_PREP_BODY)
	draw_rect(Rect2(PREP_X - 22, PREP_Y - 5, 44, 1.0), COLOR_TABLE_EDGE)
	# Cutting board on top
	draw_rect(Rect2(PREP_X - 10, PREP_Y - 4, 20, 4), COLOR_BOARD)
	# Knife resting on board (left side)
	draw_rect(Rect2(PREP_X - 9, PREP_Y - 3, 1.0, 2.0), COLOR_KNIFE)
	draw_rect(Rect2(PREP_X - 9, PREP_Y - 3, 6, 1.0), COLOR_KNIFE)

	# Ingredient chips placed during DROP stage
	for ing in _placed_ingredients:
		var c: Color = FOOD_COLOR.get(ing["id"], Color.WHITE)
		var x: float = ing["x"] - 2.0
		var y: float = ing["y"] - 2.0
		draw_rect(Rect2(x, y, 4, 4), c)
		draw_rect(Rect2(x, y, 4, 1.0), COLOR_TABLE_EDGE)
		draw_rect(Rect2(x, y + 3, 4, 1.0), COLOR_TABLE_EDGE)


func _draw_table() -> void:
	# Dining table — wider than v0.8 since we have horizontal real estate
	draw_rect(Rect2(TABLE_X - 36, TABLE_Y - 8, 72, 16), COLOR_TABLE)
	draw_rect(Rect2(TABLE_X - 36, TABLE_Y - 8, 72, 1.0), COLOR_TABLE_EDGE)
	draw_rect(Rect2(TABLE_X - 36, TABLE_Y + 7, 72, 1.0), COLOR_TABLE_EDGE)
	# Legs
	draw_rect(Rect2(TABLE_X - 34, TABLE_Y + 8, 2, 14), COLOR_TABLE)
	draw_rect(Rect2(TABLE_X + 32, TABLE_Y + 8, 2, 14), COLOR_TABLE)

	# Plated dish — only shown during PLATE / CLOSING
	if _stage == Stage.PLATE or _stage == Stage.CLOSING or _stage == Stage.DONE:
		_draw_dish_on_plate()


func _draw_dish_on_plate() -> void:
	# Plate — perfect runs get a wider gold-rimmed plate to telegraph the
	# 滿漢全席 ending. Standard plate stays cream/grey.
	var px: int = TABLE_X
	var py: int = TABLE_Y - 4
	var perfect: bool = Game.last_run_perfect
	# v0.18: plate size bumped slightly so each dish has more drawing room.
	# Standard 28×10 → 32×11; perfect 36×12 → 40×13. The 1px shadow is also
	# new — gives the plate a hint of weight on the table.
	if perfect:
		# Plate shadow under the rim
		draw_rect(Rect2(px - 20, py + 7, 40, 1), Color("#1A0E04"))
		# Gold rim
		draw_rect(Rect2(px - 20, py - 6, 40, 13), Color("#F2A227"))
		# Inner gold ring (tonal depth on the rim)
		draw_rect(Rect2(px - 19, py - 5, 38, 11), Color("#C8801F"))
		# Cream surface
		draw_rect(Rect2(px - 18, py - 4, 36, 9), COLOR_PLATE)
	else:
		draw_rect(Rect2(px - 16, py + 6, 32, 1), Color("#1A0E04"))
		draw_rect(Rect2(px - 16, py - 5, 32, 11), COLOR_PLATE_RIM)
		draw_rect(Rect2(px - 15, py - 4, 30, 9), COLOR_PLATE)

	# v0.16: render the night's headline dish on the plate. Standard plate
	# inset 1px from cream rim; perfect plate gets the bigger area. When no
	# recipe matches (very messy run), fall back to the v0.14 chip cluster.
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	if dishes.is_empty():
		_draw_messy_chips(px, py, perfect)
	else:
		var dx: int = (px - 17) if perfect else (px - 14)
		var dy: int = (py - 3) if perfect else (py - 3)
		var dw: int = 34 if perfect else 28
		var dh: int = 8 if perfect else 7
		DishRenderer.draw_dish(self, dishes[0], dx, dy, dw, dh)
		# v0.18: steam wisps above the plate while the dish is hot.
		_draw_dish_steam(px, dy)

	# Perfect runs get a single ★ pixel sitting above the plate
	if perfect:
		draw_rect(Rect2(px - 1, py - 10, 2, 2), Color("#F2A227"))


# ---------------------------------------------------------------------------
# v0.18 / v0.24 — per-recipe dish rendering.
# All palette + drawer code moved into DishRenderer (see dish_renderer.gd) so
# the cookbook journal can render the same dishes at the same shading. Only
# the steam wisps remain here (they depend on the kitchen's _steam_t).
# ---------------------------------------------------------------------------

## v0.18: steam wisps rising above the plate during PLATE/CLOSING/DONE.
## 3 wisps cycle on offset phases so they look continuous rather than
## stuttering on a single frame.
func _draw_dish_steam(plate_cx: int, plate_top_y: int) -> void:
	for i in 3:
		var phase: float = fmod((_steam_t * 0.7) + (float(i) / 3.0), 1.0)
		var wx: int = plate_cx - 8 + i * 8
		var wy: float = float(plate_top_y) - 2.0 - phase * 14.0
		var c: Color = COLOR_STEAM
		c.a = clampf(1.0 - phase, 0.0, 1.0) * 0.8
		# Wisp shape: 1 pixel + a 1-pixel sway based on phase
		var sway: int = int(sin(phase * TAU + float(i)) * 1.5)
		draw_rect(Rect2(wx + sway, wy, 1, 1), c)
		# Trailing pixel below for slight thickness
		var c2: Color = COLOR_STEAM
		c2.a = clampf(1.0 - phase, 0.0, 1.0) * 0.4
		draw_rect(Rect2(wx + sway, wy + 1, 1, 1), c2)


## v0.14 fallback — when no recipe matches, draw the old ingredient-chip
## cluster, jittered if incomplete to telegraph "made do".
func _draw_messy_chips(px: int, py: int, perfect: bool) -> void:
	var owned: PackedStringArray = Inventory.owned_ingredients()
	var per_row: int = 4 if perfect else 3
	var max_chips: int = 7 if perfect else 6
	var incomplete: bool = Game.last_run_incomplete
	for i in mini(owned.size(), max_chips):
		var col: int = i % per_row
		var row: int = i / per_row
		var dx_off: float = -float(per_row - 1) * 2.5
		var dx: float = float(px) + dx_off + float(col) * 5.0
		var dy: float = float(py) - 2.0 + float(row) * 4.0
		if incomplete:
			dx += cos(float(i) * 7.3) * 1.5
			dy += sin(float(i) * 11.7) * 1.5
		var c: Color = FOOD_COLOR.get(owned[i], Color.WHITE)
		draw_rect(Rect2(dx, dy, 3, 3), c)


func _draw_stir_meter() -> void:
	# 6-cell meter floating above the wok
	var bar_x: int = STOVE_X - 16
	var bar_y: int = STOVE_Y - 30
	draw_rect(Rect2(bar_x - 1, bar_y - 1, 34, 8), COLOR_METER_FRAME)
	draw_rect(Rect2(bar_x, bar_y, 32, 6), COLOR_BG)
	for i in STIR_TARGET:
		var cx: float = float(bar_x) + 1.0 + float(i) * 5.0
		var filled: bool = i < _stir_count
		if filled:
			draw_rect(Rect2(cx, bar_y + 1, 4, 4), COLOR_METER_FILL)
		else:
			draw_rect(Rect2(cx, bar_y + 1, 4, 4), COLOR_METER_FRAME.darkened(0.6))


func _draw_mom() -> void:
	# Stationary, manning the wok — slight bob in time with stir
	var x: int = MOM_X
	var y: int = MOM_Y
	var rock: float = 0.0
	if _wok_rock_t > 0.0:
		# Mum tilts in opposite direction to wok, like she's stirring
		var phase: float = (1.0 - _wok_rock_t / WOK_ROCK_DURATION) * TAU
		rock = -sin(phase * 2.0) * 1.0
	# Hair top + bun
	draw_rect(Rect2(x - 3 + rock, y - 7, 6, 2), Color("#3A1A0A"))
	draw_rect(Rect2(x - 2 + rock, y - 8, 4, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3 + rock, y - 5, 6, 4), Color("#F2D6A8"))
	# Eyes
	draw_rect(Rect2(x - 2 + rock, y - 3, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 1 + rock, y - 3, 1, 1), Color("#2A1A0A"))
	# Body (purple)
	draw_rect(Rect2(x - 4 + rock, y - 1, 8, 5), Color("#9A4A8A"))
	# Apron
	draw_rect(Rect2(x - 3 + rock, y + 1, 6, 3), Color("#F5EDDA"))
	# Legs
	draw_rect(Rect2(x - 3 + rock, y + 4, 2, 4), Color("#5A2A4A"))
	draw_rect(Rect2(x + 1 + rock, y + 4, 2, 4), Color("#5A2A4A"))
	# Arm extending toward the wok handle (right side of stove). Only visible
	# in stir-y stages so the silhouette is recognisable as "cooking".
	if _stage == Stage.STIR or _stage == Stage.PLATE:
		draw_rect(Rect2(x + 4 + rock, y - 1, 4, 2), Color("#F2D6A8"))


func _draw_kid() -> void:
	var bob: float = sin((_kid_t / 0.55) * TAU)
	var bob_y: float = -1.0 if bob > 0.0 else 0.0
	var x: float = float(KID_X) + _kid_x_offset
	var y: int = KID_Y
	# Hair
	draw_rect(Rect2(x - 3, y - 7 + bob_y, 6, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3, y - 5 + bob_y, 6, 4), Color("#F2D6A8"))
	# Eyes (looking left toward stove during cooking, forward at end)
	var eye_shift: float = -1.0 if _stage <= Stage.STIR else 0.0
	draw_rect(Rect2(x - 2 + eye_shift, y - 3 + bob_y, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 1 + eye_shift, y - 3 + bob_y, 1, 1), Color("#2A1A0A"))
	# Yellow shirt
	draw_rect(Rect2(x - 4, y - 1 + bob_y, 8, 5), Color("#E8F542"))
	draw_rect(Rect2(x - 4, y - 1 + bob_y, 8, 1.0), Color("#E8F542").darkened(0.25))
	# Blue shorts
	draw_rect(Rect2(x - 3, y + 4 + bob_y, 2, 3), Color("#3A4A8A"))
	draw_rect(Rect2(x + 1, y + 4 + bob_y, 2, 3), Color("#3A4A8A"))
