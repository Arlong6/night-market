## Destructible — a world object that breaks when the car hits it hard enough.
class_name Destructible
extends Area2D

signal destroyed(kind: String, value: int, heat: int, pos: Vector2)

@export var kind: String = "prop"
var broke: bool = false

const _THRESHOLD := {
	"prop": RRTuning.BREAK_THRESHOLD_PROP,
	"car": RRTuning.BREAK_THRESHOLD_CAR,
	"ped": RRTuning.BREAK_THRESHOLD_PED,
}
const _SCORE := {"prop": RRTuning.SCORE_PROP, "car": RRTuning.SCORE_CAR, "ped": RRTuning.SCORE_PED}
const _HEAT := {"prop": RRTuning.HEAT_PROP, "car": RRTuning.HEAT_CAR, "ped": RRTuning.HEAT_PED}
const _COLOR := {"prop": Color("#C8A24A"), "car": Color("#4A7AC8"), "ped": Color("#E0B0A0")}
const _SIZE := {"prop": 14.0, "car": 20.0, "ped": 8.0}

func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _SIZE.get(kind, 14.0)
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if broke or not body is Vehicle:
		return
	var v: Vehicle = body
	var force: float = RRPhysics.impact_force(v.speed(), Vehicle.MASS)
	if RRPhysics.breaks_at(force, _THRESHOLD.get(kind, 9999.0)):
		_break(v)

func _break(v: Vehicle) -> void:
	broke = true
	var c: Color = _COLOR.get(kind, Color.WHITE)
	FX.burst(get_parent(), global_position, c, 14 if kind != "car" else 24)
	FX.debris(get_parent(), global_position, c, 5 if kind != "car" else 9)
	if kind == "car":
		RRAudio.explosion(get_parent())
	else:
		RRAudio.impact(get_parent(), 800.0)
	v.bleed_speed(RRTuning.SPEED_BLEED_ON_BREAK if kind != "car" else 0.55)
	destroyed.emit(kind, _SCORE.get(kind, 10), _HEAT.get(kind, 8), global_position)
	queue_free()

func _draw() -> void:
	var s: float = _SIZE.get(kind, 14.0)
	draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), _COLOR.get(kind, Color.WHITE))
