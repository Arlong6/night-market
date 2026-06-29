## FPCockpit — first-person car INTERIOR built from primitive meshes (no art assets).
## Added as a CHILD of FPCar (car space). The FP camera sits at car-space
## (0, 1.5, -0.2) looking down -Z, so every interior piece lives at NEGATIVE z
## (in front of the camera) and is kept within ~2 units of it so normal depth
## sorting handles it against the far world. Visual only — no colliders.
##
## FPCar calls set_steer(amount) each frame to spin the wheel with the input.
class_name FPCockpit
extends Node3D

## Max wheel rotation (radians) at full steer input (amount = ±1).
const STEER_MAX_RAD: float = 0.6
## How quickly the displayed wheel angle chases the target (per-second lerp rate).
const STEER_RESPONSE: float = 10.0

# Interior palette — dark plastics plus a couple of accent colors.
const C_PLASTIC: Color = Color("#1B1C22")        # dashboard / pillars / mirror body
const C_PLASTIC_DARK: Color = Color("#101116")   # wheel hub, deep shadow trim
const C_TRIM: Color = Color("#2A2C36")            # roof header, lighter plastic
const C_ACCENT: Color = Color("#C84A2A")          # stitched-trim accent (matches car body)
const C_GAUGE_A: Color = Color("#37E0B0")         # glowing gauge dot (teal)
const C_GAUGE_B: Color = Color("#FFB020")         # glowing gauge dot (amber)
const C_MIRROR: Color = Color("#9FB6C8")          # reflective mirror glass

var _wheel: Node3D = null
var _steer_target: float = 0.0
var _steer_current: float = 0.0

func _ready() -> void:
	_build_dashboard()
	_build_steering_wheel()
	_build_pillars_and_roof()
	_build_mirror()

func _process(delta: float) -> void:
	# Smoothly chase the target steer angle so the wheel feels weighted.
	var t: float = clampf(STEER_RESPONSE * delta, 0.0, 1.0)
	_steer_current = lerpf(_steer_current, _steer_target, t)
	if _wheel != null:
		# Wheel is tilted toward the driver; spin it about its own local Z
		# (which points back toward the camera after the tilt).
		_wheel.rotation.z = _steer_current

## Set the steering input (amount in [-1, 1]); maps to about ±0.6 rad of turn.
## Called by FPCar every frame. The visible angle eases toward this target.
func set_steer(amount: float) -> void:
	_steer_target = clampf(amount, -1.0, 1.0) * STEER_MAX_RAD

# ── Builders ──────────────────────────────────────────────────────────────────

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = 0.85
	return m

func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.2
	m.roughness = 0.4
	return m

func _box(size: Vector3, color: Color, pos: Vector3, mat: StandardMaterial3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat if mat != null else _mat(color)
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	return mi

func _build_dashboard() -> void:
	# Main dashboard slab spanning the lower view, angled slightly toward the driver.
	var dash := _box(Vector3(1.8, 0.42, 0.55), C_PLASTIC, Vector3(0.0, 1.05, -1.25))
	dash.rotation.x = deg_to_rad(-14.0)
	# A lighter trim lip along the top front edge of the dash.
	var lip := _box(Vector3(1.82, 0.06, 0.1), C_TRIM, Vector3(0.0, 1.27, -1.5))
	lip.rotation.x = deg_to_rad(-14.0)
	# A thin accent stripe across the dash face.
	var stripe := _box(Vector3(1.7, 0.04, 0.02), C_ACCENT, Vector3(0.0, 1.12, -1.02))
	stripe.rotation.x = deg_to_rad(-14.0)
	# A couple of small glowing gauge dots on the dash face.
	_gauge_dot(Vector3(-0.42, 1.16, -1.0), C_GAUGE_A)
	_gauge_dot(Vector3(0.42, 1.16, -1.0), C_GAUGE_B)
	_gauge_dot(Vector3(0.0, 1.1, -1.0), C_GAUGE_A)

func _gauge_dot(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.028
	sm.height = 0.056
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = _glow_mat(color)
	mi.mesh = sm
	mi.position = pos
	add_child(mi)

func _build_steering_wheel() -> void:
	# Pivot node that we tilt toward the driver, then spin about local Z.
	_wheel = Node3D.new()
	_wheel.position = Vector3(0.0, 0.95, -1.05)
	_wheel.rotation.x = deg_to_rad(24.0)  # tilt the wheel plane toward the driver
	add_child(_wheel)

	# Outer rim — a TorusMesh ring. (TorusMesh is a standard Godot 4.x primitive.)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.155
	torus.outer_radius = 0.2
	torus.rings = 24
	torus.ring_segments = 10
	torus.material = _mat(C_PLASTIC_DARK)
	rim.mesh = torus
	# TorusMesh lies in the XZ plane (axis = Y); rotate so it faces the driver (axis = Z).
	rim.rotation.x = deg_to_rad(90.0)
	_wheel.add_child(rim)

	# Central hub.
	var hub := MeshInstance3D.new()
	var hub_cyl := CylinderMesh.new()
	hub_cyl.top_radius = 0.06
	hub_cyl.bottom_radius = 0.06
	hub_cyl.height = 0.04
	hub_cyl.radial_segments = 16
	hub_cyl.material = _mat(C_PLASTIC)
	hub.mesh = hub_cyl
	hub.rotation.x = deg_to_rad(90.0)  # disc faces the driver
	_wheel.add_child(hub)

	# A small accent emblem on the hub center.
	var emblem := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.05, 0.05, 0.012)
	em.material = _glow_mat(C_ACCENT)
	emblem.mesh = em
	emblem.position = Vector3(0.0, 0.0, 0.025)
	_wheel.add_child(emblem)

	# Three spokes from hub to rim (cross-bar style).
	for ang_deg in [90.0, 210.0, 330.0]:
		var spoke := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(0.022, 0.15, 0.022)
		sbm.material = _mat(C_PLASTIC)
		spoke.mesh = sbm
		# Place each spoke radially in the wheel's local XY plane.
		var a: float = deg_to_rad(ang_deg)
		spoke.position = Vector3(cos(a) * 0.085, sin(a) * 0.085, 0.0)
		spoke.rotation.z = a - deg_to_rad(90.0)
		_wheel.add_child(spoke)

func _build_pillars_and_roof() -> void:
	# Two angled A-pillars framing the left/right edges of the windscreen.
	var left := _box(Vector3(0.16, 1.3, 0.16), C_PLASTIC, Vector3(-0.95, 1.55, -0.85))
	left.rotation.z = deg_to_rad(12.0)
	left.rotation.x = deg_to_rad(-10.0)
	var right := _box(Vector3(0.16, 1.3, 0.16), C_PLASTIC, Vector3(0.95, 1.55, -0.85))
	right.rotation.z = deg_to_rad(-12.0)
	right.rotation.x = deg_to_rad(-10.0)
	# Roof header bar across the top of the windscreen.
	var header := _box(Vector3(2.05, 0.18, 0.4), C_TRIM, Vector3(0.0, 2.15, -0.95))
	header.rotation.x = deg_to_rad(18.0)

func _build_mirror() -> void:
	# Rearview mirror up-center: a dark body with a reflective glass face.
	var body := _box(Vector3(0.34, 0.12, 0.06), C_PLASTIC, Vector3(0.0, 2.0, -1.6))
	body.rotation.x = deg_to_rad(8.0)
	# Mirror glass on the rearward face (toward the camera, +Z relative to body).
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.3, 0.09, 0.01)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = C_MIRROR
	gmat.metallic = 0.9
	gmat.roughness = 0.15
	gm.material = gmat
	glass.mesh = gm
	glass.position = Vector3(0.0, 2.0, -1.56)
	glass.rotation.x = deg_to_rad(8.0)
	add_child(glass)
	# A thin stalk connecting the mirror to the roof header.
	_box(Vector3(0.04, 0.16, 0.04), C_PLASTIC_DARK, Vector3(0.0, 2.12, -1.55))
