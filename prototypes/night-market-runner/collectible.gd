# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does float+bob + color pop feel juicy enough, or does pickup need more?
# Date: 2026-04-22

class_name Collectible extends Area2D

signal picked_up

var base_y: float
var bob_timer: float = 0.0


func _ready() -> void:
	base_y = position.y

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 24)
	cs.shape = shape
	add_child(cs)

	var visual := ColorRect.new()
	visual.color = Color("#F2A227")  # lantern-amber collectible glow
	visual.size = Vector2(20, 24)
	visual.position = Vector2(-10, -12)
	add_child(visual)

	# Spike on top (container cue per art-bible Section 3B)
	var spike := ColorRect.new()
	spike.color = Color("#2A1A0A")
	spike.size = Vector2(2, 4)
	spike.position = Vector2(-1, -16)
	add_child(spike)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# 2-frame bob per art-bible Section 3B
	bob_timer += delta
	var up := int(bob_timer * 4.0) % 2 == 0
	position.y = base_y + (-2.0 if up else 0.0)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		picked_up.emit()
		queue_free()
