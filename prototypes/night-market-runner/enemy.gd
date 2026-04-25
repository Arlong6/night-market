# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is simple horizontal patrol + instant-kill hit enough challenge to test dodge feel?
# Date: 2026-04-22

class_name Enemy extends Node2D

signal player_hit

const PATROL_SPEED := 45.0
const PATROL_RANGE := 60.0

var origin_x: float
var direction: int = 1


func _ready() -> void:
	origin_x = position.x

	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 24)
	cs.shape = shape
	area.add_child(cs)
	add_child(area)

	var visual := ColorRect.new()
	# Body uses a neutral tone; hazard tint only on edge per art-bible Section 4A
	visual.color = Color("#7A3A2A")
	visual.size = Vector2(40, 24)
	visual.position = Vector2(-20, -12)
	add_child(visual)

	# Hazard tint edge — tells player "this ends your run"
	var edge_top := ColorRect.new()
	edge_top.color = Color("#D94F2B")
	edge_top.size = Vector2(42, 2)
	edge_top.position = Vector2(-21, -14)
	add_child(edge_top)

	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	position.x += PATROL_SPEED * direction * delta
	if position.x > origin_x + PATROL_RANGE:
		direction = -1
		position.x = origin_x + PATROL_RANGE
	elif position.x < origin_x - PATROL_RANGE:
		direction = 1
		position.x = origin_x - PATROL_RANGE


func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_hit.emit()
