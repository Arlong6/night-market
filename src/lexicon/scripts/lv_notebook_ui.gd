## LVNotebookUI — Lexicon Village #16 Notebook UI
##
## Player workspace: parchment overlay with palette + per-vignette page + counter.
## Hosts LVSymbolBinding gesture logic. Programmatic scaffold; art-bible polish deferred.
##
## See: design/gdd/notebook-ui.md
class_name LVNotebookUI
extends Control

const LVSymbolBinding = preload("res://lexicon/scripts/lv_symbol_binding.gd")
const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
const LVSfx = preload("res://lexicon/scripts/lv_sfx.gd")

## Palette grid columns (per layout constants).
const PALETTE_COLS: int = 7
const PALETTE_ROWS: int = 4
const SLOT_SIZE: Vector2 = Vector2(28, 32)
const ICON_SIZE: Vector2 = Vector2(12, 12)

## All meaning-icon IDs available in the palette — only real ones (no placeholders).
const ALL_ICONS: Array = [
	&"icon_bread", &"icon_give", &"icon_warm",
	&"icon_iron", &"icon_hammer", &"icon_make",
	&"icon_water", &"icon_fish", &"icon_come",
	&"icon_cloth", &"icon_weave", &"icon_long",
	&"icon_small", &"icon_play", &"icon_friend",
	&"icon_path", &"icon_far", &"icon_stranger",
	&"icon_remember", &"icon_place",
]

var _binding: LVSymbolBinding = null
var _session_state: Object = null
var _input: Object = null
var _active_vignette: StringName = &"BAKER"

var _palette_buttons: Dictionary = {}  # icon_id → Button
var _slot_buttons: Dictionary = {}     # slot_id → Button
var _counter_label: Label = null

func _ready() -> void:
	_session_state = get_node_or_null("/root/LVSessionState")
	_input = get_node_or_null("/root/LVInput")
	_binding = LVSymbolBinding.new(_session_state)
	_build_layout()
	_wire_input()
	visible = false  # opens via LVInput notebook_toggle

func _build_layout() -> void:
	# Background parchment panel
	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.78, 0.65, 0.95)  # parchment
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	# Vignette page panel (top half)
	_build_vignette_page()
	# Palette grid (bottom half)
	_build_palette_grid()
	# Counter label (top left)
	_counter_label = Label.new()
	_counter_label.text = "0/0 待解"
	_counter_label.position = Vector2(8, 4)
	_counter_label.add_theme_font_size_override("font_size", 8)
	add_child(_counter_label)
	# How-to hint label (centered top)
	var howto := Label.new()
	howto.text = "點下方圖示再點上方外語字 → 對 = 綠 / 錯 = 紅"
	howto.position = Vector2(0, 4)
	howto.size = Vector2(320, 10)
	howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	howto.add_theme_font_size_override("font_size", 7)
	howto.add_theme_color_override("font_color", Color(0.35, 0.22, 0.08, 0.85))
	add_child(howto)
	# Close button (top right corner)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(302, 0)
	close_btn.size = Vector2(16, 14)
	close_btn.add_theme_font_size_override("font_size", 8)
	close_btn.pressed.connect(_on_close_pressed)
	add_child(close_btn)

func _build_vignette_page() -> void:
	# Slots row at the top, tighter spacing
	var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE.get(_active_vignette, [])
	var n: int = slots.size()
	var spacing: float = 8.0
	var total_width: float = n * SLOT_SIZE.x + (n - 1) * spacing
	var start_x: float = (320.0 - total_width) * 0.5
	var y: float = 22.0
	for i in n:
		var slot_id: StringName = slots[i]
		var btn := Button.new()
		btn.text = LVVignetteContent.SEED_GLYPHS.get(slot_id, "?")
		btn.position = Vector2(start_x + i * (SLOT_SIZE.x + spacing), y)
		btn.size = SLOT_SIZE
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_slot_pressed.bind(slot_id))
		add_child(btn)
		_slot_buttons[slot_id] = btn

func _build_palette_grid() -> void:
	var cell_w: float = 18.0
	var cell_h: float = 14.0
	var gap_x: float = 2.0
	var gap_y: float = 2.0
	var total_w: float = PALETTE_COLS * cell_w + (PALETTE_COLS - 1) * gap_x
	var start_x: float = (320.0 - total_w) * 0.5
	var start_y: float = 78.0
	for i in min(ALL_ICONS.size(), PALETTE_COLS * PALETTE_ROWS):
		var icon_id: StringName = ALL_ICONS[i]
		var col: int = i % PALETTE_COLS
		var row: int = i / PALETTE_COLS
		var btn := Button.new()
		btn.text = LVVignetteContent.RESOLVED_STRINGS.get(_icon_to_slot_guess(icon_id), str(icon_id).substr(5, 4))
		btn.position = Vector2(start_x + col * (cell_w + gap_x), start_y + row * (cell_h + gap_y))
		btn.size = Vector2(cell_w, cell_h)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_palette_pressed.bind(icon_id))
		add_child(btn)
		_palette_buttons[icon_id] = btn

## Approximate icon → slot mapping for UI labels (MVP: 1:1 correspondence for baker).
func _icon_to_slot_guess(icon_id: StringName) -> StringName:
	var s := String(icon_id)
	if s.begins_with("icon_"):
		s = s.substr(5)
	# Search CORRECT_TABLE for value matching
	for k in LVVignetteContent.CORRECT_TABLE.keys():
		if LVVignetteContent.CORRECT_TABLE[k] == icon_id:
			return k
	return &""

func _wire_input() -> void:
	if _input:
		if not _input.notebook_toggle_requested.is_connected(_on_toggle):
			_input.notebook_toggle_requested.connect(_on_toggle)
		if not _input.notebook_close_requested.is_connected(_on_close_pressed):
			_input.notebook_close_requested.connect(_on_close_pressed)
	# Listen for cascade to update visual + counter
	if _session_state:
		if not _session_state.vignette_completed.is_connected(_on_vignette_completed):
			_session_state.vignette_completed.connect(_on_vignette_completed)

func _on_toggle() -> void:
	if visible:
		_on_close_pressed()
	else:
		_open()

func _open() -> void:
	visible = true
	if _input:
		_input.set_state(_input.InputState.NOTEBOOK_OPEN)
	_refresh_counter()
	_refresh_slot_visuals()

func _on_close_pressed() -> void:
	if _binding.is_carrying():
		_binding.cancel_carry()
	visible = false
	if _input and _input.get_state() == _input.InputState.NOTEBOOK_OPEN:
		_input.set_state(_input.InputState.NORMAL)

func _on_palette_pressed(icon_id: StringName) -> void:
	if _binding.is_carrying() and _binding.get_carried_icon() == icon_id:
		# Click on carried = deselect
		_binding.cancel_carry()
	else:
		_binding.pick_up_from_palette(icon_id)
	_refresh_slot_visuals()
	_refresh_counter()

func _on_slot_pressed(slot_id: StringName) -> void:
	if _binding.is_carrying():
		_binding.place_on_slot(slot_id)
		# Audio feedback: bright ding if correct, soft blip if wrong.
		var binding = _session_state.get_binding(slot_id) if _session_state else null
		var correct = LVVignetteContent.CORRECT_TABLE.get(slot_id, null)
		if binding != null and binding == correct:
			LVSfx.match_correct(self)
		else:
			LVSfx.match_wrong(self)
	else:
		_binding.pick_up_from_slot(slot_id)
		LVSfx.click(self)
	_refresh_slot_visuals()
	_refresh_counter()

func _refresh_counter() -> void:
	if _session_state and _counter_label:
		var unresolved: int = _session_state.unresolved_count(_active_vignette)
		var total: int = LVVignetteContent.SLOTS_IN_VIGNETTE.get(_active_vignette, []).size()
		_counter_label.text = "%d/%d 待解" % [unresolved, total]

func _refresh_slot_visuals() -> void:
	if _session_state == null:
		return
	for slot_id in _slot_buttons.keys():
		var btn: Button = _slot_buttons[slot_id]
		var binding = _session_state.get_binding(slot_id)
		var glyph: String = LVVignetteContent.SEED_GLYPHS.get(slot_id, "?")
		var correct_icon: Variant = LVVignetteContent.CORRECT_TABLE.get(slot_id, null)
		if _session_state.is_confirmed(slot_id):
			# Confirmed: resolved Chinese, locked, gold tint
			btn.text = LVVignetteContent.RESOLVED_STRINGS.get(slot_id, glyph)
			btn.disabled = true
			btn.modulate = Color(1.0, 0.9, 0.55, 1.0)
		elif binding != null:
			# Show placed icon's Chinese meaning + foreign glyph below.
			var placed_meaning: String = LVVignetteContent.RESOLVED_STRINGS.get(
				_icon_to_slot_guess(binding), str(binding).substr(5, 4))
			btn.text = "%s\n%s" % [placed_meaning, glyph]
			btn.disabled = false
			# Color feedback: green if matches correct, red if wrong
			if binding == correct_icon:
				btn.modulate = Color(0.65, 1.0, 0.55, 1.0)  # match — bright green
			else:
				btn.modulate = Color(1.0, 0.55, 0.5, 1.0)  # wrong — soft red
		else:
			# Empty — show glyph + default tint
			btn.text = glyph
			btn.disabled = false
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_vignette_completed(_v: StringName) -> void:
	_refresh_slot_visuals()
	_refresh_counter()
