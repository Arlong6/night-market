## LVVillage — Lexicon Village #6 Village scene & layout
##
## Programmatic Node2D scene scaffold. Places the baker NPC + Elder.
## Real village background art deferred to art bible.
##
## See: design/gdd/village-scene-layout.md
class_name LVVillage
extends Node2D

const LVNPC = preload("res://lexicon/scripts/lv_npc.gd")
const LVDialogueDisplay = preload("res://lexicon/scripts/lv_dialogue_display.gd")
const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

var _baker: LVNPC = null
var _elder: LVNPC = null
var _dialogue_display: LVDialogueDisplay = null

## Track baker cascade so we can enable elder click for MVP "ending trigger".
var _baker_cascaded: bool = false

func _ready() -> void:
	_build_background()
	_build_npcs()
	_build_dialogue_display()
	_wire_signals()

func _build_background() -> void:
	# Parchment background placeholder
	var bg := ColorRect.new()
	bg.color = Color(0.82, 0.74, 0.58, 1.0)
	bg.size = Vector2(320, 180)
	bg.position = Vector2(0, 0)
	add_child(bg)

func _build_npcs() -> void:
	# Baker at world position (120, 100) per LVVignetteContent
	_baker = LVNPC.new()
	_baker.npc_id = &"BAKER"
	_baker.placeholder_color = Color(0.9, 0.6, 0.3, 1.0)  # bread-orange
	_baker.position = LVVignetteContent.BAKER_WORLD_POSITION
	add_child(_baker)
	# Elder at village center (160, 90)
	_elder = LVNPC.new()
	_elder.npc_id = &"ELDER"
	_elder.placeholder_color = Color(0.5, 0.5, 0.7, 1.0)  # elder-purple
	_elder.tableau_duration = 0.01  # elder has no real tableau
	_elder.position = Vector2(160, 90)
	add_child(_elder)

func _build_dialogue_display() -> void:
	_dialogue_display = LVDialogueDisplay.new()
	_dialogue_display.name = "DialogueDisplay"
	_dialogue_display.add_to_group(&"lv_dialogue_display")
	_dialogue_display.position = Vector2(20, 140)
	_dialogue_display.size = Vector2(280, 35)
	# Custom-sized label inside dialogue display
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0, 1.0))
	# Background for visibility
	var dbg := ColorRect.new()
	dbg.name = "DBG"
	dbg.color = Color(1.0, 0.95, 0.85, 0.9)
	dbg.anchor_right = 1.0
	dbg.anchor_bottom = 1.0
	_dialogue_display.add_child(dbg)
	_dialogue_display.add_child(lbl)
	add_child(_dialogue_display)
	# Wire dialogue advance to LVInput.confirm_pressed
	var inp = get_node_or_null("/root/LVInput")
	if inp:
		if not inp.confirm_pressed.is_connected(_on_confirm):
			inp.confirm_pressed.connect(_on_confirm)
		if not inp.cancel_pressed.is_connected(_on_cancel):
			inp.cancel_pressed.connect(_on_cancel)

func _wire_signals() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss and not ss.vignette_completed.is_connected(_on_vignette_completed):
		ss.vignette_completed.connect(_on_vignette_completed)
	# Wire elder click to trigger ending when baker is cascaded (MVP shortcut)
	if _elder and _elder.get_state_machine():
		# In MVP we don't add real elder vignette; click triggers ending if baker done
		var area: Area2D = _elder.get_node_or_null("ClickArea")
		if area:
			area.input_event.connect(_on_elder_input)

func _on_confirm() -> void:
	# Route confirm to whichever NPC is in active dialogue (whose state machine is showing)
	# For MVP, route to baker if baker is in a dialogue state
	if _baker and _baker.get_state_machine():
		var sm = _baker.get_state_machine()
		# Forward advance if dialogue is showing
		if _dialogue_display and _dialogue_display.get_state() == _dialogue_display.DialogueState.SHOWING:
			# Phase 1: skip typewriter; Phase 2: advance state machine
			if not _dialogue_display.is_typewriter_complete():
				_dialogue_display.advance()
			else:
				_dialogue_display.advance()
				sm.on_advance_pressed()

func _on_cancel() -> void:
	if _baker and _dialogue_display and _dialogue_display.get_state() == _dialogue_display.DialogueState.SHOWING:
		_dialogue_display.hide_dialogue()
		_baker.cancel_dialogue()

func _on_elder_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# MVP shortcut: if baker is cascaded, clicking elder ends the game
			var ss = get_node_or_null("/root/LVSessionState")
			if ss and ss.is_vignette_cascaded(&"BAKER"):
				ss.transition_to_ending()

func _on_vignette_completed(v: StringName) -> void:
	if v == &"BAKER":
		_baker_cascaded = true
