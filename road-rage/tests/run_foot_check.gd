## One-off headless check: does the on-foot enter/exit logic switch modes?
## Run: godot --headless -s res://tests/run_foot_check.gd
extends SceneTree

var _m
var _done: bool = false

func _initialize() -> void:
	_m = load("res://scenes/fp_main.tscn").instantiate()
	root.add_child(_m)   # fires _ready -> spawns the car

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var car_ok: bool = (_m._mode == "car") and (_m._car != null)
	_m._exit_car()
	var foot_ok: bool = (_m._mode == "foot") and (_m._walker != null) and (not _m._car.active)
	_m._enter_car()
	var back_ok: bool = (_m._mode == "car") and (_m._car.active)
	print("FOOT_CHECK start_car=%s exit_to_foot=%s enter_back=%s" % [car_ok, foot_ok, back_ok])
	return true
