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
var _click_area: Area2D = null
var _label_above: Label = null  # NPC name above head
var _drawer: Node2D = null  # custom drawer child

## Optional held item shown during ACTION state (e.g. "麵包" for baker)
@export var held_item_text: String = ""
var _item_visible: bool = false

func _ready() -> void:
	_build_visuals()
	_build_click_area()
	_build_tableau_timer()
	_wire_state_machine()

func _build_visuals() -> void:
	# Custom-drawn body — use a child Node2D with _draw override
	_drawer = preload("res://lexicon/scripts/lv_npc_drawer.gd").new()
	_drawer.npc = self
	add_child(_drawer)
	# Name label above head
	_label_above = Label.new()
	_label_above.text = _readable_name()
	_label_above.position = Vector2(-20, -NPC_H * 0.5 - 14)
	_label_above.add_theme_font_size_override("font_size", 8)
	_label_above.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75, 1.0))
	_label_above.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 1.0))
	_label_above.add_theme_constant_override("outline_size", 2)
	_label_above.size = Vector2(40, 12)
	_label_above.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label_above)

func _readable_name() -> String:
	match npc_id:
		&"BAKER": return "麵包師"
		&"BLACKSMITH": return "鐵匠"
		&"FISHER": return "漁夫"
		&"WEAVER": return "織女"
		&"CHILD": return "小孩"
		&"TRAVELER": return "旅人"
		&"STORYTELLER": return "說書婆婆"
		&"ELDER": return "村莊長老"
		_: return String(npc_id)

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(NPC_W + 4, NPC_H + 4)
	collider.shape = shape
	_click_area.add_child(collider)
	_click_area.input_event.connect(_on_area_input)
	add_child(_click_area)

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
	# Show held item briefly during tableau
	if held_item_text != "":
		_item_visible = true
		if _drawer:
			_drawer.queue_redraw()
	# Body bounces slightly
	if _drawer:
		var tween := create_tween()
		tween.tween_property(_drawer, "position", Vector2(0, -2), 0.15)
		tween.tween_property(_drawer, "position", Vector2(0, 0), 0.15)
		tween.tween_interval(0.4)
		tween.tween_property(_drawer, "position", Vector2(0, -2), 0.15)
		tween.tween_property(_drawer, "position", Vector2(0, 0), 0.15)
	_tableau_timer.start(tableau_duration)

func _on_tableau_timeout() -> void:
	_item_visible = false
	if _drawer:
		_drawer.queue_redraw()
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
