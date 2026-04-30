## Level 1 — Shilin Night Market for Night Market Shopping (R-003).
##
## Programmatically builds a 25×14 cell grid: floor tiles drawn in alternating
## shades for visual rhythm, walls around the perimeter, 5 reserved stall
## cells (StallNPCs land here in R-006), 1 reserved cell for mum (MomNPC in
## R-008). Spawns the PlayerGrid at the home cell and a Camera2D that follows
## with clamping so the player stays inside the world bounds.
##
## Note: spec called for 20×11 single-screen; bumped to 25×14 (400×224 px)
## so the camera has room to scroll and the world feels more like a market
## to walk through.
class_name ShilinMarket
extends Node2D

# ---------------------------------------------------------------------------
# Geometry constants
# ---------------------------------------------------------------------------

const GRID_W: int = 25
const GRID_H: int = 14
const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const HOME_CELL: Vector2i = Vector2i(2, 11)
const MOM_CELL: Vector2i = Vector2i(3, 11)

## Cells reserved for stall NPCs. v0.7 expanded to 7 stalls.
const STALL_CELLS: Array[Vector2i] = [
	Vector2i(6, 3),
	Vector2i(12, 3),
	Vector2i(18, 3),
	Vector2i(6, 8),
	Vector2i(12, 8),
	Vector2i(18, 8),
	Vector2i(20, 5),
]

## Per-stall configuration — one entry per STALL_CELLS index.
## Total cheapest 5 = 190; with STARTING_MONEY=180 the player MUST bargain
## successfully at least once OR pick the cheapest 5 and skip the dearer two.
## v0.23: each `intro` is now a POOL of 4 lines; StallNPC picks one at random
## per bump for vendor-chatter variety.
const STALL_DATA: Array[Dictionary] = [
	{"id": "scallion",  "price": 20, "intro": [
		"新鮮蔥阿，要買嗎？",
		"我家蔥都自己種的，甜！",
		"今天蔥特別嫩喔～",
		"便宜啦，三把 60 才便宜！",
	]},
	{"id": "egg",       "price": 30, "intro": [
		"雞蛋一盒 30 元！",
		"我家雞蛋都當天現生的喔",
		"今天蛋特別漂亮！",
		"蛋黃黃黃的，超讚",
	]},
	{"id": "cabbage",   "price": 40, "intro": [
		"高麗菜，自家種的！",
		"山上來的高麗菜，脆脆的",
		"今天高麗菜特別大顆",
		"包水餃用最棒喔～",
	]},
	{"id": "chicken",   "price": 50, "intro": [
		"雞肉新鮮現宰！",
		"今天雞肉品質特別好",
		"回家煮雞湯最棒",
		"幫媽媽多買一斤啦",
	]},
	{"id": "soy_sauce", "price": 50, "intro": [
		"陳年醬油，一瓶 50！",
		"我們家醬油發酵 180 天",
		"炒菜放一點，鹹香鹹香",
		"這瓶陳年的，比超市便宜",
	]},
	{"id": "tofu",      "price": 60, "intro": [
		"手工嫩豆腐！",
		"今天豆腐才剛現做",
		"做豆腐花最棒",
		"我阿媽的祖傳配方喔",
	]},
	{"id": "mushroom",  "price": 70, "intro": [
		"山上採的香菇，補！",
		"新鮮乾香菇都有",
		"香菇雞湯一級棒",
		"南投來的，嚴選的",
	]},
]

## Chatter NPC slots — atmospheric world-flavour, no shop.
const CHATTER_DATA: Array[Dictionary] = [
	{
		"cell": Vector2i(10, 11),
		"color": Color("#5A8A5A"),  # green-ish (apron)
		"pool": [
			"今天人好多喔。",
			"那家蔥比較甜，我都買那家。",
			"小心錢包，人擠人小心扒手！",
		],
	},
	{
		"cell": Vector2i(15, 11),
		"color": Color("#8A6A4A"),  # tan (uncle)
		"pool": [
			"啊你媽派你來買菜啊？乖喔。",
			"我以前也是這樣被叫來夜市的。",
			"哎呀我來這 30 年了！",
		],
	},
	{
		"cell": Vector2i(8, 6),
		"color": Color("#A06090"),  # purple-ish (kid)
		"pool": [
			"你也來買晚餐喔？",
			"那邊賣雞肉的最好吃！",
			"快點啦，我媽在等。",
		],
	},
	{
		"cell": Vector2i(20, 6),
		"color": Color("#B8A050"),  # mustard (auntie)
		"pool": [
			"小弟弟要錢嗎？阿姨給你 5 塊。",  # could be a tease line
			"我覺得今天醬油那攤打折了！",
			"哎喲走路看路啦！",
		],
	},
]

## v0.17: ambient crowd — wander shoppers along 2 lanes for atmosphere.
## Each entry seeds a WanderShopper instance. No interaction, just life.
const SHOPPER_DATA: Array[Dictionary] = [
	# Upper lane — walking right
	{ "lane_y": 104.0, "direction":  1, "speed": 18.0,
	  "body": Color("#3A5A8A"), "hat": Color("#2A1A0A") },  # blue shirt
	{ "lane_y": 104.0, "direction":  1, "speed": 24.0,
	  "body": Color("#9A4A3A"), "hat": Color("#3A1A0A") },  # red shirt
	# Lower lane — walking left
	{ "lane_y": 152.0, "direction": -1, "speed": 16.0,
	  "body": Color("#5A8A4A"), "hat": Color("#3A1A0A") },  # green shirt
	{ "lane_y": 152.0, "direction": -1, "speed": 22.0,
	  "body": Color("#B86C30"), "hat": Color("#5A3A2A") },  # orange shirt
]

## Item pickups scattered on the floor — free money / loose change.
const ITEM_DATA: Array[Dictionary] = [
	{"cell": Vector2i(11, 5), "value": 10, "line": "撿到 NT$10！"},
	{"cell": Vector2i(4, 7), "value": 5,  "line": "撿到 NT$5。"},
	{"cell": Vector2i(22, 11), "value": 10, "line": "撿到 NT$10！"},
]

## Bonus pickup tuning — spawned at a random walkable cell each run.
const BONUS_VALUE: int = 15
const BONUS_LINE: String = "★ 哎呀，地上有人掉的 NT$15！"
const BONUS_COLOR: Color = Color("#7AC940")  # green — distinct from gold

# v0.21 — random street events. Each rolls independently per run.
const WALLET_CHANCE: float = 0.35
const WALLET_VALUE: int = 25
const WALLET_LINE: String = "★ 撿到一個錢包！NT$25"
const WALLET_COLOR: Color = Color("#8A4A28")  # brown leather

const LOST_CAT_CHANCE: float = 0.25
const RAIN_CHANCE: float = 0.30
## Delay before rain starts after entering the market (seconds).
const RAIN_DELAY_MIN: float = 4.0
const RAIN_DELAY_MAX: float = 14.0

# v0.31 — weekend 紅包. Guaranteed (not chance) when the rotating-week day
# is Sat or Sun. Bigger value than wallet so weekends feel like a payday.
const RED_ENVELOPE_VALUE: int = 50
const RED_ENVELOPE_LINE: String = "★ 週末紅包！NT$50"
const RED_ENVELOPE_COLOR: Color = Color("#C2241A")  # festive red

# Palette
const COLOR_FLOOR_A: Color = Color("#3A1A0A")  ## warm dark brown
const COLOR_FLOOR_B: Color = Color("#4A2412")  ## one shade lighter (rhythm)
const COLOR_WALL: Color = Color("#2A1408")     ## near-black for walls
const COLOR_HOME: Color = Color("#5A3220")     ## warm wood frame on home cell
const COLOR_HOME_DOOR: Color = Color("#7A4A2A")  ## door panel
const COLOR_HOME_DOOR_FRAME: Color = Color("#2A1408")  ## door frame ink
const COLOR_DEBRIS: Color = Color("#5A3220")   ## scattered floor pebble dots

## Deterministic pseudo-random debris dots scattered on floor cells. Same
## (x,y) → same dot pattern across runs so the map has a consistent feel.
const DEBRIS_CHANCE: int = 7  ## 1 in N floor cells gets a debris pixel

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## walkable[y][x] = true iff the player can step into cell (x, y).
var walkable: Array[Array] = []

# ---------------------------------------------------------------------------
# Private references
# ---------------------------------------------------------------------------

var _player: PlayerGrid
var _camera: Camera2D
var _hud: HudRpg
var _lanterns: Lanterns

## NPCs indexed by their cell, for O(1) bump lookup.
var _npcs_by_cell: Dictionary[Vector2i, NPC] = {}

## Floor pickups indexed by cell. Removed when collected.
var _items_by_cell: Dictionary[Vector2i, ItemPickup] = {}

## v0.21: lost cats (random event NPCs) indexed by cell so bumps dispatch
## correctly. Cleared when the cat despawns. Cats aren't NPC subclasses so
## they live in a separate dictionary from _npcs_by_cell.
var _lost_cats_by_cell: Dictionary[Vector2i, LostCat] = {}

## Camera shake state — triggered on wall bumps. Decays linearly to 0.
var _shake_t: float = 0.0
const SHAKE_DURATION: float = 0.15
const SHAKE_AMPLITUDE: float = 2.0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "shilin"
	_build_walkable_map()
	_spawn_player()
	_spawn_camera()
	_spawn_stalls()
	_spawn_chatters()
	_spawn_shoppers()
	_spawn_items()
	_spawn_random_events()
	_spawn_mom()
	_spawn_hud()
	_spawn_lanterns()
	_player.bumped.connect(_on_player_bumped)
	_player.cell_changed.connect(_on_player_cell_changed)
	Music.play_market()


func _spawn_mom() -> void:
	var mom: MomNPC = MomNPC.new()
	mom.cell = MOM_CELL
	register_npc(mom)


func _spawn_hud() -> void:
	_hud = HudRpg.new()
	_hud.name = "Hud"
	add_child(_hud)


func _spawn_lanterns() -> void:
	_lanterns = Lanterns.new()
	_lanterns.name = "Lanterns"
	add_child(_lanterns)


func _spawn_stalls() -> void:
	# v0.9: shuffle which ingredient lands at which cell. Each (id, price,
	# intro) tuple stays intact — only the position assignment varies. This
	# means players can't memorise "蔥 is always at the top-left", they have
	# to look at each stall's awning icon to plan.
	var indices: Array[int] = []
	for i in STALL_DATA.size():
		indices.append(i)
	indices.shuffle()
	# Pick one stall slot (post-shuffle) to discount by 20%.
	var discount_slot: int = randi() % STALL_CELLS.size()
	for slot in STALL_CELLS.size():
		var data: Dictionary = STALL_DATA[indices[slot]]
		var stall: StallNPC = StallNPC.new()
		stall.cell = STALL_CELLS[slot]
		stall.ingredient_id = data["id"]
		stall.price = data["price"]
		# Explicit typed-array assign: dict literal stored as untyped Array,
		# cannot auto-coerce to Array[String].
		var intro: Array[String] = []
		intro.assign(data["intro"])
		stall.intro_lines = intro
		if slot == discount_slot:
			stall.discount = 0.8
		register_npc(stall)


## v0.17: spawns ambient wandering shoppers. Pure visual, no interaction.
## Stagger their starting X across the map so they don't all clump on spawn.
func _spawn_shoppers() -> void:
	for i in SHOPPER_DATA.size():
		var data: Dictionary = SHOPPER_DATA[i]
		var s: WanderShopper = WanderShopper.new()
		s.lane_y = float(data["lane_y"])
		s.direction = int(data["direction"])
		s.speed = float(data["speed"])
		s.body_color = data["body"]
		s.hat_color = data["hat"]
		# Even spread along the X band — first shopper near left, last near right.
		var spread: float = float(i) / float(SHOPPER_DATA.size())
		s.position = Vector2(
			lerpf(s.x_min, s.x_max, spread),
			s.lane_y
		)
		# Seed _x to match the spread position so the wrap logic continues
		# from there instead of snapping back to x_min on first _process tick.
		s._x = s.position.x
		add_child(s)


## Spawns the world-flavour NPCs (no shop, no quest blockers).
func _spawn_chatters() -> void:
	for data: Dictionary in CHATTER_DATA:
		var npc: ChatterNPC = ChatterNPC.new()
		npc.cell = data["cell"]
		npc.body_color = data["color"]
		var pool: Array[String] = []
		pool.assign(data["pool"])
		npc.chatter_pool = pool
		register_npc(npc)


## Spawns floor pickups (free money sparkle items).
func _spawn_items() -> void:
	for data: Dictionary in ITEM_DATA:
		var c: Vector2i = data["cell"]
		# Skip cells that overlap an NPC or wall (shouldn't happen, but safe).
		if not is_walkable(c):
			continue
		var item: ItemPickup = ItemPickup.new()
		item.cell = c
		item.value = data["value"]
		item.pickup_line = data["line"]
		add_child(item)
		_items_by_cell[c] = item
	_spawn_bonus_pickup()


## v0.21: rolls independent random street events for this run.
##   * Wallet pickup (35%)  — bigger NT$25 brown leather coin
##   * Lost cat (25%)       — NPC at random cell, choice for +NT$20
##   * Rain (30%)           — 8-second weather overlay, fires after a delay
##
## v0.31: when today is the weekend (Sat / Sun in the rotating week), a
## guaranteed 紅包 also spawns at a free cell — NT$50, red. Skipped in
## test_mode so deterministic tests don't trip over the extra spawn.
func _spawn_random_events() -> void:
	if randf() < WALLET_CHANCE:
		_spawn_wallet()
	if randf() < LOST_CAT_CHANCE:
		_spawn_lost_cat()
	if randf() < RAIN_CHANCE:
		_schedule_rain()
	if Inventory.is_weekend() and not Game.test_mode:
		_spawn_red_envelope()


func _spawn_wallet() -> void:
	var pick: Vector2i = _random_free_cell()
	if pick == Vector2i(-1, -1):
		return
	var item: ItemPickup = ItemPickup.new()
	item.cell = pick
	item.value = WALLET_VALUE
	item.pickup_line = WALLET_LINE
	item.color = WALLET_COLOR
	add_child(item)
	_items_by_cell[pick] = item


## v0.31: weekend 紅包 — guaranteed when Inventory.is_weekend(). Same
## ItemPickup machinery as the wallet, just bigger value + red colour.
func _spawn_red_envelope() -> void:
	var pick: Vector2i = _random_free_cell()
	if pick == Vector2i(-1, -1):
		return
	var item: ItemPickup = ItemPickup.new()
	item.cell = pick
	item.value = RED_ENVELOPE_VALUE
	item.pickup_line = RED_ENVELOPE_LINE
	item.color = RED_ENVELOPE_COLOR
	add_child(item)
	_items_by_cell[pick] = item


func _spawn_lost_cat() -> void:
	var pick: Vector2i = _random_free_cell()
	if pick == Vector2i(-1, -1):
		return
	var cat: LostCat = LostCat.new()
	cat.cell = pick
	cat.despawned.connect(_on_cat_despawned)
	add_child(cat)
	_lost_cats_by_cell[pick] = cat
	# Mark the cell unwalkable so the player bumps instead of stepping onto it.
	if GridWorld.in_bounds(pick, GRID_W, GRID_H):
		walkable[pick.y][pick.x] = false


## v0.21: cat returned to its owner — free the cell and the dict slot so
## the player can walk through it again (and so the cell is reusable for
## other spawns if any future system needs it).
func _on_cat_despawned(freed_cell: Vector2i) -> void:
	_lost_cats_by_cell.erase(freed_cell)
	if GridWorld.in_bounds(freed_cell, GRID_W, GRID_H):
		walkable[freed_cell.y][freed_cell.x] = true


func _schedule_rain() -> void:
	var delay: float = randf_range(RAIN_DELAY_MIN, RAIN_DELAY_MAX)
	get_tree().create_timer(delay).timeout.connect(_start_rain)


func _start_rain() -> void:
	# Don't stack overlapping rain layers if the timer somehow fires twice.
	if has_node("Rain"):
		return
	var rain: RainOverlay = RainOverlay.new()
	rain.name = "Rain"
	add_child(rain)


## Picks any walkable cell that isn't reserved (home, mom, existing items
## or cats). Returns Vector2i(-1, -1) if no candidates remain.
func _random_free_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var c: Vector2i = Vector2i(x, y)
			if not is_walkable(c):
				continue
			if c == HOME_CELL or c == MOM_CELL:
				continue
			if _items_by_cell.has(c):
				continue
			if _lost_cats_by_cell.has(c):
				continue
			candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


## v0.9: one extra coin per run at a random walkable cell. Distinct green
## colour so it reads as "rare find" vs the standard gold pickups.
func _spawn_bonus_pickup() -> void:
	# Build the candidate cell list once: walkable + not home + not mom +
	# not already an item + not directly under the player spawn.
	var candidates: Array[Vector2i] = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var c: Vector2i = Vector2i(x, y)
			if not is_walkable(c):
				continue
			if c == HOME_CELL or c == MOM_CELL:
				continue
			if _items_by_cell.has(c):
				continue
			candidates.append(c)
	if candidates.is_empty():
		return
	var pick: Vector2i = candidates[randi() % candidates.size()]
	var item: ItemPickup = ItemPickup.new()
	item.cell = pick
	item.value = BONUS_VALUE
	item.pickup_line = BONUS_LINE
	item.color = BONUS_COLOR
	add_child(item)
	_items_by_cell[pick] = item


## Called when the player finishes a step. Picks up any item on that cell.
func _on_player_cell_changed(new_cell: Vector2i) -> void:
	var item: ItemPickup = _items_by_cell.get(new_cell, null)
	if item == null:
		return
	_items_by_cell.erase(new_cell)
	item.collect()


# ---------------------------------------------------------------------------
# Public API — register NPCs (called by R-006/R-008 spawn helpers)
# ---------------------------------------------------------------------------

## Adds an NPC as a child and indexes it by its cell so bumps trigger its
## `on_bumped()` handler. The cell is also marked unwalkable.
func register_npc(npc: NPC) -> void:
	add_child(npc)
	_npcs_by_cell[npc.cell] = npc
	if GridWorld.in_bounds(npc.cell, GRID_W, GRID_H):
		walkable[npc.cell.y][npc.cell.x] = false


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

## Called when PlayerGrid emits `bumped(target_cell)`. If an NPC sits on the
## bumped cell, dispatch to its on_bumped(). No-op otherwise.
func _on_player_bumped(target_cell: Vector2i) -> void:
	var npc: NPC = _npcs_by_cell.get(target_cell, null)
	if npc != null:
		npc.on_bumped()
		return
	# v0.21: lost cats live in their own dict — same bump semantics.
	var cat: LostCat = _lost_cats_by_cell.get(target_cell, null)
	if cat != null:
		cat.on_bumped()
		return
	# Wall thunk — only when there's no NPC, so dialogue intros don't
	# get a redundant bump cue stacked under the typewriter blips.
	Sfx.play_bump()
	_shake_t = SHAKE_DURATION


func _process(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
	_update_camera()


func _draw() -> void:
	_draw_floor_and_walls()


# ---------------------------------------------------------------------------
# Build helpers
# ---------------------------------------------------------------------------

func _build_walkable_map() -> void:
	walkable.resize(GRID_H)
	for y in GRID_H:
		var row: Array = []
		row.resize(GRID_W)
		for x in GRID_W:
			row[x] = _initial_walkable(x, y)
		walkable[y] = row


## Returns the static walkability of a cell (independent of any NPCs).
func _initial_walkable(x: int, y: int) -> bool:
	# Perimeter walls.
	if x == 0 or x == GRID_W - 1 or y == 0 or y == GRID_H - 1:
		return false
	# Reserved stall cells — players bump into stalls, not through them.
	for sc in STALL_CELLS:
		if sc.x == x and sc.y == y:
			return false
	# Reserved mum cell — same: bump triggers dialogue (R-004 / R-008).
	if MOM_CELL.x == x and MOM_CELL.y == y:
		return false
	return true


func _spawn_player() -> void:
	_player = PlayerGrid.new()
	_player.name = "Player"
	_player.start_cell = HOME_CELL
	_player.walkable_check = Callable(self, "is_walkable")
	add_child(_player)


func _spawn_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "GameCamera"
	# Initial position so first frame doesn't snap.
	_camera.position = GridWorld.cell_to_px(HOME_CELL)
	add_child(_camera)
	_camera.make_current()


# ---------------------------------------------------------------------------
# Per-frame updates
# ---------------------------------------------------------------------------

## Camera follows the player with edge clamping so the view never shows
## outside the world bounds. Pixel-snapped each frame to avoid sub-pixel
## jitter under the integer-scale stretch mode.
func _update_camera() -> void:
	if _camera == null or _player == null:
		return
	var map_w: int = GRID_W * GridWorld.TILE_SIZE
	var map_h: int = GRID_H * GridWorld.TILE_SIZE
	var half_w: float = VIEWPORT_W / 2.0
	var half_h: float = VIEWPORT_H / 2.0
	# `max(half, map - half)` collapses to `half` when the map is narrower
	# than the viewport, so the camera stays centred (no jitter from clamp).
	var max_x: float = maxf(half_w, float(map_w) - half_w)
	var max_y: float = maxf(half_h, float(map_h) - half_h)
	var cx: float = clampf(_player.position.x, half_w, max_x)
	var cy: float = clampf(_player.position.y, half_h, max_y)
	# Camera shake — fades linearly with _shake_t over SHAKE_DURATION.
	if _shake_t > 0.0:
		var fade: float = _shake_t / SHAKE_DURATION
		cx += (randf() * 2.0 - 1.0) * SHAKE_AMPLITUDE * fade
		cy += (randf() * 2.0 - 1.0) * SHAKE_AMPLITUDE * fade
	_camera.position = Vector2(roundf(cx), roundf(cy))


# ---------------------------------------------------------------------------
# Drawing — single _draw call paints the entire floor + walls
# ---------------------------------------------------------------------------

func _draw_floor_and_walls() -> void:
	for y in GRID_H:
		for x in GRID_W:
			var px: Vector2 = GridWorld.cell_to_px(Vector2i(x, y))
			var rect: Rect2 = Rect2(
				px.x - GridWorld.TILE_SIZE / 2.0,
				px.y - GridWorld.TILE_SIZE / 2.0,
				GridWorld.TILE_SIZE,
				GridWorld.TILE_SIZE
			)
			var color: Color = _color_for_cell(x, y)
			draw_rect(rect, color)
			_draw_cell_decoration(x, y, px)


## Per-cell extras: home-cell door, scattered debris pebbles on floor cells.
func _draw_cell_decoration(x: int, y: int, px: Vector2) -> void:
	# Home cell — render a small door panel framed in dark ink
	if x == HOME_CELL.x and y == HOME_CELL.y:
		# Door frame: 8×11 ink rect spanning most of the cell
		draw_rect(Rect2(px.x - 4.0, px.y - 5.0, 8.0, 11.0), COLOR_HOME_DOOR_FRAME)
		# Door panel: 6×9 wood inside the frame
		draw_rect(Rect2(px.x - 3.0, px.y - 4.0, 6.0, 9.0), COLOR_HOME_DOOR)
		# Doorknob: 1px gold dot
		draw_rect(Rect2(px.x + 1.0, px.y, 1.0, 1.0), Color("#F2A227"))
		return
	# Walls / stalls / mum cells skip debris.
	if x == 0 or x == GRID_W - 1 or y == 0 or y == GRID_H - 1:
		return
	for sc in STALL_CELLS:
		if sc.x == x and sc.y == y:
			return
	if x == MOM_CELL.x and y == MOM_CELL.y:
		return
	# Deterministic debris speckle: hash position to decide dot placement.
	# Same (x,y) → same hash → same dot every run, no pop-in randomness.
	var h: int = (x * 73856093) ^ (y * 19349663)
	if (h % DEBRIS_CHANCE) == 0:
		# 1px dot at a deterministic offset within the cell.
		var dx: float = float((h >> 8) & 7) - 3.5
		var dy: float = float((h >> 16) & 7) - 3.5
		draw_rect(Rect2(px.x + dx, px.y + dy, 1.0, 1.0), COLOR_DEBRIS)


func _color_for_cell(x: int, y: int) -> Color:
	if x == 0 or x == GRID_W - 1 or y == 0 or y == GRID_H - 1:
		return COLOR_WALL
	if x == HOME_CELL.x and y == HOME_CELL.y:
		return COLOR_HOME
	# Checker pattern for floor visibility — alternate per-cell.
	if (x + y) % 2 == 0:
		return COLOR_FLOOR_A
	return COLOR_FLOOR_B


# ---------------------------------------------------------------------------
# Public API — passed as Callable to PlayerGrid
# ---------------------------------------------------------------------------

## True iff the cell is in-bounds AND its walkable[y][x] entry is true.
func is_walkable(cell: Vector2i) -> bool:
	if not GridWorld.in_bounds(cell, GRID_W, GRID_H):
		return false
	return walkable[cell.y][cell.x]
