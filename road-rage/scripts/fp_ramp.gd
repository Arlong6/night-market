## FPRamp — a stunt ramp. A tilted slab the car rides up, with a launch trigger at
## the crest that kicks a fast car into the air (scaled by speed). Its own facing is
## irrelevant to the launch — any fast car crossing the crest gets thrown upward and
## keeps its horizontal momentum, so it arcs and (satisfyingly) crashes down.
class_name FPRamp
extends StaticBody3D

const LENGTH: float = 11.0
const WIDTH: float = 8.0
const ANGLE_DEG: float = 22.0
const LAUNCH_MIN: float = 8.0
const LAUNCH_SCALE: float = 0.7    ## upward kick per unit of car speed
const LAUNCH_MAX: float = 26.0
const RETRIGGER_CD: float = 1.2    ## ignore re-entries for this long (no launch stacking)

var _cd: float = 0.0

func _ready() -> void:
	var ang: float = deg_to_rad(ANGLE_DEG)
	var center_y: float = (LENGTH * 0.5) * sin(ang)
	# Tilted slab is VISUAL ONLY — no blocking collision, because the CharacterBody car
	# can't reliably climb a slope; the launch trigger below does the work instead, so a
	# fast car hitting the ramp gets flung up and over it (reads as a stunt jump).
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH, 0.5, LENGTH)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#E0A02A")
	mat.metallic = 0.2
	mat.roughness = 0.7
	bm.material = mat
	mi.mesh = bm
	mi.rotation.x = ang
	mi.position = Vector3(0.0, center_y, 0.0)
	add_child(mi)
	# Hazard stripe near the crest so it reads as a jump.
	var stripe := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(WIDTH, 0.54, 1.2)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("#1A1A1E")
	sbm.material = smat
	stripe.mesh = sbm
	stripe.rotation.x = ang
	stripe.position = Vector3(0.0, LENGTH * 0.42 * sin(ang), -LENGTH * 0.42 * cos(ang))
	add_child(stripe)
	# Launch trigger covering the ramp footprint at ground level — a fast car driving
	# into it gets kicked up and keeps its horizontal momentum, arcing over the ramp.
	var area := Area3D.new()
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(WIDTH + 1.0, 4.5, LENGTH)
	acol.shape = abox
	area.add_child(acol)
	area.position = Vector3(0.0, 2.0, 0.0)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)

func _on_body_entered(body: Node) -> void:
	if _cd > 0.0:
		return   # still cooling down from the last launch — don't re-fling
	if body is FPCar:
		var sp: float = body.speed()
		if sp > 4.0:
			body.launch(clampf(sp * LAUNCH_SCALE + LAUNCH_MIN, LAUNCH_MIN, LAUNCH_MAX))
			_cd = RETRIGGER_CD
