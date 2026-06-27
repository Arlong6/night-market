## CameraRig — follows a target with trauma-based shake + zoom punch.
class_name CameraRig
extends Camera2D

var _target: Node2D = null
var _trauma: float = 0.0
var _base_zoom: Vector2 = Vector2.ONE
var _zoom_kick: float = 0.0

func setup(target: Node2D) -> void:
	_target = target
	if target and is_instance_valid(target):
		global_position = target.global_position
	make_current()

func shake(strength: float) -> void:
	_trauma = minf(1.0, _trauma + strength)

func punch(amount: float) -> void:
	_zoom_kick = maxf(_zoom_kick, amount)

func _process(delta: float) -> void:
	if _target and is_instance_valid(_target):
		global_position = global_position.lerp(_target.global_position, 1.0 - pow(0.001, delta))
	_trauma = maxf(0.0, _trauma - delta * 1.5)
	var amt: float = _trauma * _trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 12.0 * amt
	_zoom_kick = maxf(0.0, _zoom_kick - delta * 4.0)
	zoom = _base_zoom * (1.0 + _zoom_kick)
