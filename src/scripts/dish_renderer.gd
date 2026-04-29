## v0.24: shared dish-drawing helpers extracted from Kitchen so the cookbook
## journal can render the same dishes at the same shading as the kitchen plate.
##
## All functions are static and take a `canvas: CanvasItem` first arg, so any
## node that uses `_draw()` can call them. (Kitchen passes `self`; Cookbook
## passes the dish-cell control.)
##
## Layout: every dish drawer fits a (w×h) rect at (x, y) — a 28×7 standard
## plate or a 34×8 perfect plate works best, but any size is clipped via the
## helper functions.
class_name DishRenderer
extends RefCounted

# ---------------------------------------------------------------------------
# Palette — shared across kitchen and cookbook
# ---------------------------------------------------------------------------

const COLOR_CHICKEN_LIGHT: Color = Color("#D4965A")
const COLOR_CHICKEN_BROWN: Color = Color("#A36B3A")
const COLOR_CHICKEN_DARK: Color = Color("#7A4A2A")
const COLOR_SOY_GLOSS: Color = Color("#3A1A0A")
const COLOR_SOY_HIGHLIGHT: Color = Color("#6A3A2A")
const COLOR_SESAME: Color = Color("#F5EDDA")
const COLOR_BASIL: Color = Color("#3A6A2A")
const COLOR_BASIL_LIGHT: Color = Color("#5A9A3A")
const COLOR_EGG_YELLOW: Color = Color("#FFE9B0")
const COLOR_EGG_BROWNED: Color = Color("#E8C870")
const COLOR_EGG_DARK: Color = Color("#C8A848")
const COLOR_SCALLION_GREEN: Color = Color("#7AC940")
const COLOR_SCALLION_DARK: Color = Color("#5A9028")
const COLOR_MUSHROOM_LIGHT: Color = Color("#A06A4A")
const COLOR_MUSHROOM_BROWN: Color = Color("#7A4A2A")
const COLOR_MUSHROOM_DARK: Color = Color("#5A3018")
const COLOR_TOFU_WHITE: Color = Color("#F8F0D8")
const COLOR_TOFU_SHADOW: Color = Color("#D8C8A8")
const COLOR_REDCOOK_SAUCE: Color = Color("#5A2410")
const COLOR_REDCOOK_HIGHLIGHT: Color = Color("#7A3818")
const COLOR_BROTH_PALE: Color = Color("#F5E0B0")
const COLOR_BROTH_SHIMMER: Color = Color("#FFF8D8")
const COLOR_CABBAGE_LIGHT: Color = Color("#B8E890")
const COLOR_CABBAGE_MID: Color = Color("#9EE070")
const COLOR_CABBAGE_DARK: Color = Color("#5A8030")

## All seven dishes the recipe system can produce, in cookbook display order.
const ALL_DISHES: Array[String] = [
	"三杯雞",
	"醬油雞",
	"蔥蛋",
	"香菇炒蛋",
	"紅燒豆腐",
	"豆腐高麗菜湯",
	"清炒高麗菜",
]

# ---------------------------------------------------------------------------
# Public dispatch
# ---------------------------------------------------------------------------

## Draws the named dish onto `canvas` inside the rect (x, y, w, h).
## Unknown dish names are no-ops — caller should fall back to placeholder art.
static func draw_dish(canvas: CanvasItem, dish_name: String,
		x: int, y: int, w: int, h: int) -> void:
	match dish_name:
		"三杯雞":         _draw_dish_sanbei(canvas, x, y, w, h)
		"醬油雞":         _draw_dish_soy_chicken(canvas, x, y, w, h)
		"蔥蛋":           _draw_dish_scallion_egg(canvas, x, y, w, h)
		"香菇炒蛋":       _draw_dish_mushroom_egg(canvas, x, y, w, h)
		"紅燒豆腐":       _draw_dish_red_tofu(canvas, x, y, w, h)
		"豆腐高麗菜湯":   _draw_dish_tofu_soup(canvas, x, y, w, h)
		"清炒高麗菜":     _draw_dish_stirfry_cabbage(canvas, x, y, w, h)


# ---------------------------------------------------------------------------
# Pure-pixel helpers
# ---------------------------------------------------------------------------

static func _dot(canvas: CanvasItem, x: int, y: int, w: int, h: int,
		ox: int, oy: int, c: Color) -> void:
	if ox < 0 or oy < 0 or ox >= w or oy >= h:
		return
	canvas.draw_rect(Rect2(x + ox, y + oy, 1, 1), c)


static func _chunk2(canvas: CanvasItem, x: int, y: int, w: int, h: int,
		ox: int, oy: int, c: Color) -> void:
	if ox < 0 or oy < 0 or ox + 1 >= w or oy + 1 >= h:
		return
	canvas.draw_rect(Rect2(x + ox, y + oy, 2, 2), c)


static func _chunk_chicken(canvas: CanvasItem, x: int, y: int, w: int, h: int,
		ox: int, oy: int) -> void:
	if ox < 0 or oy < 0 or ox + 3 >= w or oy + 2 >= h:
		return
	canvas.draw_rect(Rect2(x + ox, y + oy, 4, 3), COLOR_CHICKEN_BROWN)
	canvas.draw_rect(Rect2(x + ox, y + oy, 4, 1), COLOR_CHICKEN_LIGHT)
	canvas.draw_rect(Rect2(x + ox, y + oy + 2, 4, 1), COLOR_CHICKEN_DARK)
	canvas.draw_rect(Rect2(x + ox + 1, y + oy, 1, 1),
		COLOR_CHICKEN_LIGHT.lightened(0.2))


# ---------------------------------------------------------------------------
# Per-dish drawers
# ---------------------------------------------------------------------------

static func _draw_dish_sanbei(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y + h - 1, w, 1), COLOR_SOY_GLOSS)
	_dot(canvas, x, y, w, h, w / 4, h - 1, COLOR_SOY_HIGHLIGHT)
	_dot(canvas, x, y, w, h, 3 * w / 4, h - 1, COLOR_SOY_HIGHLIGHT)
	for chunk in [[1, 2], [7, 1], [13, 2], [19, 1], [4, 4], [16, 4]]:
		_chunk_chicken(canvas, x, y, w, h, int(chunk[0]), int(chunk[1]))
	for b in [[5, 0], [11, 0], [17, 0], [23, 1]]:
		var bx: int = int(b[0])
		var by: int = int(b[1])
		_chunk2(canvas, x, y, w, h, bx, by, COLOR_BASIL)
		_dot(canvas, x, y, w, h, bx + 1, by, COLOR_BASIL_LIGHT)
	for s in [[3, 1], [9, 0], [15, 1], [21, 0], [25, 2], [8, 4]]:
		_dot(canvas, x, y, w, h, int(s[0]), int(s[1]), COLOR_SESAME)


static func _draw_dish_soy_chicken(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y + h - 1, w, 1), COLOR_SOY_GLOSS)
	_dot(canvas, x, y, w, h, w / 2, h - 1, COLOR_SOY_HIGHLIGHT)
	for i in 4:
		var cx: int = x + 1 + i * 6
		var cy: int = y + 1
		if cx + 5 > x + w:
			break
		canvas.draw_rect(Rect2(cx, cy, 5, h - 2), COLOR_CHICKEN_BROWN)
		canvas.draw_rect(Rect2(cx, cy + 1, 5, 1), COLOR_CHICKEN_LIGHT)
		canvas.draw_rect(Rect2(cx, cy + h - 3, 5, 1), COLOR_CHICKEN_DARK)
		canvas.draw_rect(Rect2(cx, cy, 5, 1), COLOR_SOY_GLOSS)
		_dot(canvas, x, y, w, h, cx - x + 2, cy - y, COLOR_SOY_HIGHLIGHT)
		_dot(canvas, x, y, w, h, cx - x + 1, cy - y + 1, COLOR_SESAME)
		_dot(canvas, x, y, w, h, cx - x + 3, cy - y + 1, COLOR_SESAME)


static func _draw_dish_scallion_egg(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), COLOR_EGG_YELLOW)
	canvas.draw_rect(Rect2(x, y, w, 1), COLOR_EGG_BROWNED)
	canvas.draw_rect(Rect2(x, y + h - 1, w, 1), COLOR_EGG_DARK)
	for ex in [2, 8, 14, 21, 26]:
		_dot(canvas, x, y, w, h, ex, 0, COLOR_EGG_DARK)
	for fy in [2, 4]:
		for fx in [4, 11, 18, 24]:
			_dot(canvas, x, y, w, h, fx, fy, COLOR_EGG_BROWNED)
	for seg in [[1, 1], [6, 2], [12, 1], [17, 3], [22, 2]]:
		var sx: int = int(seg[0])
		var sy: int = int(seg[1])
		if sx + 1 < w and sy < h:
			canvas.draw_rect(Rect2(x + sx, y + sy, 2, 1), COLOR_SCALLION_GREEN)
			_dot(canvas, x, y, w, h, sx, sy + 1, COLOR_SCALLION_DARK)
	for d in [[3, 3], [9, 4], [15, 4], [20, 1], [25, 3]]:
		_dot(canvas, x, y, w, h, int(d[0]), int(d[1]), COLOR_SCALLION_GREEN)


static func _draw_dish_mushroom_egg(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), COLOR_EGG_YELLOW)
	canvas.draw_rect(Rect2(x, y, w, 1), COLOR_EGG_BROWNED)
	canvas.draw_rect(Rect2(x, y + h - 1, w, 1), COLOR_EGG_DARK)
	for i in 4:
		var mx: int = x + 1 + i * 7
		var my: int = y + 1
		if mx + 4 > x + w:
			break
		canvas.draw_rect(Rect2(mx, my, 4, 1), COLOR_MUSHROOM_DARK)
		canvas.draw_rect(Rect2(mx, my + 1, 4, 2), COLOR_MUSHROOM_BROWN)
		_dot(canvas, x, y, w, h, mx - x + 1, my - y + 1, COLOR_MUSHROOM_LIGHT)
		_dot(canvas, x, y, w, h, mx - x + 1, my - y + 3, COLOR_MUSHROOM_DARK)
		_dot(canvas, x, y, w, h, mx - x + 2, my - y + 3, COLOR_MUSHROOM_DARK)
	for s in [[5, 4], [12, 4], [19, 4], [25, 4]]:
		_dot(canvas, x, y, w, h, int(s[0]), int(s[1]), COLOR_SCALLION_GREEN)


static func _draw_dish_red_tofu(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), COLOR_REDCOOK_SAUCE)
	canvas.draw_rect(Rect2(x + 2, y, w - 4, 1), COLOR_REDCOOK_HIGHLIGHT)
	for i in 3:
		var tx: int = x + 2 + i * 8
		var ty: int = y + 2
		if tx + 4 > x + w or ty + 3 > y + h:
			break
		canvas.draw_rect(Rect2(tx, ty, 4, 3), COLOR_TOFU_WHITE)
		canvas.draw_rect(Rect2(tx, ty, 4, 1), COLOR_TOFU_WHITE.lightened(0.15))
		canvas.draw_rect(Rect2(tx + 3, ty, 1, 3), COLOR_TOFU_SHADOW)
		_dot(canvas, x, y, w, h, tx - x + 1, ty - y, COLOR_REDCOOK_SAUCE)
	for s in [[5, 5], [12, 5], [19, 5], [25, 5]]:
		_dot(canvas, x, y, w, h, int(s[0]), int(s[1]), COLOR_SCALLION_GREEN)


static func _draw_dish_tofu_soup(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), COLOR_BROTH_PALE)
	for sx in [3, 8, 13, 18, 23]:
		_dot(canvas, x, y, w, h, sx, 0, COLOR_BROTH_SHIMMER)
	for sx in [5, 11, 17, 22]:
		_dot(canvas, x, y, w, h, sx, 1, COLOR_BROTH_SHIMMER)
	for i in 3:
		var tx: int = x + 3 + i * 8
		var ty: int = y + 2
		if tx + 3 > x + w or ty + 3 > y + h:
			break
		canvas.draw_rect(Rect2(tx, ty, 3, 3), COLOR_TOFU_WHITE)
		canvas.draw_rect(Rect2(tx, ty, 3, 1), COLOR_TOFU_WHITE.lightened(0.15))
		_dot(canvas, x, y, w, h, tx - x + 1, ty - y + 3,
			COLOR_BROTH_PALE.darkened(0.15))
	for c in [[6, 1], [13, 4], [20, 1], [25, 4]]:
		var cx: int = int(c[0])
		var cy: int = int(c[1])
		_chunk2(canvas, x, y, w, h, cx, cy, COLOR_CABBAGE_MID)
		_dot(canvas, x, y, w, h, cx, cy, COLOR_CABBAGE_LIGHT)


static func _draw_dish_stirfry_cabbage(canvas: CanvasItem,
		x: int, y: int, w: int, h: int) -> void:
	canvas.draw_rect(Rect2(x, y, w, h), COLOR_CABBAGE_MID)
	for c in [[1, 2], [5, 4], [9, 2], [14, 4], [18, 2], [22, 4], [26, 2]]:
		var cx: int = int(c[0])
		var cy: int = int(c[1])
		_chunk2(canvas, x, y, w, h, cx, cy, COLOR_CABBAGE_DARK)
	for c in [[3, 0], [7, 1], [12, 0], [17, 1], [21, 0], [25, 1]]:
		var cx: int = int(c[0])
		var cy: int = int(c[1])
		_chunk2(canvas, x, y, w, h, cx, cy, COLOR_CABBAGE_LIGHT)
	for h_pt in [[2, 0], [10, 0], [16, 0], [24, 0]]:
		_dot(canvas, x, y, w, h, int(h_pt[0]), int(h_pt[1]),
			COLOR_CABBAGE_LIGHT.lightened(0.3))
	for r in [[6, 3], [15, 3], [23, 3]]:
		_dot(canvas, x, y, w, h, int(r[0]), int(r[1]), Color("#C2241A"))
