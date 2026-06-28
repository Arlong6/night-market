## ComboSystem — chains destructions within a time window into a multiplier.
class_name ComboSystem
extends RefCounted

var _count: int = 0
var _timer: float = 0.0

func register(value: int) -> int:
	_count += 1
	_timer = RRTuning.COMBO_WINDOW
	return value * multiplier()

func multiplier() -> int:
	return clampi(_count, 1, RRTuning.COMBO_MAX_MULT)

func count() -> int:
	return _count

func is_active() -> bool:
	return _count > 0 and _timer > 0.0

func tick(dt: float) -> void:
	if _count == 0:
		return
	_timer -= dt
	if _timer <= 0.0:
		_count = 0
		_timer = 0.0
