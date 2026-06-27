## Vehicle — top-down arcade car for 橫衝直撞. Heavy momentum + steering.
class_name Vehicle
extends CharacterBody2D

signal died

var hp: float = RRTuning.VEHICLE_HP
const MASS: float = RRTuning.VEHICLE_MASS

var _w: float = 22.0
var _h: float = 12.0

func _ready() -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_w * 2.0, _h * 2.0)
	col.shape = rect
	add_child(col)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func speed() -> float:
	return velocity.length()

func _physics_process(delta: float) -> void:
	var throttle: float = Input.get_axis("brake", "accel")
	var steer: float = Input.get_axis("left", "right")
	# Steering scales with how fast you're going (no pivot-in-place).
	var speed_frac: float = clampf(speed() / RRTuning.MAX_SPEED, 0.0, 1.0)
	rotation += steer * RRTuning.TURN_RATE * delta * (0.35 + 0.65 * speed_frac)
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	if throttle > 0.0:
		velocity += forward * RRTuning.ACCEL * delta
	elif throttle < 0.0:
		velocity -= forward * RRTuning.ACCEL * delta
	# Passive friction
	var fr: float = RRTuning.FRICTION * delta
	if velocity.length() <= fr:
		velocity = Vector2.ZERO
	else:
		velocity -= velocity.normalized() * fr
	velocity = velocity.limit_length(RRTuning.MAX_SPEED)
	move_and_slide()

func bleed_speed(factor: float) -> void:
	velocity *= factor

func take_damage(d: float) -> void:
	hp = maxf(0.0, hp - d)
	if hp <= 0.0:
		died.emit()

func _draw() -> void:
	# Body
	draw_rect(Rect2(-_w, -_h, _w * 2.0, _h * 2.0), Color("#D24B2A"))
	# Windshield (front = +x)
	draw_rect(Rect2(_w * 0.2, -_h * 0.7, _w * 0.5, _h * 1.4), Color("#2A2E38"))
	# Nose marker
	draw_rect(Rect2(_w - 3.0, -2.0, 3.0, 4.0), Color("#FFE08A"))
