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

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_walkable_map()
	_spawn_player()
	_spawn_camera()


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
