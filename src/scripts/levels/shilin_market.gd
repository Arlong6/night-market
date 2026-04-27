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

## Cells reserved for stall NPCs. R-006 spawns StallNPC instances here.
const STALL_CELLS: Array[Vector2i] = [
	Vector2i(6, 3),
	Vector2i(12, 3),
	Vector2i(18, 3),
	Vector2i(6, 8),
	Vector2i(18, 8),
]

## Per-stall configuration — one entry per STALL_CELLS index.
## Order matches REQUIRED_INGREDIENTS prices (20/30/40/50/50).
const STALL_DATA: Array[Dictionary] = [
	{"id": "scallion",  "price": 20, "intro": ["新鮮蔥阿，要買嗎？"]},
	{"id": "egg",       "price": 30, "intro": ["雞蛋一盒30元！"]},
	{"id": "cabbage",   "price": 40, "intro": ["高麗菜，自家種的！"]},
	{"id": "chicken",   "price": 50, "intro": ["雞肉新鮮現宰！"]},
	{"id": "soy_sauce", "price": 50, "intro": ["陳年醬油，一瓶50！"]},
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

## Item pickups scattered on the floor — free money / loose change.
const ITEM_DATA: Array[Dictionary] = [
	{"cell": Vector2i(11, 5), "value": 10, "line": "撿到 NT$10！"},
	{"cell": Vector2i(4, 7), "value": 5,  "line": "撿到 NT$5。"},
	{"cell": Vector2i(22, 11), "value": 10, "line": "撿到 NT$10！"},
]

# Palette
const COLOR_FLOOR_A: Color = Color("#3A1A0A")  ## warm dark brown
const COLOR_FLOOR_B: Color = Color("#4A2412")  ## one shade lighter (rhythm)
const COLOR_WALL: Color = Color("#2A1408")     ## near-black for walls
const COLOR_HOME: Color = Color("#5A3220")     ## faint highlight on home cell

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
	_spawn_items()
	_spawn_mom()
	_spawn_hud()
	_spawn_lanterns()
	_player.bumped.connect(_on_player_bumped)
	_player.cell_changed.connect(_on_player_cell_changed)


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
	# Pick one stall per run to discount by 20% (replayability touch).
	var discount_idx: int = randi() % STALL_CELLS.size()
	for i in STALL_CELLS.size():
		var data: Dictionary = STALL_DATA[i]
		var stall: StallNPC = StallNPC.new()
		stall.cell = STALL_CELLS[i]
		stall.ingredient_id = data["id"]
		stall.price = data["price"]
		# Explicit typed-array assign: dict literal stored as untyped Array,
		# cannot auto-coerce to Array[String].
		var intro: Array[String] = []
		intro.assign(data["intro"])
		stall.intro_lines = intro
		if i == discount_idx:
			stall.discount = 0.8
		register_npc(stall)


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
	else:
		# Wall thunk — only when there's no NPC, so dialogue intros don't
		# get a redundant bump cue stacked under the typewriter blips.
		Sfx.play_bump()


func _process(_delta: float) -> void:
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
