# PROTOTYPE - NOT FOR PRODUCTION
# Question: What jump height / gravity / run speed feels right at 320x180?
# Date: 2026-04-22

class_name Player extends CharacterBody2D

signal died

# Tunable feel — the point of the prototype is to find what works
# Starting values — expect to tweak these by ±30% during playtest
const MOVE_SPEED := 110.0        # px/sec
const JUMP_VELOCITY := -230.0    # px/sec (negative = up)
const GRAVITY := 800.0           # px/sec^2
const JUMP_CUT_MULT := 0.5       # release jump early → cut upward velocity
const COYOTE_TIME := 0.10        # sec — jump just after walking off edge
const JUMP_BUFFER := 0.10        # sec — press jump just before landing

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 40)
	cs.shape = shape
	add_child(cs)

	var visual := ColorRect.new()
	visual.color = Color("#E8F542")  # player accent (art-bible Section 4A)
	visual.size = Vector2(24, 40)
	visual.position = Vector2(-12, -20)
	add_child(visual)

	# Boba straw spike (so silhouette reads per art-bible Section 3A)
	var straw := ColorRect.new()
	straw.color = Color("#2A1A0A")
	straw.size = Vector2(2, 6)
	straw.position = Vector2(6, -24)
	add_child(straw)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME

	# Horizontal
	var input_dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = input_dir * MOVE_SPEED

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0

	# Jump-cut — releasing jump while rising shortens arc (platformer feel)
	if velocity.y < 0 and not (Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")):
		velocity.y *= JUMP_CUT_MULT

	move_and_slide()

	# Fell off world
	if position.y > 240:
		died.emit()
