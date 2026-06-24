## LVNPC — Lexicon Village #7 NPC sprite & tableau
##
## Per-NPC node: drawn character silhouette (head + body) + clickable Area2D
## + tableau timer. Drives LVVignetteStateMachine via signals.
##
## See: design/gdd/npc-sprite-tableau.md
class_name LVNPC
extends Node2D

const LVVignetteStateMachine = preload("res://lexicon/scripts/lv_vignette_state_machine.gd")
const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
const LVSfx = preload("res://lexicon/scripts/lv_sfx.gd")

## NPC's vignette identifier (matches keystone §3 §4 names: BAKER, ELDER, etc.)
@export var npc_id: StringName = &"BAKER"

## Body/clothing color (per NPC for visual distinction).
@export var body_color: Color = Color(0.65, 0.35, 0.22, 1.0)

## Skin color (default warm parchment-friendly tone).
@export var skin_color: Color = Color(0.92, 0.78, 0.62, 1.0)

## Tableau duration (per #7 GDD: ~3s for baker).
@export var tableau_duration: float = 3.0

## NPC sprite size in base pixels.
const NPC_W: float = 16.0
const NPC_H: float = 28.0

var _state_machine: LVVignetteStateMachine = null
var _tableau_timer: Timer = null
var _click_area: Area2D = null  # legacy; kept for tests
var _click_button: Control = null  # primary click target for Web reliability
var _label_above: Label = null  # NPC name above head
var _drawer: Node2D = null  # custom drawer child
var _hint_bubble: Label = null  # Chinese hint shown during tableau

## Distinctive held item shown beside each NPC at all times (visual identity).
@export var held_item_text: String = ""
var _item_visible: bool = true  # always show — gives each NPC a permanent visual identity

func _ready() -> void:
	_build_visuals()
	_build_click_area()
	_build_click_button()
	_build_tableau_timer()
	_wire_state_machine()

func _build_visuals() -> void:
	# Custom-drawn body — use a child Node2D with _draw override
	_drawer = preload("res://lexicon/scripts/lv_npc_drawer.gd").new()
	_drawer.npc = self
	add_child(_drawer)
	# Name label above head — IGNORE so clicks on the label fall through to Area2D
	_label_above = Label.new()
	_label_above.text = _readable_name()
	_label_above.position = Vector2(-20, -NPC_H * 0.5 - 14)
	_label_above.add_theme_font_size_override("font_size", 8)
	_label_above.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75, 1.0))
	_label_above.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 1.0))
	_label_above.add_theme_constant_override("outline_size", 2)
	_label_above.size = Vector2(40, 12)
	_label_above.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_above.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label_above)
	# Hint bubble: Chinese text shown above head during tableau (teaches meaning).
	_hint_bubble = Label.new()
	_hint_bubble.text = ""
	_hint_bubble.position = Vector2(-24, -NPC_H * 0.5 - 30)
	_hint_bubble.size = Vector2(48, 14)
	_hint_bubble.add_theme_font_size_override("font_size", 10)
	_hint_bubble.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0, 1.0))
	_hint_bubble.add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.75, 0.95))
	_hint_bubble.add_theme_constant_override("outline_size", 3)
	_hint_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bubble.visible = false
	add_child(_hint_bubble)

func _readable_name() -> String:
	match npc_id:
		&"BAKER": return "麵包師"
		&"SMITH", &"BLACKSMITH": return "鐵匠"
		&"FISHER": return "漁夫"
		&"WEAVER": return "織女"
		&"CHILD": return "小孩"
		&"TRAVELER": return "旅人"
		&"STORYTELLER": return "說書婆婆"
		&"ELDER": return "村莊長老"
		_: return String(npc_id)

func _build_click_area() -> void:
	# Legacy Area2D — kept so integration tests that simulate input_event still pass.
	# Real Web click goes through _click_button (Control) below.
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	_click_area.input_pickable = true
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 50)
	collider.position = Vector2(0, -7)
	collider.shape = shape
	_click_area.add_child(collider)
	_click_area.input_event.connect(_on_area_input)
	add_child(_click_area)

## Build the Control-based click target — Web-reliable, doesn't depend on Area2D
## physics picking which can be flaky under canvas_items stretch mode.
func _build_click_button() -> void:
	_click_button = Control.new()
	_click_button.name = "ClickButton"
	# Cover body + label area. Centered around the NPC origin like the Area2D was.
	_click_button.position = Vector2(-22, -NPC_H * 0.5 - 18)
	_click_button.size = Vector2(44, NPC_H + 22)
	_click_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_button.gui_input.connect(_on_button_gui_input)
	add_child(_click_button)

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			LVSfx.click(self)
			var inp = get_node_or_null("/root/LVInput")
			if inp:
				inp.request_npc_interaction(npc_id)
			_state_machine.on_npc_clicked()
			_click_button.accept_event()

func _build_tableau_timer() -> void:
	_tableau_timer = Timer.new()
	_tableau_timer.one_shot = true
	_tableau_timer.timeout.connect(_on_tableau_timeout)
	add_child(_tableau_timer)

func _wire_state_machine() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	_state_machine = LVVignetteStateMachine.new(
		npc_id, ss, LVVignetteContent.get_content
	)
	_state_machine.show_line_requested.connect(_on_show_line_requested)
	_state_machine.hide_dialogue_requested.connect(_on_hide_dialogue_requested)
	_state_machine.play_tableau_requested.connect(_on_play_tableau_requested)
	_state_machine.state_changed.connect(_on_state_changed)
	# Burst sparkles when this NPC's vignette cascades
	if ss and ss.has_signal("vignette_completed"):
		if not ss.vignette_completed.is_connected(_on_session_vignette_completed):
			ss.vignette_completed.connect(_on_session_vignette_completed)

func _on_session_vignette_completed(vignette_id: StringName) -> void:
	if vignette_id != npc_id:
		return
	_burst_sparkles()

func _burst_sparkles() -> void:
	# Spawn a brief particle burst above the NPC for the "aha" moment.
	var p := CPUParticles2D.new()
	p.amount = 28
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.85
	p.spread = 70.0
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.8
	p.scale_amount_max = 2.8
	p.scale_amount_curve = _spark_size_curve()
	p.color = Color(1.0, 0.9, 0.45, 1.0)
	p.color_ramp = _spark_color_ramp()
	p.direction = Vector2(0, -1)
	p.position = Vector2(0, -NPC_H * 0.4)
	p.emitting = true
	add_child(p)
	# Cleanup after lifetime
	var t := get_tree().create_timer(p.lifetime + 0.2)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func _spark_size_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.5, 0.7))
	c.add_point(Vector2(1.0, 0.0))
	return c

func _spark_color_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 0.7, 1.0))
	g.set_color(1, Color(1.0, 0.55, 0.2, 0.0))
	return g

## Show the Chinese hint bubble whenever this NPC is actively in dialogue
## (intro/action/closing/complete_pending), hide it otherwise. Gives the player
## a constant clue about what this NPC's vignette is about.
func _on_state_changed(new_state: int) -> void:
	if _hint_bubble == null:
		return
	const ACTIVE_STATES: Array = [1, 2, 3, 4]  # INTRO, ACTION, CLOSING, COMPLETE_PENDING
	if new_state in ACTIVE_STATES and held_item_text != "":
		_hint_bubble.text = held_item_text
		_hint_bubble.visible = true
	else:
		_hint_bubble.visible = false

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var inp = get_node_or_null("/root/LVInput")
			if inp:
				inp.request_npc_interaction(npc_id)
			_state_machine.on_npc_clicked()

func _on_show_line_requested(tokens: Array) -> void:
	var dd = _find_dialogue_display()
	if dd:
		dd.show_line(tokens)

func _on_hide_dialogue_requested() -> void:
	var dd = _find_dialogue_display()
	if dd:
		dd.hide_dialogue()

func _on_play_tableau_requested() -> void:
	# Held item is permanently visible (set in declaration). Tableau animates body
	# + reinforces the Chinese hint bubble.
	if _hint_bubble and held_item_text != "":
		_hint_bubble.text = held_item_text
		_hint_bubble.visible = true
	# Body bounces — 4 hops + held-out gesture in middle for clarity
	if _drawer:
		var tween := create_tween()
		tween.tween_property(_drawer, "position", Vector2(0, -3), 0.2)
		tween.tween_property(_drawer, "position", Vector2(0, 0), 0.2)
		tween.tween_property(_drawer, "position", Vector2(2, -1), 0.4)  # extends item forward
		tween.tween_property(_drawer, "position", Vector2(0, 0), 0.4)
		tween.tween_property(_drawer, "position", Vector2(0, -3), 0.2)
		tween.tween_property(_drawer, "position", Vector2(0, 0), 0.2)
	_tableau_timer.start(tableau_duration)

func _on_tableau_timeout() -> void:
	# Held item stays visible permanently; only tableau bouncing ends.
	if _state_machine:
		_state_machine.on_tableau_complete()

func _find_dialogue_display() -> Node:
	return get_tree().get_first_node_in_group(&"lv_dialogue_display") if get_tree() else null

func advance_dialogue() -> void:
	if _state_machine:
		_state_machine.on_advance_pressed()

func cancel_dialogue() -> void:
	if _state_machine:
		_state_machine.on_dialogue_cancelled()

func get_state_machine() -> LVVignetteStateMachine:
	return _state_machine

func is_item_visible() -> bool:
	return _item_visible
