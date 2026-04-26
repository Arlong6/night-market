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

## NPCs indexed by their cell, for O(1) bump lookup.
var _npcs_by_cell: Dictionary[Vector2i, NPC] = {}

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_walkable_map()
	_spawn_player()
	_spawn_camera()
	_spawn_stalls()
	_spawn_hud()
	_player.bumped.connect(_on_player_bumped)


func _spawn_hud() -> void:
	_hud = HudRpg.new()
	_hud.name = "Hud"
	add_child(_hud)


func _spawn_stalls() -> void:
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
		register_npc(stall)


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
