## WantedSystem — accumulates heat from destruction into a 0..5 star level.
class_name WantedSystem
extends RefCounted

var _heat: float = 0.0

func add_heat(n: int) -> void:
	_heat += float(n)

func decay(dt: float) -> void:
	_heat = maxf(0.0, _heat - RRTuning.HEAT_DECAY_PER_SEC * dt)

func heat() -> float:
	return _heat

func stars() -> int:
	var s: int = 0
	for i in RRTuning.STAR_THRESHOLDS.size():
		if _heat >= float(RRTuning.STAR_THRESHOLDS[i]):
			s = i
	return s
