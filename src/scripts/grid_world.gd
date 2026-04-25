## Grid coordinate utilities for Night Market Shopping.
##
## All gameplay positions are stored as `Vector2i` cells. This class is the
## sole authority for converting between cell coordinates and pixel positions,
## and for bounds-checking. Pure functions only (no node state) — instantiate
## as `RefCounted` rather than `Node`.
##
## Convention: a cell's pixel position refers to its CENTRE (not top-left).
## A 14×14 sprite centred on the cell origin sits cleanly inside the 16×16 cell
## with 1px gutter on each side.
class_name GridWorld
extends RefCounted

## Edge length of every grid cell in pixels.
const TILE_SIZE: int = 16


## Returns the world-space pixel position of the *centre* of the given cell.
## Cell (0, 0)'s centre is at (8, 8); cell (1, 0)'s centre is at (24, 8); etc.
static func cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * TILE_SIZE + TILE_SIZE / 2),
		float(cell.y * TILE_SIZE + TILE_SIZE / 2)
	)


## Inverse of cell_to_px. Rounds to the nearest cell.
## A pixel exactly on a cell boundary (e.g. x=16) maps to the cell on the
## positive side (cell (1, ?)), per `floor()` semantics.
static func px_to_cell(px: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(px.x / float(TILE_SIZE))),
		int(floor(px.y / float(TILE_SIZE)))
	)


## True iff `cell` lies inside the half-open rectangle [0,grid_w) × [0,grid_h).
static func in_bounds(cell: Vector2i, grid_w: int, grid_h: int) -> bool:
	return cell.x >= 0 and cell.x < grid_w and cell.y >= 0 and cell.y < grid_h
