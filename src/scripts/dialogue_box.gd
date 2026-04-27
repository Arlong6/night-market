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

## Emitted with the selected option index when the player confirms a choice.
signal choice_confirmed(index: int)

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
## Last typewriter character index that played a blip — gates so we only
## fire SFX when a NEW char is revealed (not every frame).
var _last_blip_chars: int = 0
var _label: Label = null
var _options_label: Label = null  ## rendered below the question in choice mode
var _bg: ColorRect = null
var _border: ColorRect = null
var _active: bool = false

## Choice mode state.
var _choice_mode: bool = false
var _options: Array[String] = []
var _option_index: int = 0

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
	var new_chars: int = mini(int(_visible_chars_float), _current_line_length())
	# Fire a blip every 2 new chars so 30 cps → ~15 blips/sec (gentler).
	if new_chars > _last_blip_chars and (new_chars - _last_blip_chars) >= 2:
		Sfx.play_blip()
		_last_blip_chars = new_chars
	_label.visible_characters = new_chars
	# Reveal the options once the question typewriter completes.
	if _choice_mode and _typewriter_complete() and _options_label != null:
		_options_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _choice_mode:
		# In choice mode: arrows navigate options once typewriter is complete;
		# interact either snaps the typewriter or confirms the selection.
		if event.is_action_pressed("interact"):
			_advance()
			get_viewport().set_input_as_handled()
		elif _typewriter_complete():
			if event.is_action_pressed("ui_up"):
				var prev: int = _option_index
				_option_index = max(0, _option_index - 1)
				if _option_index != prev:
					Sfx.play_choice()
				_update_options_label()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				var prev: int = _option_index
				_option_index = min(_options.size() - 1, _option_index + 1)
				if _option_index != prev:
					Sfx.play_choice()
				_update_options_label()
				get_viewport().set_input_as_handled()
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
	_choice_mode = false
	if _options_label != null:
		_options_label.visible = false
	visible = true
	_show_current_line()


## Begins a choice prompt: typewriter the question, then accept arrow-key
## navigation through `options`. interact confirms the selected index.
func start_choice(question: String, options: Array[String]) -> void:
	_lines = [question]
	_line_index = 0
	_options = options
	_option_index = 0
	_choice_mode = true
	_active = true
	visible = true
	_show_current_line()
	_update_options_label()
	_options_label.visible = false  # reveal once typewriter complete


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
	_last_blip_chars = 0
	_label.text = _lines[_line_index] if _line_index < _lines.size() else ""
	_label.visible_characters = 0


func _advance() -> void:
	# If still typing, snap to fully-revealed first.
	if _label.visible_characters < _current_line_length():
		_label.visible_characters = _current_line_length()
		_visible_chars_float = float(_current_line_length())
		if _choice_mode:
			_options_label.visible = true
		return
	# In choice mode: confirm the current option.
	if _choice_mode:
		_confirm_choice()
		return
	# Already fully revealed — go to next line or finish.
	_line_index += 1
	if _line_index >= _lines.size():
		_close()
		return
	_show_current_line()


func _typewriter_complete() -> bool:
	return _label.visible_characters >= _current_line_length()


func _confirm_choice() -> void:
	var idx: int = _option_index
	_active = false
	visible = false
	_choice_mode = false
	_lines = []
	_options = []
	_option_index = 0
	choice_confirmed.emit(idx)


## Renders the option list with a "▶" cursor on the active option.
func _update_options_label() -> void:
	if _options_label == null:
		return
	var text := ""
	for i in _options.size():
		var prefix: String = "▶ " if i == _option_index else "  "
		text += prefix + _options[i]
		if i < _options.size() - 1:
			text += "\n"
	_options_label.text = text


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
	_label.size = Vector2(_bg.size.x - 2 * TEXT_PADDING, 16.0)  # one-line top
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

	# Options label — rendered below the question in choice mode.
	_options_label = Label.new()
	_options_label.add_theme_font_override("font", _make_cjk_font())
	_options_label.add_theme_font_size_override("font_size", 11)
	_options_label.add_theme_color_override("font_color", COLOR_TEXT)
	_options_label.position = _label.position + Vector2(0.0, 18.0)
	_options_label.size = Vector2(_bg.size.x - 2 * TEXT_PADDING, 28.0)
	_options_label.visible = false
	add_child(_options_label)


func _make_cjk_font() -> FontFile:
	return CjkFont.make()
