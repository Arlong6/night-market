## FPTouch — on-screen touch controls for mobile / web play: a left virtual joystick
## (drives the move actions), a right-side drag area (aims the camera), and action
## buttons. It presses/releases the SAME input actions the keyboard uses, so both car
## and foot modes work unchanged. Shown only on touch/web builds (or when forced).
class_name FPTouch
extends Control

const STICK_CENTER := Vector2(150.0, 402.0)
const STICK_RADIUS := 78.0
const STICK_DEAD := 0.28          ## fraction of radius before a direction registers
const LOOK_SENS := 0.006          ## radians of look per pixel dragged

var game = null

# Buttons: label, centre, radius, and the input action they hold down.
var _buttons: Array = [
	{"label": "射擊", "pos": Vector2(852.0, 438.0), "r": 52.0, "act": "fire"},
	{"label": "上下車", "pos": Vector2(852.0, 322.0), "r": 44.0, "act": "enter_exit"},
	{"label": "氮氣", "pos": Vector2(742.0, 462.0), "r": 40.0, "act": "nitro"},
	{"label": "跳/煞", "pos": Vector2(742.0, 356.0), "r": 40.0, "act": "handbrake"},
	{"label": "換槍", "pos": Vector2(646.0, 300.0), "r": 38.0, "act": "_weapon"},
]

var _move_idx: int = -1           ## finger controlling the joystick (or -1)
var _move_vec: Vector2 = Vector2.ZERO
var _look_idx: int = -1           ## finger dragging to aim (or -1)
# per-button: which finger index is holding it (-1 = none)
var _btn_idx: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(960.0, 540.0)
	_btn_idx.resize(_buttons.size())
	_btn_idx.fill(-1)
	set_process_input(true)

func _process(_delta: float) -> void:
	queue_redraw()

## Release every touch-held action — used when the app loses focus (backgrounded),
## which otherwise leaves fire/nitro/etc. stuck down with no release event coming.
func _release_all() -> void:
	for i in _buttons.size():
		if _btn_idx[i] != -1:
			_btn_idx[i] = -1
			_release_action(String(_buttons[i]["act"]))
	if _move_idx != -1:
		_move_idx = -1
		_move_vec = Vector2.ZERO
		_apply_move(Vector2.ZERO)
	_look_idx = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()

# ── Touch handling ───────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)

func _on_press(idx: int, pos: Vector2) -> void:
	# Safety: if this finger index is still bound (its release event was dropped by the
	# OS), release it first so actions can't get stuck held down.
	_on_release(idx)
	var p := _to_ui(pos)
	# Buttons first.
	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		if p.distance_to(b["pos"]) <= float(b["r"]):
			_btn_idx[i] = idx
			_press_action(String(b["act"]))
			return
	# Left half -> joystick; right half -> look.
	if p.x < 480.0:
		_move_idx = idx
		_update_stick(p)
	else:
		_look_idx = idx

func _on_release(idx: int) -> void:
	for i in _buttons.size():
		if _btn_idx[i] == idx:
			_btn_idx[i] = -1
			_release_action(String(_buttons[i]["act"]))
	if idx == _move_idx:
		_move_idx = -1
		_move_vec = Vector2.ZERO
		_apply_move(Vector2.ZERO)
	if idx == _look_idx:
		_look_idx = -1

func _on_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var p := _to_ui(pos)
	if idx == _move_idx:
		_update_stick(p)
	elif idx == _look_idx and game != null and game.has_method("touch_look"):
		# UI is 960x540; convert the raw pixel delta to UI space for a consistent feel.
		var scale: float = 960.0 / maxf(get_viewport_rect().size.x, 1.0)
		game.touch_look(rel * scale * LOOK_SENS)

func _update_stick(p: Vector2) -> void:
	var off: Vector2 = (p - STICK_CENTER).limit_length(STICK_RADIUS)
	_move_vec = off / STICK_RADIUS
	_apply_move(_move_vec)

## Map the joystick vector to the digital move actions (up=accel, down=brake, etc.).
func _apply_move(v: Vector2) -> void:
	_set_action("accel", v.y < -STICK_DEAD)
	_set_action("brake", v.y > STICK_DEAD)
	_set_action("right", v.x > STICK_DEAD)
	_set_action("left", v.x < -STICK_DEAD)

func _set_action(act: String, down: bool) -> void:
	if down and not Input.is_action_pressed(act):
		Input.action_press(act)
	elif not down and Input.is_action_pressed(act):
		Input.action_release(act)

func _press_action(act: String) -> void:
	if act == "_weapon":
		if game != null and game.has_method("cycle_weapon"):
			game.cycle_weapon()
		return
	Input.action_press(act)

func _release_action(act: String) -> void:
	if act == "_weapon":
		return
	Input.action_release(act)

func _to_ui(pos: Vector2) -> Vector2:
	# Convert a raw viewport pixel to the 960x540 design space the buttons live in.
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(pos.x / maxf(vp.x, 1.0) * 960.0, pos.y / maxf(vp.y, 1.0) * 540.0)

# ── Drawing ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Joystick base + knob.
	draw_circle(STICK_CENTER, STICK_RADIUS, Color(1, 1, 1, 0.10))
	draw_arc(STICK_CENTER, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	var knob: Vector2 = STICK_CENTER + _move_vec * STICK_RADIUS
	draw_circle(knob, 30.0, Color(1, 1, 1, 0.30))
	# Buttons.
	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		var held: bool = _btn_idx[i] != -1
		var col := Color(1.0, 0.82, 0.3, 0.5 if held else 0.28)
		draw_circle(b["pos"], float(b["r"]), col)
		draw_arc(b["pos"], float(b["r"]), 0.0, TAU, 28, Color(1, 1, 1, 0.4), 2.0)
		var lbl := String(b["label"])
		var fnt := ThemeDB.fallback_font
		var fs := 20
		var w := fnt.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(fnt, b["pos"] + Vector2(-w * 0.5, 7.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
