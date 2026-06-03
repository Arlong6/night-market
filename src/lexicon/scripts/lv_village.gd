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
var _smith: LVNPC = null
var _fisher: LVNPC = null
var _weaver: LVNPC = null
var _child: LVNPC = null
var _traveler: LVNPC = null
var _storyteller: LVNPC = null
var _elder: LVNPC = null
var _dialogue_display: LVDialogueDisplay = null

## Track which NPC vignettes have cascaded; elder ending unlocks once
## any vignette is done (MVP shortcut keeps baker-only gate).
var _baker_cascaded: bool = false
var _smith_cascaded: bool = false
var _fisher_cascaded: bool = false
var _weaver_cascaded: bool = false
var _child_cascaded: bool = false
var _traveler_cascaded: bool = false
var _storyteller_cascaded: bool = false

func _ready() -> void:
	_build_background()
	_build_npcs()
	_build_dialogue_display()
	_wire_signals()

func _build_background() -> void:
	# Layered parchment background: sky band (top) + ground (bottom)
	var sky := ColorRect.new()
	sky.color = Color(0.78, 0.72, 0.55, 1.0)
	sky.size = Vector2(320, 110)
	sky.position = Vector2(0, 0)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.62, 0.54, 0.38, 1.0)
	ground.size = Vector2(320, 70)
	ground.position = Vector2(0, 110)
	add_child(ground)
	# Sun/horizon line accent
	var horizon := ColorRect.new()
	horizon.color = Color(0.95, 0.82, 0.55, 0.6)
	horizon.size = Vector2(320, 2)
	horizon.position = Vector2(0, 110)
	add_child(horizon)
	# Distant village rooftops (stylized rectangles)
	for i in 5:
		var roof := ColorRect.new()
		roof.color = Color(0.45, 0.32, 0.22, 1.0)
		roof.size = Vector2(30, 14)
		roof.position = Vector2(15 + i * 60, 96)
		add_child(roof)
	# Title text in the scene corner
	var place_label := Label.new()
	place_label.text = "村莊"
	place_label.position = Vector2(8, 8)
	place_label.add_theme_font_size_override("font_size", 10)
	place_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1, 0.7))
	add_child(place_label)
	# Hint text bottom
	var hint := Label.new()
	hint.text = "點 NPC 對話 · N 開筆記本"
	hint.position = Vector2(80, 168)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1, 0.55))
	add_child(hint)

func _build_npcs() -> void:
	# Baker at world position (120, 100) per LVVignetteContent
	_baker = LVNPC.new()
	_baker.npc_id = &"BAKER"
	_baker.body_color = Color(0.85, 0.55, 0.3, 1.0)  # apron-ochre
	_baker.skin_color = Color(0.95, 0.8, 0.65, 1.0)
	_baker.held_item_text = "麵包"
	_baker.position = LVVignetteContent.BAKER_WORLD_POSITION
	add_child(_baker)
	# Smith at world position (50, 110) — far left
	_smith = LVNPC.new()
	_smith.npc_id = &"SMITH"
	_smith.body_color = Color(0.35, 0.25, 0.2, 1.0)  # soot-leather
	_smith.skin_color = Color(0.85, 0.65, 0.5, 1.0)  # darker tan
	_smith.held_item_text = "鐵"
	_smith.position = LVVignetteContent.SMITH_WORLD_POSITION
	add_child(_smith)
	# Fisher at world position (250, 110) — far right
	_fisher = LVNPC.new()
	_fisher.npc_id = &"FISHER"
	_fisher.body_color = Color(0.3, 0.45, 0.55, 1.0)  # sea-blue coat
	_fisher.skin_color = Color(0.92, 0.78, 0.6, 1.0)
	_fisher.held_item_text = "魚"
	_fisher.position = LVVignetteContent.FISHER_WORLD_POSITION
	add_child(_fisher)
	# Weaver at (180, 100) — right of baker
	_weaver = LVNPC.new()
	_weaver.npc_id = &"WEAVER"
	_weaver.body_color = Color(0.55, 0.4, 0.55, 1.0)  # muted violet
	_weaver.skin_color = Color(0.93, 0.78, 0.65, 1.0)
	_weaver.held_item_text = "布"
	_weaver.position = LVVignetteContent.WEAVER_WORLD_POSITION
	add_child(_weaver)
	# Child at (95, 135) — bottom-left
	_child = LVNPC.new()
	_child.npc_id = &"CHILD"
	_child.body_color = Color(0.75, 0.65, 0.4, 1.0)  # straw yellow
	_child.skin_color = Color(0.95, 0.82, 0.7, 1.0)
	_child.held_item_text = "朋友"
	_child.position = LVVignetteContent.CHILD_WORLD_POSITION
	add_child(_child)
	# Traveler at (270, 70) — top-right
	_traveler = LVNPC.new()
	_traveler.npc_id = &"TRAVELER"
	_traveler.body_color = Color(0.4, 0.3, 0.2, 1.0)  # dusty traveler-brown
	_traveler.skin_color = Color(0.85, 0.7, 0.55, 1.0)
	_traveler.held_item_text = "杖"
	_traveler.position = LVVignetteContent.TRAVELER_WORLD_POSITION
	add_child(_traveler)
	# Storyteller at (40, 75) — top-left
	_storyteller = LVNPC.new()
	_storyteller.npc_id = &"STORYTELLER"
	_storyteller.body_color = Color(0.55, 0.35, 0.3, 1.0)  # rust-red shawl
	_storyteller.skin_color = Color(0.9, 0.75, 0.6, 1.0)
	_storyteller.held_item_text = "書"
	_storyteller.position = LVVignetteContent.STORYTELLER_WORLD_POSITION
	add_child(_storyteller)
	# Elder at village top-center (160, 60) — raised above horizon so distinct
	_elder = LVNPC.new()
	_elder.npc_id = &"ELDER"
	_elder.body_color = Color(0.45, 0.32, 0.5, 1.0)  # plum robe
	_elder.skin_color = Color(0.9, 0.78, 0.65, 1.0)
	_elder.tableau_duration = 0.01  # elder has no real tableau
	_elder.position = Vector2(160, 60)
	add_child(_elder)

func _build_dialogue_display() -> void:
	_dialogue_display = LVDialogueDisplay.new()
	_dialogue_display.name = "DialogueDisplay"
	_dialogue_display.add_to_group(&"lv_dialogue_display")
	_dialogue_display.position = Vector2(20, 140)
	_dialogue_display.size = Vector2(280, 35)
	# Background for visibility (dialogue display owns its own TokenBox)
	var dbg := ColorRect.new()
	dbg.name = "DBG"
	dbg.color = Color(1.0, 0.95, 0.85, 0.9)
	dbg.anchor_right = 1.0
	dbg.anchor_bottom = 1.0
	_dialogue_display.add_child(dbg)
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
	# Route confirm to whichever NPC has an active dialogue state machine.
	if _dialogue_display == null:
		return
	if _dialogue_display.get_state() != _dialogue_display.DialogueState.SHOWING:
		return
	if not _dialogue_display.is_typewriter_complete():
		_dialogue_display.advance()
		return
	_dialogue_display.advance()
	# Phase 2: advance the active NPC's state machine
	var active: LVNPC = _active_npc()
	if active and active.get_state_machine():
		active.get_state_machine().on_advance_pressed()

func _on_cancel() -> void:
	if _dialogue_display and _dialogue_display.get_state() == _dialogue_display.DialogueState.SHOWING:
		_dialogue_display.hide_dialogue()
		var active: LVNPC = _active_npc()
		if active:
			active.cancel_dialogue()

## Find the NPC whose state machine is currently engaged in dialogue.
## Returns null if none.
func _active_npc() -> LVNPC:
	for npc in [_baker, _smith, _fisher, _weaver, _child, _traveler, _storyteller]:
		if npc == null:
			continue
		var sm = npc.get_state_machine()
		if sm and sm.has_method("is_in_dialogue") and sm.is_in_dialogue():
			return npc
	return null

func _on_elder_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# MVP shortcut: if baker is cascaded, clicking elder ends the game
			var ss = get_node_or_null("/root/LVSessionState")
			if ss and ss.is_vignette_cascaded(&"BAKER"):
				ss.transition_to_ending()

func _on_vignette_completed(v: StringName) -> void:
	match v:
		&"BAKER": _baker_cascaded = true
		&"SMITH": _smith_cascaded = true
		&"FISHER": _fisher_cascaded = true
		&"WEAVER": _weaver_cascaded = true
		&"CHILD": _child_cascaded = true
		&"TRAVELER": _traveler_cascaded = true
		&"STORYTELLER": _storyteller_cascaded = true

## All three vignettes cascaded → elder click triggers ending.
## MVP fallback: baker-only suffices (so MVP play loop still works).
func _ending_unlocked() -> bool:
	return _baker_cascaded
