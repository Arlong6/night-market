## FPVehicleKinds — the catalogue of vehicles that fill the city, and the single
## place their look, worth and handling live. Traffic spawns from this table, and
## carjacking one hands its `drive` profile to the player's car, so stealing a bus
## really does feel like driving a bus: slow to wind up, hopeless in a corner, and
## an absolute wrecking ball once it is moving.
##
## Data-driven per project standards: to add a vehicle, add a row here. Nothing
## else needs to change.
class_name FPVehicleKinds
extends RefCounted

## Cached so the literals are built once instead of on every spawn.
static var _catalogue: Array = []

## chassis  base box: x = width, y = ride height, z = length (world units)
## cabin    the greenhouse: [width_frac, height, length_frac, z_offset_frac]
## box      optional cargo body behind the cabin: [height, length_frac, z_offset_frac]
## axles    z offsets (fraction of length) that get a wheel pair
## wheel    wheel radius as a fraction of chassis height
## speed    drift speed range for street traffic
## drive    multipliers over FPCar's base constants once the player is behind the wheel
## weight   spawn weight — sedans everywhere, buses rare. 0 = never spawns as traffic.
static func catalogue() -> Array:
	if _catalogue.is_empty():
		_catalogue = [
			{
				"id": "muscle", "name": "肌肉車", "weight": 0,
				"value": RRTuning.SCORE_CAR, "heat": RRTuning.HEAT_CAR,
				"chassis": Vector3(3.2, 1.0, 6.6), "colors": ["#D8482A"],
				"cabin": [0.84, 1.0, 0.45, 0.07], "box": [],
				"axles": [-0.33, 0.33], "wheel": 0.72, "speed": [10.0, 16.0],
				"drive": {"accel": 1.0, "top": 1.0, "turn": 1.0, "grip": 1.0, "mass": 1.0},
			},
			{
				"id": "sedan", "name": "轎車", "weight": 34,
				"value": RRTuning.SCORE_CAR, "heat": RRTuning.HEAT_CAR,
				"chassis": Vector3(2.4, 1.4, 4.4),
				"colors": ["#4A7AC8", "#3F6B4E", "#8C8F98", "#B4453C", "#2E3440"],
				"cabin": [0.84, 1.05, 0.48, 0.06], "box": [],
				"axles": [-0.32, 0.32], "wheel": 0.5, "speed": [10.0, 16.0],
				"drive": {"accel": 1.05, "top": 1.02, "turn": 1.05, "grip": 1.05, "mass": 0.9},
			},
			{
				"id": "sports", "name": "跑車", "weight": 16,
				"value": int(RRTuning.SCORE_CAR * 1.5), "heat": RRTuning.HEAT_CAR,
				"chassis": Vector3(2.5, 0.95, 4.8),
				"colors": ["#E03A2E", "#F2C12E", "#1FBFA8", "#EE6A1E", "#F0F0F2"],
				"cabin": [0.78, 0.62, 0.34, 0.20], "box": [],
				"axles": [-0.34, 0.34], "wheel": 0.62, "speed": [15.0, 23.0],
				"drive": {"accel": 1.45, "top": 1.30, "turn": 1.18, "grip": 1.30, "mass": 0.75},
			},
			{
				"id": "van", "name": "廂型車", "weight": 14,
				"value": int(RRTuning.SCORE_CAR * 1.6), "heat": int(RRTuning.HEAT_CAR * 1.2),
				"chassis": Vector3(2.5, 1.6, 5.0),
				"colors": ["#E8E6DE", "#C9CBD0", "#6E7C8C", "#D8C8A0"],
				"cabin": [0.90, 1.15, 0.30, -0.26], "box": [1.55, 0.62, 0.20],
				"axles": [-0.32, 0.34], "wheel": 0.48, "speed": [8.0, 13.0],
				"drive": {"accel": 0.86, "top": 0.92, "turn": 0.82, "grip": 0.90, "mass": 1.35},
			},
			{
				"id": "truck", "name": "卡車", "weight": 9,
				"value": RRTuning.SCORE_CAR * 2, "heat": int(RRTuning.HEAT_CAR * 1.5),
				"chassis": Vector3(2.9, 1.8, 7.4),
				"colors": ["#8E3B2E", "#2F5A3E", "#37476B", "#4A4A50"],
				"cabin": [0.92, 1.5, 0.24, -0.34], "box": [2.1, 0.56, 0.20],
				"axles": [-0.36, 0.16, 0.36], "wheel": 0.46, "speed": [7.0, 11.0],
				"drive": {"accel": 0.70, "top": 0.84, "turn": 0.62, "grip": 0.76, "mass": 2.0},
			},
			{
				"id": "bus", "name": "公車", "weight": 6,
				"value": RRTuning.SCORE_CAR * 3, "heat": RRTuning.HEAT_CAR * 2,
				"chassis": Vector3(2.9, 2.0, 9.6),
				"colors": ["#F0B429", "#E2582E", "#3FA98C", "#D8D4CA"],
				"cabin": [0.96, 1.7, 0.90, 0.02], "box": [],
				"axles": [-0.36, 0.14, 0.36], "wheel": 0.42, "speed": [6.0, 10.0],
				"drive": {"accel": 0.58, "top": 0.76, "turn": 0.48, "grip": 0.70, "mass": 2.6},
			},
		]
	return _catalogue

## The car the player starts the run in.
static func player_default() -> Dictionary:
	return by_id("muscle")

static func by_id(id: String) -> Dictionary:
	for k in catalogue():
		if String(k["id"]) == id:
			return k
	return catalogue()[0]

## Weighted pick over everything with weight > 0 — street traffic is mostly
## sedans, with the occasional bus to make a block feel alive (and worth a lot).
static func pick(rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for k in catalogue():
		total += int(k["weight"])
	var roll: int = rng.randi_range(1, maxi(total, 1))
	for k in catalogue():
		roll -= int(k["weight"])
		if roll <= 0 and int(k["weight"]) > 0:
			return k
	return by_id("sedan")

## Number of kinds that actually appear as street traffic.
static func traffic_kind_count() -> int:
	var n: int = 0
	for k in catalogue():
		if int(k["weight"]) > 0:
			n += 1
	return n

## Build the body of `kind` onto `holder`, sitting on the ground at local origin.
## `holder` supplies nothing but a transform — every mesh here is a child of it,
## so a rebuild is just "free the holder and call this again".
static func build(holder: Node3D, kind: Dictionary, color: Color) -> void:
	var size: Vector3 = kind["chassis"]
	var wheel_r: float = size.y * float(kind["wheel"])

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.metallic = 0.35
	body_mat.roughness = 0.45

	# Chassis — the slab everything else sits on.
	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(size.x, size.y * 0.62, size.z)
	cm.material = body_mat
	chassis.mesh = cm
	chassis.position = Vector3(0.0, wheel_r + cm.size.y * 0.4, 0.0)
	holder.add_child(chassis)

	# Cabin / greenhouse — the silhouette that tells the kinds apart at a glance.
	var cab_spec: Array = kind["cabin"]
	var cab_h: float = float(cab_spec[1])
	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(size.x * float(cab_spec[0]), cab_h, size.z * float(cab_spec[2]))
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = color.darkened(0.18)
	cab_mat.metallic = 0.35
	cab_mat.roughness = 0.45
	cab.material = cab_mat
	cabin.mesh = cab
	var cab_z: float = size.z * float(cab_spec[3])
	var deck: float = chassis.position.y + cm.size.y * 0.5
	cabin.position = Vector3(0.0, deck + cab_h * 0.5, cab_z)
	holder.add_child(cabin)

	# Windscreen on the front face of the cabin (the car faces -Z).
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(cab.size.x * 0.94, cab_h * 0.72, 0.18)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#243040")
	gmat.metallic = 0.7
	gmat.roughness = 0.1
	gm.material = gmat
	glass.mesh = gm
	glass.position = Vector3(0.0, cabin.position.y + cab_h * 0.08, cab_z - cab.size.z * 0.5 - 0.05)
	holder.add_child(glass)

	# Optional cargo body (vans and trucks) — a tall slab behind the cab.
	var box_spec: Array = kind["box"]
	if box_spec.size() == 3:
		var bx := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x * 0.98, float(box_spec[0]), size.z * float(box_spec[1]))
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = color.lightened(0.22)
		bmat.roughness = 0.65
		bm.material = bmat
		bx.mesh = bm
		bx.position = Vector3(0.0, deck + bm.size.y * 0.5, size.z * float(box_spec[2]))
		holder.add_child(bx)

	# Headlights (front = -Z), emissive so they read at dusk and at night.
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color("#FFF6C0")
	hl_mat.emission_enabled = true
	hl_mat.emission = Color("#FFE890")
	hl_mat.emission_energy_multiplier = 2.0
	for sx in [-size.x * 0.33, size.x * 0.33]:
		var hl := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(size.x * 0.19, size.y * 0.24, 0.2)
		hm.material = hl_mat
		hl.mesh = hm
		hl.position = Vector3(sx, chassis.position.y, -size.z * 0.5 - 0.05)
		holder.add_child(hl)

	# Wheels — cylinders on their side, one pair per axle.
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color("#18181C")
	wheel_mat.roughness = 0.9
	for wx in [-size.x * 0.52, size.x * 0.52]:
		for az in kind["axles"]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = wheel_r
			wm.bottom_radius = wheel_r
			wm.height = size.x * 0.16
			wm.material = wheel_mat
			w.mesh = wm
			w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			w.position = Vector3(wx, wheel_r, size.z * float(az))
			holder.add_child(w)
