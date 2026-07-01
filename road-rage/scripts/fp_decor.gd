## FPDecor — static beauty/decor builders for the first-person city (橫衝直撞).
## Pure static helpers; FPMain calls them to prettify the world.
class_name FPDecor
extends RefCounted

## Turn a plain traffic box into something that reads as a car: cabin + wheels +
## headlights, added as children of `body` (whose own box is the chassis). The
## box origin sits at ground level with the chassis centred at y = size.y*0.5.
static func make_car_body(body: Node3D, size: Vector3, color: Color) -> void:
	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(size.x * 0.82, size.y * 0.6, size.z * 0.5)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = color.darkened(0.18)
	cmat.metallic = 0.3
	cmat.roughness = 0.45
	cab.material = cmat
	cabin.mesh = cab
	cabin.position = Vector3(0.0, size.y + cab.size.y * 0.5 - 0.05, -size.z * 0.04)
	body.add_child(cabin)
	# Headlights (front = -Z)
	var hl := StandardMaterial3D.new()
	hl.albedo_color = Color("#FFF3C0")
	hl.emission_enabled = true
	hl.emission = Color("#FFE890")
	hl.emission_energy_multiplier = 2.0
	for sx in [-size.x * 0.32, size.x * 0.32]:
		var l := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(size.x * 0.22, size.y * 0.25, 0.15)
		lm.material = hl
		l.mesh = lm
		l.position = Vector3(sx, size.y * 0.45, -size.z * 0.5)
		body.add_child(l)
	# Wheels
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("#141418")
	wmat.roughness = 0.9
	var wr: float = size.y * 0.32
	for wx in [-size.x * 0.5, size.x * 0.5]:
		for wz in [-size.z * 0.32, size.z * 0.32]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = wr
			wm.bottom_radius = wr
			wm.height = size.x * 0.16
			wm.material = wmat
			w.mesh = wm
			w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			w.position = Vector3(wx, wr, wz)
			body.add_child(w)

## A glowing neon sign: an emissive panel on a thin post at `pos` (base on ground).
static func neon_sign(parent: Node3D, pos: Vector3, facing_deg: float, color: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = Vector3(0.0, facing_deg, 0.0)
	parent.add_child(holder)
	var post_h: float = 5.5
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.25, post_h, 0.25)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("#20202A")
	pm.material = pmat
	post.mesh = pm
	post.position = Vector3(0.0, post_h * 0.5, 0.0)
	holder.add_child(post)
	var panel := MeshInstance3D.new()
	var qm := BoxMesh.new()
	qm.size = Vector3(2.6, 1.2, 0.14)
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = color
	nmat.emission_enabled = true
	nmat.emission = color
	nmat.emission_energy_multiplier = 4.5
	qm.material = nmat
	panel.mesh = qm
	panel.position = Vector3(0.0, post_h + 0.2, 0.0)
	holder.add_child(panel)

## Raised sidewalk curbs along arterial road lines (index % 4 == 0), both sides.
## Cheap: one long thin box per road line per side (~2 per line).
static func add_curbs(parent: Node3D, cols: int, rows: int, tile: float) -> void:
	var span: float = cols * tile
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6A6E78")
	mat.roughness = 0.9
	var curb_h: float = 0.35
	var curb_w: float = 0.5
	var offset: float = tile * 0.5 - 0.4   # to the edge of the road cell
	var c: int = 4
	while c < cols:
		var x: float = c * tile
		for side in [-offset, offset]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(curb_w, curb_h, span)
			bm.material = mat
			b.mesh = bm
			b.position = Vector3(x + side, curb_h * 0.5, span * 0.5)
			parent.add_child(b)
		c += 4
	var r: int = 4
	while r < rows:
		var z: float = r * tile
		for side2 in [-offset, offset]:
			var b2 := MeshInstance3D.new()
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(span, curb_h, curb_w)
			bm2.material = mat
			b2.mesh = bm2
			b2.position = Vector3(span * 0.5, curb_h * 0.5, z + side2)
			parent.add_child(b2)
		r += 4

## Reconfigure an existing Environment + sun for "day" / "dusk" / "night".
## Keeps glow/ssao/ssr as they are; only changes sky/ambient/fog/sun.
static func apply_time_of_day(env: Environment, sun: DirectionalLight3D, mode: String) -> void:
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = env.sky.sky_material
	match mode:
		"dusk":
			if sky_mat:
				sky_mat.sky_top_color = Color("#3A3A6E")
				sky_mat.sky_horizon_color = Color("#E8A24E")
				sky_mat.ground_bottom_color = Color("#2E2A30")
				sky_mat.ground_horizon_color = Color("#8A6A56")
			env.ambient_light_energy = 0.7
			env.fog_light_color = Color("#C8824E")
			sun.rotation_degrees = Vector3(-13.0, -122.0, 0.0)
			sun.light_color = Color("#FFB060")
			sun.light_energy = 1.2
		"night":
			if sky_mat:
				sky_mat.sky_top_color = Color("#070A18")
				sky_mat.sky_horizon_color = Color("#20304E")
				sky_mat.ground_bottom_color = Color("#05060C")
				sky_mat.ground_horizon_color = Color("#141C30")
			env.ambient_light_energy = 0.32
			env.fog_light_color = Color("#10162A")
			sun.rotation_degrees = Vector3(-34.0, -66.0, 0.0)
			sun.light_color = Color("#8F9ED0")   # cool moonlight
			sun.light_energy = 0.5
		_:  # day
			if sky_mat:
				sky_mat.sky_top_color = Color("#2E5FA8")
				sky_mat.sky_horizon_color = Color("#C4D9EC")
				sky_mat.ground_bottom_color = Color("#3E434E")
				sky_mat.ground_horizon_color = Color("#9EACBC")
			env.ambient_light_energy = 1.0
			env.fog_light_color = Color("#C6D8EC")
			sun.rotation_degrees = Vector3(-58.0, -52.0, 0.0)
			sun.light_color = Color("#FFF2DC")
			sun.light_energy = 1.4
