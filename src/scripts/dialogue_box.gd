## CanvasLayer dialogue UI with typewriter effect (R-004).
##
## Owned by the Dialogue autoload. Renders a cream-coloured panel at the
## bottom of the viewport with one line of CJK text being typed out at
## CHARS_PER_SECOND. Pressing `interact` skips the typewriter to the line
## end, or advances to the next line if already complete.
class_name DialogueBox
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the player has advanced past the final line.
signal finished

# ---------------------------------------------------------------------------
# Constants — tuning
# ---------------------------------------------------------------------------

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const BOX_MARGIN: int = 8       ## px from viewport edge
const BOX_HEIGHT: int = 50      ## px tall
const TEXT_PADDING: int = 6     ## px inside the box

const CHARS_PER_SECOND: float = 30.0

const COLOR_BG: Color = Color("#F5EDDA")     ## warm cream
const COLOR_BORDER: Color = Color("#2A1A0A") ## ink black
const COLOR_TEXT: Color = Color("#2A1A0A")   ## ink black

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _lines: Array[String] = []
var _line_index: int = 0
var _visible_chars_float: float = 0.0
var _label: Label = null
var _bg: ColorRect = null
var _border: ColorRect = null
var _active: bool = false

# ---------------------------------------------------------------------------
# Built-in
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 15
	_build_ui()
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	# Advance typewriter timer.
	_visible_chars_float += CHARS_PER_SECOND * delta
	_label.visible_characters = mini(int(_visible_chars_float), _current_line_length())


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API (called by Dialogue autoload)
# ---------------------------------------------------------------------------

## Begins showing the given lines from index 0.
func start_dialogue(lines: Array[String]) -> void:
	_lines = lines
	_line_index = 0
	_active = true
	visible = true
	_show_current_line()


## Test helper: returns how many characters of the current line are revealed.
func current_visible_chars() -> int:
	return _label.visible_characters if _label != null else 0


## Test helper: returns the current line index.
func current_line_index() -> int:
	return _line_index


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _show_current_line() -> void:
	_visible_chars_float = 0.0
	_label.text = _lines[_line_index] if _line_index < _lines.size() else ""
	_label.visible_characters = 0


func _advance() -> void:
	# If still typing, snap to fully-revealed first.
	if _label.visible_characters < _current_line_length():
		_label.visible_characters = _current_line_length()
		_visible_chars_float = float(_current_line_length())
		return
	# Already fully revealed — go to next line or finish.
	_line_index += 1
	if _line_index >= _lines.size():
		_close()
		return
	_show_current_line()


func _close() -> void:
	_active = false
	visible = false
	_lines = []
	_line_index = 0
	finished.emit()


func _current_line_length() -> int:
	if _line_index >= _lines.size():
		return 0
	return _lines[_line_index].length()


func _build_ui() -> void:
	# Background + border via two stacked ColorRects (cheap, pixel-crisp).
	_border = ColorRect.new()
	_border.color = COLOR_BORDER
	_border.size = Vector2(VIEWPORT_W - 2 * BOX_MARGIN, BOX_HEIGHT)
	_border.position = Vector2(
		BOX_MARGIN,
		VIEWPORT_H - BOX_MARGIN - BOX_HEIGHT
	)
	add_child(_border)

	_bg = ColorRect.new()
	_bg.color = COLOR_BG
	_bg.size = Vector2(_border.size.x - 2.0, _border.size.y - 2.0)
	_bg.position = _border.position + Vector2(1.0, 1.0)
	add_child(_bg)

	_label = Label.new()
	_label.add_theme_font_override("font", _make_cjk_font())
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.position = _bg.position + Vector2(TEXT_PADDING, TEXT_PADDING)
	_label.size = _bg.size - Vector2(2 * TEXT_PADDING, 2 * TEXT_PADDING)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f
