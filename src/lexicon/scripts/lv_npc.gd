## LVNPC — Lexicon Village #7 NPC sprite & tableau
##
## Per-NPC node: placeholder ColorRect sprite + clickable Area2D + tableau timer.
## Drives LVVignetteStateMachine via signal callbacks. Real sprite art deferred.
##
## See: design/gdd/npc-sprite-tableau.md
class_name LVNPC
extends Node2D

const LVVignetteStateMachine = preload("res://lexicon/scripts/lv_vignette_state_machine.gd")
const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

## NPC's vignette identifier (matches keystone §3 §4 names: BAKER, ELDER, etc.)
@export var npc_id: StringName = &"BAKER"

## Placeholder sprite color (per NPC for visual distinction).
@export var placeholder_color: Color = Color(0.7, 0.5, 0.3, 1.0)

## Tableau duration (per #7 GDD: ~3s for baker).
@export var tableau_duration: float = 3.0

## NPC sprite size in base pixels (per art bible TBD: 16×24).
const NPC_SIZE: Vector2 = Vector2(16, 24)

var _state_machine: LVVignetteStateMachine = null
var _tableau_timer: Timer = null
var _sprite_rect: ColorRect = null
var _click_area: Area2D = null

func _ready() -> void:
	_build_sprite()
	_build_click_area()
	_build_tableau_timer()
	_wire_state_machine()

func _build_sprite() -> void:
	_sprite_rect = ColorRect.new()
	_sprite_rect.name = "Sprite"
	_sprite_rect.color = placeholder_color
	_sprite_rect.size = NPC_SIZE
	_sprite_rect.position = -NPC_SIZE * 0.5  # center on origin
	add_child(_sprite_rect)

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = NPC_SIZE + Vector2(4, 4)  # 2px padding
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
			# Route via LVInput so it respects state gating
			var inp = get_node_or_null("/root/LVInput")
			if inp:
				inp.request_npc_interaction(npc_id)
			# Also forward directly to state machine
			_state_machine.on_npc_clicked()

func _on_show_line_requested(tokens: Array) -> void:
	# Find the dialogue display in the scene tree and call show_line
	var dd = _find_dialogue_display()
	if dd:
		dd.show_line(tokens)

func _on_hide_dialogue_requested() -> void:
	var dd = _find_dialogue_display()
	if dd:
		dd.hide_dialogue()

func _on_play_tableau_requested() -> void:
	# Placeholder: flash the sprite + start the timer
	if _sprite_rect:
		var tween := create_tween()
		tween.tween_property(_sprite_rect, "color", placeholder_color * 1.5, 0.2)
		tween.tween_property(_sprite_rect, "color", placeholder_color, 0.2)
	_tableau_timer.start(tableau_duration)

func _on_tableau_timeout() -> void:
	if _state_machine:
		_state_machine.on_tableau_complete()

func _find_dialogue_display() -> Node:
	# Look upward through tree for LVDialogueDisplay
	var node: Node = self
	while node:
		var dd = node.get_node_or_null("DialogueDisplay")
		if dd:
			return dd
		node = node.get_parent()
	# Fallback: search whole tree
	return get_tree().get_first_node_in_group(&"lv_dialogue_display")

## Forward advance() to state machine (called by Title/Game scene on confirm input).
func advance_dialogue() -> void:
	if _state_machine:
		_state_machine.on_advance_pressed()

## Forward cancel to state machine.
func cancel_dialogue() -> void:
	if _state_machine:
		_state_machine.on_dialogue_cancelled()

func get_state_machine() -> LVVignetteStateMachine:
	return _state_machine
