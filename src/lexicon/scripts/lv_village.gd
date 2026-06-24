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

## Tutorial overlay tracked so it can be dismissed by ANY action.
var _tutorial: Control = null

func _ready() -> void:
	_build_background()
	_build_npcs()
	_build_dialogue_display()
	_build_tutorial_overlay()
	_wire_signals()

func _build_background() -> void:
	# Layered parchment background: sky + ground. Named so we can warm them as the
	# player solves more vignettes (atmosphere shift).
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.78, 0.72, 0.55, 1.0)
	sky.size = Vector2(320, 110)
	sky.position = Vector2(0, 0)
	add_child(sky)
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = Color(0.62, 0.54, 0.38, 1.0)
	ground.size = Vector2(320, 70)
	ground.position = Vector2(0, 110)
	add_child(ground)
	# Sun/horizon line accent
	var horizon := ColorRect.new()
	horizon.name = "Horizon"
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
	# Soft warm glow at horizon that intensifies as you solve more NPCs
	var glow := ColorRect.new()
	glow.name = "ProgressGlow"
	glow.color = Color(1.0, 0.85, 0.5, 0.0)
	glow.size = Vector2(320, 30)
	glow.position = Vector2(0, 95)
	add_child(glow)
	# Title text in the scene corner
	var place_label := Label.new()
	place_label.text = "村莊"
	place_label.position = Vector2(8, 8)
	place_label.add_theme_font_size_override("font_size", 10)
	place_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1, 0.7))
	add_child(place_label)
	# Hint text bottom
	var hint := Label.new()
	hint.text = "點 NPC 看他在做什麼  ·  N 開筆記本拼字"
	hint.position = Vector2(40, 168)
	hint.size = Vector2(240, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1, 0.65))
	add_child(hint)
	# Progress badge top-right: "X/Y 解開"
	var progress := Label.new()
	progress.name = "ProgressBadge"
	progress.text = "0/%d 解開" % LVVignetteContent.SLOTS_IN_VIGNETTE.size()
	progress.position = Vector2(245, 8)
	progress.size = Vector2(70, 10)
	progress.add_theme_font_size_override("font_size", 9)
	progress.add_theme_color_override("font_color", Color(0.35, 0.22, 0.08, 0.9))
	add_to_group(&"village_progress_label")
	add_child(progress)

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
	# Wire tap-to-advance: clicking the dialogue panel triggers the same flow as Enter.
	if not _dialogue_display.tap_received.is_connected(_on_confirm):
		_dialogue_display.tap_received.connect(_on_confirm)
	# Pulsing "點繼續" hint that appears only when typewriter is complete
	# (= line is ready to advance). Hides during typewriter to avoid noise.
	var hint := Label.new()
	hint.name = "TapHint"
	hint.text = "點繼續"
	hint.position = Vector2(232, 20)
	hint.size = Vector2(46, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.32, 0.12, 1.0))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	_dialogue_display.add_child(hint)
	# Pulse loop (continuous; only visible when typewriter is complete)
	var pulse_tween := create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(hint, "modulate:a", 0.4, 0.6)
	pulse_tween.tween_property(hint, "modulate:a", 1.0, 0.6)
	# Wire visibility to typewriter state
	if not _dialogue_display.line_completed.is_connected(_show_tap_hint):
		_dialogue_display.line_completed.connect(_show_tap_hint)
	if not _dialogue_display.line_shown.is_connected(_hide_tap_hint_on_new_line):
		_dialogue_display.line_shown.connect(_hide_tap_hint_on_new_line)
	if not _dialogue_display.dialogue_hidden.is_connected(_hide_tap_hint):
		_dialogue_display.dialogue_hidden.connect(_hide_tap_hint)
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
		var area: Area2D = _elder.get_node_or_null("ClickArea")
		if area and not area.input_event.is_connected(_on_elder_input):
			area.input_event.connect(_on_elder_input)
	# Dismiss tutorial on any meaningful input
	var inp = get_node_or_null("/root/LVInput")
	if inp:
		if inp.has_signal("notebook_toggle_requested") and not inp.notebook_toggle_requested.is_connected(_dismiss_tutorial):
			inp.notebook_toggle_requested.connect(_dismiss_tutorial)
		if inp.has_signal("npc_interaction_requested") and not inp.npc_interaction_requested.is_connected(_on_any_npc_clicked):
			inp.npc_interaction_requested.connect(_on_any_npc_clicked)

func _on_any_npc_clicked(_npc_id: StringName) -> void:
	_dismiss_tutorial()

func _show_tap_hint() -> void:
	var hint = _dialogue_display.get_node_or_null("TapHint") if _dialogue_display else null
	if hint:
		hint.visible = true

func _hide_tap_hint() -> void:
	var hint = _dialogue_display.get_node_or_null("TapHint") if _dialogue_display else null
	if hint:
		hint.visible = false

func _hide_tap_hint_on_new_line(_tokens: Array) -> void:
	_hide_tap_hint()

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
	_refresh_progress_badge()

## First-time tutorial overlay — explains the game loop. Dismissed on any click.
func _build_tutorial_overlay() -> void:
	var overlay := Control.new()
	overlay.name = "Tutorial"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200  # above notebook (100) so it's always on top
	add_child(overlay)
	_tutorial = overlay
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	# Title
	var title := Label.new()
	title.text = "歡迎來到 字典村莊"
	title.size = Vector2(320, 18)
	title.position = Vector2(0, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)
	# Body text
	var body := Label.new()
	body.text = "這裡的人說一種你不懂的語言\n\n1. 點 NPC → 看他的動作 + 中文提示\n2. 按 N 開筆記本 → 把對的圖示放到外語字上\n3. 三個槽都正確 → 字會變成中文\n\n目標：解開全部 7 個 NPC 的話\n最後村莊長老會問你一個問題"
	body.size = Vector2(280, 100)
	body.position = Vector2(20, 50)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(body)
	# Dismiss hint
	var dismiss := Label.new()
	dismiss.text = "點任意處開始"
	dismiss.size = Vector2(320, 12)
	dismiss.position = Vector2(0, 158)
	dismiss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismiss.add_theme_font_size_override("font_size", 9)
	dismiss.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 0.95))
	dismiss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dismiss)
	# Dismiss on any click
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_tutorial()
	)

func _dismiss_tutorial() -> void:
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null

func _refresh_progress_badge() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss == null:
		return
	var done: int = 0
	for vid in LVVignetteContent.SLOTS_IN_VIGNETTE.keys():
		if ss.is_vignette_cascaded(vid):
			done += 1
	var total: int = LVVignetteContent.SLOTS_IN_VIGNETTE.size()
	var label: Label = get_node_or_null("ProgressBadge")
	if label:
		label.text = "%d/%d 解開" % [done, total]
	# Atmosphere shift: sky warms + horizon glow brightens with each cascade.
	var t: float = float(done) / float(max(1, total))
	var sky: ColorRect = get_node_or_null("Sky") as ColorRect
	if sky:
		var sky_start := Color(0.78, 0.72, 0.55, 1.0)
		var sky_end := Color(0.95, 0.78, 0.45, 1.0)  # warmer dusk
		sky.color = sky_start.lerp(sky_end, t)
	var ground: ColorRect = get_node_or_null("Ground") as ColorRect
	if ground:
		var g_start := Color(0.62, 0.54, 0.38, 1.0)
		var g_end := Color(0.55, 0.42, 0.28, 1.0)
		ground.color = g_start.lerp(g_end, t)
	var glow: ColorRect = get_node_or_null("ProgressGlow") as ColorRect
	if glow:
		glow.color = Color(1.0, 0.85, 0.5, 0.6 * t)

## All three vignettes cascaded → elder click triggers ending.
## MVP fallback: baker-only suffices (so MVP play loop still works).
func _ending_unlocked() -> bool:
	return _baker_cascaded
