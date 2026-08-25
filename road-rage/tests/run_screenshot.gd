## Renders fp_main for a moment then saves a screenshot so we can SEE what the
## game actually draws. Run NON-headless (it needs a real GPU):
##   godot --path road-rage -s res://tests/run_screenshot.gd -- <out.png> [frames]
extends SceneTree

var _m
var _f: int = 0
var _shot: String = "/tmp/roadrage_shot.png"
var _wait: int = 90

func _initialize() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() > 0:
		_shot = argv[0]
	if argv.size() > 1:
		_wait = int(argv[1])
	_m = load("res://scenes/fp_main.tscn").instantiate()
	root.add_child(_m)

func _process(_delta: float) -> bool:
	_f += 1
	if _f < _wait:
		return false
	var img := root.get_texture().get_image()
	if img != null:
		var err := img.save_png(_shot)
		print("SHOT saved=%s err=%d size=%dx%d" % [_shot, err, img.get_width(), img.get_height()])
	else:
		print("SHOT image was null")
	return true
