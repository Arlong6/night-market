## Cookbook journal — v0.24.
##
## Cross-run progression panel showing every dish the recipe system can
## produce. Locked dishes appear as silhouettes with a lock glyph; unlocked
## dishes are rendered via DishRenderer (same drawer the kitchen plate uses)
## with a cook count below.
##
## Reachable from the title screen via the "C" key. ESC returns to title.
##
## All visuals are programmatic — no .tres / image assets so the page loads
## fast on web.
class_name Cookbook
extends Control

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

## 7 dishes laid out as a 4×2 grid (last row has 3 dishes — column-centered).
const COLS: int = 4
const ROWS: int = 2
const CELL_W: int = 64
const CELL_H: int = 56
const GRID_TOP: int = 38
const GRID_GAP_X: int = 8
const GRID_GAP_Y: int = 8

# Plate inside the cell — bigger than kitchen's 28×7 because we have room.
const PLATE_W: int = 38
const PLATE_H: int = 9

# Colors
const COLOR_BG: Color = Color("#1A1208")
const COLOR_TITLE: Color = Color("#F5EDDA")
const COLOR_HINT: Color = Color("#888888")
const COLOR_CELL_BG: Color = Color("#2A1A0A")
const COLOR_CELL_BORDER: Color = Color("#3A2A1A")
const COLOR_CELL_BORDER_UNLOCKED: Color = Color("#F2A227")
const COLOR_PLATE: Color = Color("#F5EDDA")
const COLOR_PLATE_RIM: Color = Color("#888888")
const COLOR_PLATE_SHADOW: Color = Color("#0E0804")
const COLOR_LOCK_SILHOUETTE: Color = Color("#3A2A1A")
const COLOR_LOCK_GLYPH: Color = Color("#5A4030")
const COLOR_DISH_NAME: Color = Color("#F5EDDA")
const COLOR_DISH_NAME_LOCKED: Color = Color("#5A4030")
const COLOR_COUNT: Color = Color("#F2A227")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	Game.current_area = "cookbook"
	_build_ui()
	set_process_unhandled_input(true)
	# v0.32: short page-flip on open so the menu transition has audio weight.
	Sfx.play_page_flip()


func _unhandled_input(event: InputEvent) -> void:
	# "interact" or any C/B key closes the cookbook → title.
	if event.is_action_pressed("interact"):
		Game.goto_level("title")
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Background fill
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	add_child(bg)

	# Title bar
	var title: Label = _make_label(
		"料理圖鑑　%d / %d" % [
			HiScore.unlocked_dish_count(), DishRenderer.ALL_DISHES.size()
		],
		12, COLOR_TITLE
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(VIEWPORT_W, 14)
	title.position = Vector2(0, 8)
	add_child(title)

	# Subtitle — total dishes cooked across all runs
	var total: int = _total_cooked()
	var sub: Label = _make_label(
		"總共做過 %d 道菜" % total, 8, COLOR_HINT
	)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(VIEWPORT_W, 10)
	sub.position = Vector2(0, 22)
	add_child(sub)

	# Grid of dish cells — last row centred so trailing 3 cells aren't hugging
	# the left edge.
	var dishes: Array[String] = DishRenderer.ALL_DISHES
	var grid_total_w: int = COLS * CELL_W + (COLS - 1) * GRID_GAP_X
	var grid_x0: int = (VIEWPORT_W - grid_total_w) / 2
	for i in dishes.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var cells_in_row: int = mini(COLS, dishes.size() - row * COLS)
		var row_w: int = cells_in_row * CELL_W + (cells_in_row - 1) * GRID_GAP_X
		var row_x0: int = (VIEWPORT_W - row_w) / 2 if row == ROWS - 1 else grid_x0
		var cx: int = row_x0 + col * (CELL_W + GRID_GAP_X)
		var cy: int = GRID_TOP + row * (CELL_H + GRID_GAP_Y)
		_build_cell(dishes[i], cx, cy)

	# Bottom hint
	var hint: Label = _make_label(
		"ESC / 空白鍵 返回標題", 8, COLOR_HINT
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(VIEWPORT_W, 10)
	hint.position = Vector2(0, VIEWPORT_H - 12)
	add_child(hint)


## Each cell is a custom-drawn Control: cookbook drawing is centralised in
## DishCell so we don't queue_redraw the whole cookbook every frame (these
## are static — only redraw on _ready).
func _build_cell(dish_name: String, x: int, y: int) -> void:
	var cell: DishCell = DishCell.new()
	cell.dish_name = dish_name
	cell.cooked_count = HiScore.cook_count(dish_name)
	cell.unlocked = cell.cooked_count > 0
	cell.position = Vector2(x, y)
	cell.size = Vector2(CELL_W, CELL_H)
	add_child(cell)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _total_cooked() -> int:
	var n: int = 0
	for k in HiScore.dishes_cooked.keys():
		n += int(HiScore.dishes_cooked[k])
	return n


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


# ---------------------------------------------------------------------------
# Inner cell node — one per dish.
# ---------------------------------------------------------------------------

class DishCell extends Control:
	var dish_name: String = ""
	var cooked_count: int = 0
	var unlocked: bool = false

	func _ready() -> void:
		queue_redraw()
		# Add the dish-name label below the plate
		var name_label: Label = Label.new()
		name_label.text = dish_name if unlocked else "？？？"
		name_label.add_theme_font_override("font",
			load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color",
			Cookbook.COLOR_DISH_NAME if unlocked else Cookbook.COLOR_DISH_NAME_LOCKED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(Cookbook.CELL_W, 12)
		name_label.position = Vector2(0, 28)
		add_child(name_label)
		# Cook count below name (only when unlocked)
		if unlocked:
			var count_label: Label = Label.new()
			count_label.text = "× %d" % cooked_count
			count_label.add_theme_font_override("font",
				load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile)
			count_label.add_theme_font_size_override("font_size", 8)
			count_label.add_theme_color_override("font_color", Cookbook.COLOR_COUNT)
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.size = Vector2(Cookbook.CELL_W, 10)
			count_label.position = Vector2(0, 42)
			add_child(count_label)

	func _draw() -> void:
		# Cell border + bg
		var border_color: Color = (
			Cookbook.COLOR_CELL_BORDER_UNLOCKED if unlocked
			else Cookbook.COLOR_CELL_BORDER
		)
		draw_rect(Rect2(0, 0, Cookbook.CELL_W, Cookbook.CELL_H), border_color)
		draw_rect(Rect2(1, 1, Cookbook.CELL_W - 2, Cookbook.CELL_H - 2),
			Cookbook.COLOR_CELL_BG)

		# Plate centered horizontally near the top of the cell
		var plate_w: int = Cookbook.PLATE_W
		var plate_h: int = Cookbook.PLATE_H
		var plate_x: int = (Cookbook.CELL_W - plate_w) / 2
		var plate_y: int = 6
		# Plate shadow + rim + cream surface
		draw_rect(Rect2(plate_x, plate_y + plate_h, plate_w, 1),
			Cookbook.COLOR_PLATE_SHADOW)
		draw_rect(Rect2(plate_x, plate_y, plate_w, plate_h),
			Cookbook.COLOR_PLATE_RIM)
		draw_rect(Rect2(plate_x + 1, plate_y + 1, plate_w - 2, plate_h - 2),
			Cookbook.COLOR_PLATE)

		if unlocked:
			# Render the actual dish art via shared DishRenderer.
			var dish_x: int = plate_x + 2
			var dish_y: int = plate_y + 1
			var dish_w: int = plate_w - 4
			var dish_h: int = plate_h - 2
			DishRenderer.draw_dish(self, dish_name,
				dish_x, dish_y, dish_w, dish_h)
		else:
			# Locked silhouette — single dark blob covering the plate area.
			var blob_x: int = plate_x + 6
			var blob_y: int = plate_y + 2
			var blob_w: int = plate_w - 12
			var blob_h: int = plate_h - 4
			draw_rect(Rect2(blob_x, blob_y, blob_w, blob_h),
				Cookbook.COLOR_LOCK_SILHOUETTE)
			# Lock glyph — 3×4 padlock body + shackle dots
			var lx: int = plate_x + plate_w / 2 - 1
			var ly: int = plate_y + 3
			draw_rect(Rect2(lx, ly, 3, 1), Cookbook.COLOR_LOCK_GLYPH)
			draw_rect(Rect2(lx, ly + 1, 1, 1), Cookbook.COLOR_LOCK_GLYPH)
			draw_rect(Rect2(lx + 2, ly + 1, 1, 1), Cookbook.COLOR_LOCK_GLYPH)
			draw_rect(Rect2(lx - 1, ly + 2, 5, 2), Cookbook.COLOR_LOCK_GLYPH)
