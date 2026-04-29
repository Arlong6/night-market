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
var _time_label: Label = null
var _checklist_label: Label = null

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 10
	_build_ui()
	# Initial render from current Inventory state.
	_refresh_money()
	_refresh_progress()
	_refresh_time()
	_refresh_checklist()
	# Subscribe so future changes auto-update.
	if not Inventory.money_changed.is_connected(_on_money_changed):
		Inventory.money_changed.connect(_on_money_changed)
	if not Inventory.ingredient_added.is_connected(_on_ingredient_added):
		Inventory.ingredient_added.connect(_on_ingredient_added)


func _process(_delta: float) -> void:
	# Time updates every frame from Game.session_time (driven by Game._process).
	_refresh_time()


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

	# Time label — top centre, slightly faded so money + progress dominate.
	_time_label = Label.new()
	_time_label.add_theme_font_override("font", _make_cjk_font())
	_time_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_time_label.add_theme_color_override("font_color", Color("#888888"))
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.size = Vector2(60.0, 16.0)
	_time_label.position = Vector2((VIEWPORT_W - 60.0) / 2.0, MARGIN)
	add_child(_time_label)

	# v0.13 checklist label — sits under the N/5 progress in the top-right
	# and shows ✓/○ for each of mum's randomly-required ingredients.
	_checklist_label = Label.new()
	_checklist_label.add_theme_font_override("font", _make_cjk_font())
	_checklist_label.add_theme_font_size_override("font_size", 8)
	_checklist_label.add_theme_color_override("font_color", Color("#F5EDDA"))
	_checklist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_checklist_label.size = Vector2(110.0, 12.0)
	_checklist_label.position = Vector2(VIEWPORT_W - MARGIN - 110.0, MARGIN + 12.0)
	add_child(_checklist_label)


func _make_cjk_font() -> FontFile:
	var f: FontFile = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


# ---------------------------------------------------------------------------
# Update handlers
# ---------------------------------------------------------------------------

func _on_money_changed(_new_money: int) -> void:
	_refresh_money()


func _on_ingredient_added(_id: String) -> void:
	_refresh_progress()
	_refresh_checklist()


func _refresh_money() -> void:
	_money_label.text = "$%d" % Inventory.money


func _refresh_progress() -> void:
	# v0.13: progress counts ONLY the random required-list, not arbitrary
	# extras the player might also buy for the perfect-run achievement.
	_progress_label.text = "%d/%d" % [
		Inventory.required_owned_count(),
		Inventory.REQUIRED_COUNT
	]


## v0.13: rebuilds "✓蔥 ○蛋 ○菜 ○雞 ○醬"-style checklist from the run's
## random required-list. Checked items use a brighter green to read clearly.
func _refresh_checklist() -> void:
	if _checklist_label == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for id in Inventory.required_ingredients:
		var mark: String = "✓" if Inventory.has(id) else "○"
		parts.append("%s%s" % [mark, Inventory.display_abbrev(id)])
	_checklist_label.text = " ".join(parts)


func _refresh_time() -> void:
	if _time_label == null:
		return
	var t: float = Game.session_time
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	_time_label.text = "%d:%02d" % [minutes, seconds]
