## Police — chases and rams the player. Count/aggression scale with wanted stars.
class_name Police
extends CharacterBody2D

var target: Vehicle = null
var _dmg_cooldown: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 22)
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	_dmg_cooldown = maxf(0.0, _dmg_cooldown - delta)
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	rotation = dir.angle()
	velocity = dir * RRTuning.POLICE_SPEED
	move_and_slide()
	if global_position.distance_to(target.global_position) < 30.0 and _dmg_cooldown <= 0.0:
		target.take_damage(RRTuning.POLICE_RAM_DAMAGE)
		_dmg_cooldown = 0.6

func _draw() -> void:
	draw_rect(Rect2(-20, -11, 40, 22), Color("#2A50C0"))
	draw_rect(Rect2(-6, -11, 12, 4), Color("#E03030"))  # light bar
