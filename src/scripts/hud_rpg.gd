## In-game HUD for Night Market Shopping (R-007).
##
## Shows current money (top-left) and ingredient progress N/5 (top-right).
## Subscribes to Inventory signals so it updates without polling.
##
## Layer 10 — above world geometry, below the dialogue box (which is layer 15).
class_name HudRpg
extends CanvasLayer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const MARGIN: int = 4

const COLOR_TEXT: Color = Color("#C2241A")  ## stamp red, same as v0.1 HUD
const FONT_SIZE: int = 10

# ---------------------------------------------------------------------------
# Refs
# ---------------------------------------------------------------------------

var _money_label: Label = null
var _progress_label: Label = null

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 10
	_build_ui()
	# Initial render from current Inventory state.
	_refresh_money()
	_refresh_progress()
	# Subscribe so future changes auto-update.
	if not Inventory.money_changed.is_connected(_on_money_changed):
		Inventory.money_changed.connect(_on_money_changed)
	if not Inventory.ingredient_added.is_connected(_on_ingredient_added):
		Inventory.ingredient_added.connect(_on_ingredient_added)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_money_label = Label.new()
	_money_label.add_theme_font_override("font", _make_cjk_font())
	_money_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_money_label.add_theme_color_override("font_color", COLOR_TEXT)
	_money_label.position = Vector2(MARGIN, MARGIN)
	add_child(_money_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_override("font", _make_cjk_font())
	_progress_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_progress_label.add_theme_color_override("font_color", COLOR_TEXT)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.size = Vector2(60.0, 16.0)
	_progress_label.position = Vector2(VIEWPORT_W - MARGIN - 60.0, MARGIN)
	add_child(_progress_label)


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f


# ---------------------------------------------------------------------------
# Update handlers
# ---------------------------------------------------------------------------

func _on_money_changed(_new_money: int) -> void:
	_refresh_money()


func _on_ingredient_added(_id: String) -> void:
	_refresh_progress()


func _refresh_money() -> void:
	_money_label.text = "$%d" % Inventory.money


func _refresh_progress() -> void:
	_progress_label.text = "%d/%d" % [
		Inventory.ingredient_count(),
		Inventory.REQUIRED_INGREDIENTS.size()
	]
