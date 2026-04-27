## Kitchen cutscene for Night Market Shopping (v0.8).
##
## Bridges the win bump and the stat dump on end_win. Shows mum at the stove
## while the ingredients you actually bought drop onto the table one by one,
## each with a sparkle + the ingredient's name called out. After all are
## placed, mum says one closing line and the scene auto-transitions to
## end_win. Pressing any key skips ahead.
##
## All visuals are programmatic ColorRect / _draw shapes consistent with the
## rest of the game — no bitmap assets.
class_name Kitchen
extends Node2D

# ---------------------------------------------------------------------------
# Layout constants — viewport is 320×180
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const FLOOR_Y: int = 130            ## y-coord where the floor stripe sits
const STOVE_X: int = 90             ## stove anchor centre
const STOVE_Y: int = 90
const TABLE_X: int = 220            ## table anchor centre
const TABLE_Y: int = 100
const MOM_X: int = 90
const MOM_Y: int = 75
const KID_X: int = 175
const KID_Y: int = 110

## How long between each ingredient's drop on the table.
const INGREDIENT_INTERVAL: float = 0.7

## Delay before the first drop (lets the opening line settle).
const OPENING_DELAY: float = 0.6

## How long mum's closing line stays before auto-advancing to end_win.
const CLOSING_HOLD: float = 1.4

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_BG: Color = Color("#2A1408")
const COLOR_FLOOR: Color = Color("#4A2412")
const COLOR_WALL: Color = Color("#3A1A0A")
const COLOR_STOVE_BODY: Color = Color("#5A3220")
const COLOR_BURNER: Color = Color("#2A1A0A")
const COLOR_FLAME: Color = Color("#F2A227")
const COLOR_POT: Color = Color("#888888")
const COLOR_POT_RIM: Color = Color("#444444")
const COLOR_TABLE: Color = Color("#7A4A2A")
const COLOR_TABLE_EDGE: Color = Color("#3A1A0A")
const COLOR_STEAM: Color = Color("#F5EDDA")

# Stall food icon colours (mirrored from StallNPC) — keyed by ingredient_id.
const FOOD_COLOR: Dictionary = {
	"scallion":  Color("#7AC940"),
	"egg":       Color("#FFE9B0"),
	"cabbage":   Color("#9EE070"),
	"chicken":   Color("#C58A4A"),
	"soy_sauce": Color("#3A1A0A"),
	"tofu":      Color("#F8F0D8"),
	"mushroom":  Color("#7A4A2A"),
}

# Per-ingredient flavour line shown when it lands on the table.
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
# State
# ---------------------------------------------------------------------------

var _placed_ingredients: Array[Dictionary] = []  ## { id, x, y } per dropped chip
var _flame_t: float = 0.0
var _steam_t: float = 0.0
var _kid_t: float = 0.0  # for kid bob
var _done: bool = false
var _skipped: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "kitchen"
	# Music keeps playing from the market — let the win arpeggio that already
	# fired from MomNPC.on_bumped() carry into here. Stop only at end_win.
	set_process_unhandled_input(true)
	_run_sequence()


func _process(delta: float) -> void:
	_flame_t += delta
	_steam_t += delta
	_kid_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEvent and event.is_pressed()):
		return
	# Any input skips the cutscene straight to end_win.
	if not _skipped:
		_skipped = true
		_skip_to_end()


# ---------------------------------------------------------------------------
# Sequence
# ---------------------------------------------------------------------------

func _run_sequence() -> void:
	# Opening line
	Dialogue.show(["終於回來了！讓我看看你買到什麼好東西…"])
	await get_tree().create_timer(OPENING_DELAY).timeout
	if _skipped:
		return

	# Drop each owned ingredient onto the table, one at a time.
	var owned: PackedStringArray = Inventory.owned_ingredients()
	for i in owned.size():
		if _skipped:
			return
		_drop_ingredient(owned[i], i)
		await get_tree().create_timer(INGREDIENT_INTERVAL).timeout

	if _skipped:
		return

	# Closing line based on time tier — same buckets as MomNPC.
	var line: String = _closing_line_for_time(Game.session_time)
	Dialogue.show([line])
	await get_tree().create_timer(CLOSING_HOLD).timeout

	if not _skipped:
		_done = true
		Game.goto_level("end_win")


func _drop_ingredient(id: String, idx: int) -> void:
	# 7 ingredient slots arranged in a 2-row grid on the table top.
	var col: int = idx % 4
	var row: int = idx / 4
	var slot_x: float = float(TABLE_X) - 18.0 + float(col) * 12.0
	var slot_y: float = float(TABLE_Y) - 6.0 + float(row) * 8.0
	_placed_ingredients.append({
		"id": id, "x": slot_x, "y": slot_y,
	})
	# Sparkle pop on landing.
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2(slot_x, slot_y)
	burst.count = 5
	burst.color = Color("#F2A227")
	burst.speed_min = 30.0
	burst.speed_max = 60.0
	burst.particle_size = 1.5
	burst.lifetime = 0.35
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.7
	add_child(burst)
	Sfx.play_pickup()
	# Show the flavour line for this ingredient (interrupts opening line).
	var flavor: String = FLAVOR_LINE.get(id, Inventory.display_name(id))
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue.show([flavor])


func _closing_line_for_time(t: float) -> String:
	if t < 90.0:
		return "好快！馬上開動～"
	elif t < 240.0:
		return "好菜上桌囉～"
	return "等你好久了～開飯！"


func _skip_to_end() -> void:
	if _done:
		return
	_done = true
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Game.goto_level("end_win")


# ---------------------------------------------------------------------------
# Drawing — programmatic kitchen scene
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Backdrop fill (dark wall) + floor stripe
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_BG)
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, VIEWPORT_H - FLOOR_Y), COLOR_FLOOR)
	# Wall trim — 2px highlight strip at the floor join
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1.0), COLOR_WALL.lightened(0.2))

	_draw_stove()
	_draw_table()
	_draw_mom()
	_draw_kid()


func _draw_stove() -> void:
	# Stove body
	draw_rect(Rect2(STOVE_X - 18, STOVE_Y - 12, 36, 30), COLOR_STOVE_BODY)
	# Burner ring
	draw_rect(Rect2(STOVE_X - 12, STOVE_Y - 4, 24, 6), COLOR_BURNER)
	# Pot on the burner
	draw_rect(Rect2(STOVE_X - 10, STOVE_Y - 14, 20, 10), COLOR_POT)
	draw_rect(Rect2(STOVE_X - 11, STOVE_Y - 15, 22, 1), COLOR_POT_RIM)
	# Animated flame peek out the burner sides
	var flame_phase: float = sin((_flame_t / 0.15) * TAU)
	var flame_h: float = 2.0 + (1.0 if flame_phase > 0.0 else 0.0)
	draw_rect(Rect2(STOVE_X - 11, STOVE_Y, 4, flame_h), COLOR_FLAME)
	draw_rect(Rect2(STOVE_X + 7, STOVE_Y, 4, flame_h), COLOR_FLAME)
	# Steam puffs rising — 2 dots cycling up
	var steam_y0: float = float(STOVE_Y) - 18.0 - fmod(_steam_t * 14.0, 18.0)
	var steam_y1: float = float(STOVE_Y) - 18.0 - fmod(_steam_t * 14.0 + 9.0, 18.0)
	var steam_alpha0: float = 1.0 - fmod(_steam_t * 14.0, 18.0) / 18.0
	var steam_alpha1: float = 1.0 - fmod(_steam_t * 14.0 + 9.0, 18.0) / 18.0
	var c0: Color = COLOR_STEAM
	c0.a = clampf(steam_alpha0, 0.0, 1.0)
	var c1: Color = COLOR_STEAM
	c1.a = clampf(steam_alpha1, 0.0, 1.0)
	draw_rect(Rect2(STOVE_X - 2, steam_y0, 2, 2), c0)
	draw_rect(Rect2(STOVE_X + 1, steam_y1, 2, 2), c1)


func _draw_table() -> void:
	# Table top (large rect) + edge ink
	draw_rect(Rect2(TABLE_X - 30, TABLE_Y - 10, 60, 18), COLOR_TABLE)
	draw_rect(Rect2(TABLE_X - 30, TABLE_Y - 10, 60, 1), COLOR_TABLE_EDGE)
	draw_rect(Rect2(TABLE_X - 30, TABLE_Y + 7, 60, 1), COLOR_TABLE_EDGE)
	# Legs
	draw_rect(Rect2(TABLE_X - 28, TABLE_Y + 8, 2, 12), COLOR_TABLE)
	draw_rect(Rect2(TABLE_X + 26, TABLE_Y + 8, 2, 12), COLOR_TABLE)

	# Placed ingredient chips
	for ing in _placed_ingredients:
		var c: Color = FOOD_COLOR.get(ing["id"], Color.WHITE)
		var x: float = ing["x"] - 2.0
		var y: float = ing["y"] - 2.0
		draw_rect(Rect2(x, y, 4, 4), c)
		draw_rect(Rect2(x, y, 4, 1), Color("#2A1A0A"))
		draw_rect(Rect2(x, y + 3, 4, 1), Color("#2A1A0A"))


func _draw_mom() -> void:
	# Mum at the stove — same silhouette logic as MomNPC but inline since
	# we're not extending NPC here. Stationary (no bob — she's working).
	var x: int = MOM_X
	var y: int = MOM_Y
	# Hair top
	draw_rect(Rect2(x - 3, y - 7, 6, 2), Color("#3A1A0A"))
	# Hair bun
	draw_rect(Rect2(x - 2, y - 8, 4, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3, y - 5, 6, 4), Color("#F2D6A8"))
	# Eyes
	draw_rect(Rect2(x - 2, y - 3, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 1, y - 3, 1, 1), Color("#2A1A0A"))
	# Body (purple)
	draw_rect(Rect2(x - 4, y - 1, 8, 5), Color("#9A4A8A"))
	# Apron (cream)
	draw_rect(Rect2(x - 3, y + 1, 6, 3), Color("#F5EDDA"))
	# Legs (darker purple)
	draw_rect(Rect2(x - 3, y + 4, 2, 4), Color("#5A2A4A"))
	draw_rect(Rect2(x + 1, y + 4, 2, 4), Color("#5A2A4A"))


func _draw_kid() -> void:
	# Kid by the table — alternating-foot bob from the same step parity as
	# the gameplay walk cycle, so the silhouette feels consistent.
	var bob: float = sin((_kid_t / 0.55) * TAU)
	var bob_y: float = -1.0 if bob > 0.0 else 0.0
	var x: int = KID_X
	var y: int = KID_Y
	# Hair top
	draw_rect(Rect2(x - 3, y - 7 + bob_y, 6, 2), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3, y - 5 + bob_y, 6, 4), Color("#F2D6A8"))
	# Eyes (looking up at the food being placed)
	draw_rect(Rect2(x - 2, y - 3 + bob_y, 1, 1), Color("#2A1A0A"))
	draw_rect(Rect2(x + 1, y - 3 + bob_y, 1, 1), Color("#2A1A0A"))
	# Yellow shirt
	draw_rect(Rect2(x - 4, y - 1 + bob_y, 8, 5), Color("#E8F542"))
	draw_rect(Rect2(x - 4, y - 1 + bob_y, 8, 1), Color("#E8F542").darkened(0.25))
	# Blue shorts
	draw_rect(Rect2(x - 3, y + 4 + bob_y, 2, 3), Color("#3A4A8A"))
	draw_rect(Rect2(x + 1, y + 4 + bob_y, 2, 3), Color("#3A4A8A"))
