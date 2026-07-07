## FPMain — first-person 3D destruction-driving for 橫衝直撞.
## Dusk city built from primitive meshes (no art assets): designed buildings with
## glowing windows, wandering pedestrian crowds, drifting traffic, streetlights,
## shadows + fog for depth. Reuses CityGen / ComboSystem / ScoreSystem. Endless
## rampage — no death.
extends Node3D

const FPCar = preload("res://scripts/fp_car.gd")
const FPTarget = preload("res://scripts/fp_target.gd")
const FPBuildings = preload("res://scripts/fp_buildings.gd")
const FPPed = preload("res://scripts/fp_ped.gd")
const FPPolice = preload("res://scripts/fp_police.gd")
const FPDecor = preload("res://scripts/fp_decor.gd")
const FPWalker = preload("res://scripts/fp_walker.gd")
const FPFootCop = preload("res://scripts/fp_footcop.gd")
const FPExplosive = preload("res://scripts/fp_explosive.gd")
const FPMinimap = preload("res://scripts/fp_minimap.gd")
const FPPickup = preload("res://scripts/fp_pickup.gd")
const CityGen = preload("res://scripts/city_gen.gd")
const ComboSystem = preload("res://scripts/combo_system.gd")
const ScoreSystem = preload("res://scripts/score_system.gd")

const TILE3D: float = 14.0   ## bigger blocks + wider roads (cornering room)

var _car: FPCar = null
var _walker: FPWalker = null
var _mode: String = "car"    # "car" or "foot"
var _combo := ComboSystem.new()
var _score := ScoreSystem.new()
var _best: int = 0
var _smashed: int = 0
var _rng := RandomNumberGenerator.new()

var _env: Environment = null
var _sun: DirectionalLight3D = null
var _tod: int = 0                 # 0 day, 1 dusk, 2 night
const _TOD_NAMES: Array[String] = ["day", "dusk", "night"]

var _wanted_heat: float = 0.0
var _police: Array = []
var _footcops: Array = []
var _pol_timer: float = 0.0

var _max_hp: float = 100.0
var _hp: float = 100.0
var _regen_delay: float = 0.0
var _ui_hp_bg: ColorRect = null
var _ui_hp_fill: ColorRect = null
var _ui_flash: ColorRect = null
var _flash: float = 0.0

var _ui_score: Label = null
var _ui_combo: Label = null
var _ui_best: Label = null
var _ui_speed: Label = null
var _ui_wanted: Label = null

func _ready() -> void:
	_rng.randomize()
	_best = _score.load_best()
	_build_environment()
	_build_ground()
	_build_bounds()
	_build_city()
	_spawn_car()
	_build_hud()

func _process(delta: float) -> void:
	_combo.tick(delta)
	if _ui_combo:
		_ui_combo.visible = _combo.is_active() and _combo.multiplier() > 1
		_ui_combo.text = "×%d 連擊!" % _combo.multiplier()
	if _ui_speed and is_instance_valid(_car):
		_ui_speed.text = "%d km/h" % int(_car.speed() * 3.6)
	# Wanted heat decays; police escalate with the star level.
	_wanted_heat = maxf(0.0, _wanted_heat - 6.0 * delta)
	_pol_timer -= delta
	if _pol_timer <= 0.0:
		_pol_timer = 3.0
		_manage_police()
	if _ui_wanted:
		var stars: int = _wanted_stars()
		_ui_wanted.text = "通緝 " + "★".repeat(stars) + "☆".repeat(5 - stars)
	_update_health(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)
	if _ui_flash:
		_ui_flash.color.a = _flash * 0.5
	# Cycle day / dusk / night with T.
	if Input.is_action_just_pressed("toggle_time"):
		_cycle_time()
	# Get in / out of the car with E.
	if Input.is_action_just_pressed("enter_exit"):
		_toggle_vehicle()

func _wanted_stars() -> int:
	var s: int = 0
	for i in RRTuning.STAR_THRESHOLDS.size():
		if _wanted_heat >= float(RRTuning.STAR_THRESHOLDS[i]):
			s = i
	return s

func _manage_police() -> void:
	_police = _police.filter(func(p): return is_instance_valid(p))
	_footcops = _footcops.filter(func(c): return is_instance_valid(c))
	var stars: int = _wanted_stars()
	var pp: Vector3 = _player_pos()
	while _police.size() < stars * 2 and is_instance_valid(_car):
		_police.append(FPPolice.spawn(self, _car, pp, 90.0))
	while _footcops.size() < stars * 2:
		_footcops.append(FPFootCop.spawn(self, self, pp, 55.0))

func _player_pos() -> Vector3:
	if _mode == "foot" and is_instance_valid(_walker):
		return _walker.global_position
	if is_instance_valid(_car):
		return _car.global_position
	return Vector3.ZERO

func _damage(amt: float) -> void:
	_hp = maxf(0.0, _hp - amt)
	_regen_delay = 2.5
	if _hp <= 0.0:
		_respawn()

func _respawn() -> void:
	_hp = _max_hp
	_wanted_heat *= 0.4
	var safe: Vector3 = _world_pos(Vector2i(12, 12)) + Vector3(0.0, 1.2, 0.0)
	# Always bring the car to the respawn point so it is never lost ("車不見").
	if is_instance_valid(_car):
		_car.global_position = safe
		_car.velocity = Vector3.ZERO
	if _mode == "foot" and is_instance_valid(_walker):
		_walker.global_position = safe + Vector3(4.5, 0.0, 0.0)   # beside the car
		_walker.velocity = Vector3.ZERO

func _update_health(delta: float) -> void:
	var pp: Vector3 = _player_pos()
	for p in _police:
		if is_instance_valid(p) and p.global_position.distance_to(pp) < 5.0:
			_damage(18.0 * delta)
	if _regen_delay > 0.0:
		_regen_delay -= delta
	elif _hp < _max_hp:
		_hp = minf(_max_hp, _hp + 12.0 * delta)
	if _ui_hp_fill and _ui_hp_bg:
		var frac: float = clampf(_hp / _max_hp, 0.0, 1.0)
		_ui_hp_fill.size.x = _ui_hp_bg.size.x * frac
		_ui_hp_fill.color = Color("#4ADE6A").lerp(Color("#E04040"), 1.0 - frac)

func _cycle_time() -> void:
	_tod = (_tod + 1) % _TOD_NAMES.size()
	if _env != null and _sun != null:
		FPDecor.apply_time_of_day(_env, _sun, _TOD_NAMES[_tod])

# ── On foot: get in/out of the car + shooting ────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _mode == "foot" and is_instance_valid(_walker):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_walker.fire()

func _toggle_vehicle() -> void:
	if _mode == "car":
		_exit_car()
	else:
		_enter_car()

func _exit_car() -> void:
	if not is_instance_valid(_car):
		return
	_mode = "foot"
	_car.active = false
	_car.velocity = Vector3.ZERO   # park it
	if not is_instance_valid(_walker):
		_walker = FPWalker.new()
		add_child(_walker)
	var side: Vector3 = _car.global_transform.basis.x.normalized()
	_walker.rotation = Vector3.ZERO
	_walker.global_position = _car.global_position + side * 3.8 + Vector3(0.0, 0.3, 0.0)
	_walker.make_current()

func _enter_car() -> void:
	if not is_instance_valid(_walker) or not is_instance_valid(_car):
		return
	var wp: Vector3 = _walker.global_position
	var own_d: float = _car.global_position.distance_to(wp)
	# Find the nearest traffic vehicle so you can hijack any car nearby.
	var nearest = null
	var nd: float = 1000000.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		if is_instance_valid(v):
			var d: float = v.global_position.distance_to(wp)
			if d < nd:
				nd = d
				nearest = v
	if own_d <= 8.0 and own_d <= nd:
		_board_car()
	elif nearest != null and nd <= 8.0:
		# Hijack: move our car onto that car's spot and remove it.
		var pos: Vector3 = nearest.global_position
		nearest.queue_free()
		_car.global_position = pos + Vector3(0.0, 0.6, 0.0)
		_car.velocity = Vector3.ZERO
		_board_car()

func _board_car() -> void:
	_mode = "car"
	_car.active = true
	_car.focus_camera()
	if is_instance_valid(_walker):
		_walker.queue_free()
	_walker = null

func _world_pos(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE3D, 0.0, cell.y * TILE3D)

# ── Atmosphere & depth ────────────────────────────────────────────────────────

func _build_environment() -> void:
	# Bright DAYTIME: clear blue sky, strong neutral ambient, light distance haze
	# for depth, and a high sun casting crisp shadows (the main depth cue).
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Grand procedural sky — a gradient dome with a sun disk (follows the sun light).
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#2E5FA8")
	sky_mat.sky_horizon_color = Color("#C4D9EC")
	sky_mat.ground_bottom_color = Color("#3E434E")
	sky_mat.ground_horizon_color = Color("#9EACBC")
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# Atmospheric depth.
	env.fog_enabled = true
	env.fog_light_color = Color("#C6D8EC")
	env.fog_density = 0.0026
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.3
	# Grandeur: ambient occlusion + bloom + cinematic tonemap (Forward+ features).
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.2
	env.ssr_enabled = true          # screen-space reflections on the polished road
	env.ssr_max_steps = 32
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	we.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -52.0, 0.0)  # high midday angle
	sun.light_color = Color("#EAF2FB")  # cool daylight white
	sun.light_energy = 1.35
	# Forward+ on Apple Silicon handles real-time shadows fine — re-enabled for depth.
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.shadow_bias = 0.04
	add_child(sun)
	_env = env
	_sun = sun

func _build_ground() -> void:
	var span: float = RRTuning.CITY_COLS * TILE3D
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(span + 60.0, 2.0, span + 60.0)
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#22222A")
	mat.roughness = 0.5     # polished asphalt — catches SSR reflections
	mat.metallic = 0.12
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = Vector3(span * 0.5, -1.0, span * 0.5)  # top at y=0
	add_child(body)
	# Cheap road-lane depth cues: slightly-emissive strips along arterial cells.
	var lane_mat := StandardMaterial3D.new()
	lane_mat.albedo_color = Color("#3A3A44")
	lane_mat.emission_enabled = true
	lane_mat.emission = Color("#5A5E78")
	lane_mat.emission_energy_multiplier = 0.6
	lane_mat.roughness = 1.0
	var lane_y: float = 0.02
	var strip_w: float = 0.6
	var c: int = 0
	while c <= RRTuning.CITY_COLS:
		var center: float = c * TILE3D
		var z_strip := MeshInstance3D.new()
		var zq := QuadMesh.new()
		zq.size = Vector2(strip_w, span)
		zq.material = lane_mat
		z_strip.mesh = zq
		z_strip.position = Vector3(center, lane_y, span * 0.5)
		z_strip.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(z_strip)
		var x_strip := MeshInstance3D.new()
		var xq := QuadMesh.new()
		xq.size = Vector2(span, strip_w)
		xq.material = lane_mat
		x_strip.mesh = xq
		x_strip.position = Vector3(span * 0.5, lane_y, center)
		x_strip.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(x_strip)
		c += 4

func _build_bounds() -> void:
	# Tall perimeter walls so the car can NEVER drive off the world (which read as
	# "the game ended"). Slightly inset blue-grey barriers around the district.
	var span: float = RRTuning.CITY_COLS * TILE3D
	var h: float = 40.0
	var th: float = 4.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#39414F")
	mat.roughness = 0.9
	var c: float = span * 0.5
	_wall(Vector3(c, h * 0.5, -th * 0.5), Vector3(span + th * 2.0, h, th), mat)
	_wall(Vector3(c, h * 0.5, span + th * 0.5), Vector3(span + th * 2.0, h, th), mat)
	_wall(Vector3(-th * 0.5, h * 0.5, c), Vector3(th, h, span + th * 2.0), mat)
	_wall(Vector3(span + th * 0.5, h * 0.5, c), Vector3(th, h, span + th * 2.0), mat)

func _wall(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	sb.position = pos
	add_child(sb)

func _add_streetlight(pos: Vector3) -> void:
	var pole_height: float = 7.0
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, pole_height, 0.35)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("#2A2A30")
	pmat.metallic = 0.4
	pmat.roughness = 0.7
	bm.material = pmat
	pole.mesh = bm
	pole.position = pos + Vector3(0.0, pole_height * 0.5, 0.0)
	add_child(pole)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.45
	hm.height = 0.9
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color("#FFD9A0")
	hmat.emission_enabled = true
	hmat.emission = Color("#FFC062")
	hmat.emission_energy_multiplier = 4.0
	hm.material = hmat
	head.mesh = hm
	head.position = pos + Vector3(0.0, pole_height, 0.0)
	add_child(head)
	var light := OmniLight3D.new()
	light.light_color = Color("#FFC062")
	light.light_energy = 2.0
	light.omni_range = 18.0
	light.omni_attenuation = 1.5
	light.position = pos + Vector3(0.0, pole_height - 0.4, 0.0)
	add_child(light)

# ── City ──────────────────────────────────────────────────────────────────────

func _build_city() -> void:
	var layout: Dictionary = CityGen.new().generate(_rng.randi())
	for cell in layout["buildings"]:
		_add_building(cell)
	for p in layout["props"]:
		_add_target(p["cell"], p["kind"], Vector3.ZERO)
	_spawn_traffic(12)
	_spawn_crowds(16)   # more pedestrians on the streets
	_spawn_trees(34)
	FPDecor.add_curbs(self, RRTuning.CITY_COLS, RRTuning.CITY_ROWS, TILE3D)
	_spawn_neon(16)
	_build_test_track()
	var barrels: Array = FPExplosive.scatter(self, 40, RRTuning.CITY_COLS * TILE3D, _rng)
	for b in barrels:
		b.connect("exploded", _on_explosion)
	FPDecor.add_crosswalks(self, RRTuning.CITY_COLS, RRTuning.CITY_ROWS, TILE3D)
	_spawn_landmarks()
	var packs: Array = FPPickup.scatter(self, 16, RRTuning.CITY_COLS * TILE3D, _rng)
	for p in packs:
		p.connect("collected", _on_pickup)

func _add_building(cell: Vector2i) -> void:
	var b := FPBuildings.make(TILE3D * 0.82, _rng)
	add_child(b)
	b.global_position = _world_pos(cell)
	b.connect("collapsed", _on_building_collapsed)

func _on_building_collapsed(pos: Vector3) -> void:
	_hit_stop(0.05)
	var pts: int = _combo.register(150)
	_score.add(pts, 1)
	_smashed += 1
	_wanted_heat += 40.0   # leveling a building brings serious heat
	if _score.score > _best:
		_best = _score.score
		_score.submit()
	_popup(pos + Vector3(0.0, 5.0, 0.0), "轟! +%d" % pts)
	_refresh()

func _on_explosion(pos: Vector3) -> void:
	_flash = 0.55
	_hit_stop(0.04)
	if _player_pos().distance_to(pos) < 15.0:
		_damage(26.0)
	var pts: int = _combo.register(60)
	_score.add(pts, 1)
	_smashed += 1
	_wanted_heat += 22.0
	_popup(pos + Vector3(0.0, 3.0, 0.0), "轟!")
	_refresh()

func _on_pickup(amount: float, pos: Vector3) -> void:
	_hp = minf(_max_hp, _hp + amount)
	_popup(pos + Vector3(0.0, 2.0, 0.0), "+體力")

func _hit_stop(dur: float) -> void:
	if Engine.time_scale < 1.0:
		return   # a freeze is already active — don't stack
	Engine.time_scale = 0.0
	get_tree().create_timer(dur, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)

func _spawn_landmarks() -> void:
	var cells: Array[Vector2i] = [Vector2i(6, 6), Vector2i(6, 22), Vector2i(22, 6), Vector2i(22, 22), Vector2i(14, 18)]
	var colors: Array[Color] = [Color("#3A5A8A"), Color("#5A4A6A"), Color("#4A6A5A")]
	for i in cells.size():
		var h: float = _rng.randf_range(46.0, 74.0)
		var sb := FPBuildingBody.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(TILE3D * 0.7, h, TILE3D * 0.7)
		col.shape = shape
		col.position = Vector3(0.0, h * 0.5, 0.0)
		sb.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = shape.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.metallic = 0.4
		mat.roughness = 0.35
		bm.material = mat
		mi.mesh = bm
		mi.position = Vector3(0.0, h * 0.5, 0.0)
		sb.add_child(mi)
		var top := MeshInstance3D.new()
		var tbm := BoxMesh.new()
		tbm.size = Vector3(TILE3D * 0.76, 1.6, TILE3D * 0.76)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color("#FFC060")
		tmat.emission_enabled = true
		tmat.emission = Color("#FFC060")
		tmat.emission_energy_multiplier = 2.2
		tbm.material = tmat
		top.mesh = tbm
		top.position = Vector3(0.0, h, 0.0)
		sb.add_child(top)
		var spire := MeshInstance3D.new()
		var scm := CylinderMesh.new()
		scm.top_radius = 0.1
		scm.bottom_radius = 0.5
		scm.height = 8.0
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color("#AAB0BA")
		scm.material = smat
		spire.mesh = scm
		spire.position = Vector3(0.0, h + 4.0, 0.0)
		sb.add_child(spire)
		add_child(sb)
		sb.global_position = _world_pos(cells[i])
		sb.connect("collapsed", _on_building_collapsed)

func _add_target(cell: Vector2i, kind: String, drift: Vector3) -> void:
	var t := FPTarget.new()
	match kind:
		"car":
			t.value = RRTuning.SCORE_CAR; t.heat = RRTuning.HEAT_CAR
			t.box_color = Color("#4A7AC8"); t.size = Vector3(2.4, 1.6, 4.2); t.min_speed = 4.0
		"ped":
			t.value = RRTuning.SCORE_PED; t.heat = RRTuning.HEAT_PED
			t.box_color = Color("#E0B0A0"); t.size = Vector3(1.0, 2.0, 1.0); t.min_speed = 2.0
		_:
			t.value = RRTuning.SCORE_PROP; t.heat = RRTuning.HEAT_PROP
			t.box_color = Color("#C8A24A"); t.size = Vector3(1.8, 2.0, 1.8); t.min_speed = 5.0
	t.drift = drift
	t.smashed.connect(_on_smashed)
	add_child(t)
	t.global_position = _world_pos(cell)
	if kind == "car":
		FPDecor.make_car_body(t, t.size, t.box_color)
		t.add_to_group("vehicle")

func _spawn_traffic(count: int) -> void:
	for i in count:
		var on_x: bool = (i % 2 == 0)
		var lane: int = (_rng.randi_range(0, RRTuning.CITY_COLS / 4)) * 4
		var along: int = _rng.randi_range(1, RRTuning.CITY_ROWS - 2)
		var cell := Vector2i(lane, along) if on_x else Vector2i(along, lane)
		var dir := Vector3(0, 0, _rng.randf_range(8.0, 16.0)) if on_x else Vector3(_rng.randf_range(8.0, 16.0), 0, 0)
		_add_target(cell, "car", dir)

func _spawn_crowds(clusters: int) -> void:
	for i in clusters:
		var cell := Vector2i(_rng.randi_range(1, RRTuning.CITY_COLS - 2), _rng.randi_range(1, RRTuning.CITY_ROWS - 2))
		var peds: Array = FPPed.crowd(self, _world_pos(cell), _rng.randi_range(3, 6), _rng)
		for ped in peds:
			ped.smashed.connect(_on_smashed)

func _spawn_streetlights() -> void:
	var c: int = 0
	while c < RRTuning.CITY_COLS:
		var r: int = 0
		while r < RRTuning.CITY_ROWS:
			if _rng.randf() < 0.12:   # daytime: just a few poles; many omnis stress GL-compat
				_add_streetlight(_world_pos(Vector2i(c, r)) + Vector3(TILE3D * 0.4, 0.0, TILE3D * 0.4))
			r += 4
		c += 4

func _add_tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.3
	tm.bottom_radius = 0.42
	tm.height = 3.0
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("#5A3A22")
	trunk_mat.roughness = 0.95
	tm.material = trunk_mat
	trunk.mesh = tm
	trunk.position = pos + Vector3(0.0, 1.5, 0.0)
	add_child(trunk)
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.9
	sm.height = 3.6
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("#3E7D3A")
	leaf.roughness = 0.9
	sm.material = leaf
	canopy.mesh = sm
	canopy.position = pos + Vector3(0.0, 4.0, 0.0)
	add_child(canopy)

func _spawn_trees(count: int) -> void:
	# Greenery along the sidewalks (edges of road cells) for a bit of life.
	var span: float = RRTuning.CITY_COLS * TILE3D
	for i in count:
		var lane: int = (_rng.randi_range(1, RRTuning.CITY_COLS / 4)) * 4
		var along: float = _rng.randf_range(1.0, RRTuning.CITY_ROWS - 1) * TILE3D
		var edge: float = TILE3D * 0.42 * (1.0 if (i % 2 == 0) else -1.0)
		var p: Vector3
		if i % 2 == 0:
			p = Vector3(lane * TILE3D + edge, 0.0, along)
		else:
			p = Vector3(along, 0.0, lane * TILE3D + edge)
		p.x = clampf(p.x, 6.0, span - 6.0)
		p.z = clampf(p.z, 6.0, span - 6.0)
		_add_tree(p)

func _spawn_neon(count: int) -> void:
	var colors: Array[Color] = [Color("#FF3AA0"), Color("#22E0FF"), Color("#FFE23A"), Color("#8A5CFF"), Color("#FF6A2A"), Color("#3AFF8A")]
	for i in count:
		var lane: int = (_rng.randi_range(1, RRTuning.CITY_COLS / 4)) * 4
		var along: float = _rng.randf_range(2.0, RRTuning.CITY_ROWS - 2) * TILE3D
		var pos: Vector3
		var facing: float
		if i % 2 == 0:
			pos = Vector3(lane * TILE3D + TILE3D * 0.42, 0.0, along)
			facing = 90.0
		else:
			pos = Vector3(along, 0.0, lane * TILE3D + TILE3D * 0.42)
			facing = 0.0
		FPDecor.neon_sign(self, pos, facing, colors[_rng.randi() % colors.size()])

func _build_test_track() -> void:
	# A ring of cones near the spawn — a simple cornering course to test handling.
	var center: Vector3 = _world_pos(Vector2i(12, 12))
	var rx: float = 56.0
	var rz: float = 36.0
	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color("#FF6A1A")
	cone_mat.emission_enabled = true
	cone_mat.emission = Color("#FF5400")
	cone_mat.emission_energy_multiplier = 0.7
	var n: int = 26
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var pos: Vector3 = center + Vector3(cos(a) * rx, 0.0, sin(a) * rz)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.45
		cm.height = 1.1
		cm.material = cone_mat
		cone.mesh = cm
		cone.position = pos + Vector3(0.0, 0.55, 0.0)
		add_child(cone)

func _spawn_car() -> void:
	_car = FPCar.new()
	_car.position = _world_pos(Vector2i(12, 12)) + Vector3(0.0, 1.2, 0.0)
	add_child(_car)

# ── Events / HUD ──────────────────────────────────────────────────────────────

func _on_smashed(value: int, heat: int, pos: Vector3) -> void:
	var pts: int = _combo.register(value)
	_score.add(pts, 1)
	_smashed += 1
	_wanted_heat += float(heat)
	if _score.score > _best:
		_best = _score.score
		_score.submit()
	_popup(pos, "+%d" % pts)
	_refresh()

func _popup(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos + Vector3(0.0, 2.5, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.modulate = Color("#FFE08A")
	l.outline_size = 12
	add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 4.0, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(l): l.queue_free())

func _refresh() -> void:
	if _ui_score:
		_ui_score.text = "分數 %d　·　摧毀 %d" % [_score.score, _smashed]
	if _ui_best:
		_ui_best.text = ("最佳 %d" % _best) if _best > 0 else ""

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_flash = ColorRect.new()
	_ui_flash.color = Color(1.0, 0.6, 0.25, 0.0)
	_ui_flash.size = Vector2(960, 540)
	_ui_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ui_flash)
	_ui_score = _mk_label(ui, Vector2(20, 16), 26, Color("#F2E4B0"))
	_ui_best = _mk_label(ui, Vector2(740, 18), 18, Color("#C8BC90"))
	_ui_combo = _mk_label(ui, Vector2(20, 50), 24, Color("#FFB020"))
	_ui_combo.visible = false
	_ui_wanted = _mk_label(ui, Vector2(20, 84), 22, Color("#FF6060"))
	var hp_lbl := _mk_label(ui, Vector2(20, 114), 16, Color("#C8D0DC"))
	hp_lbl.text = "體力"
	_ui_hp_bg = ColorRect.new()
	_ui_hp_bg.position = Vector2(70, 118)
	_ui_hp_bg.size = Vector2(200, 16)
	_ui_hp_bg.color = Color(0.1, 0.1, 0.12, 0.85)
	ui.add_child(_ui_hp_bg)
	_ui_hp_fill = ColorRect.new()
	_ui_hp_fill.position = Vector2(70, 118)
	_ui_hp_fill.size = Vector2(200, 16)
	_ui_hp_fill.color = Color("#4ADE6A")
	ui.add_child(_ui_hp_fill)
	_ui_speed = _mk_label(ui, Vector2(740, 500), 22, Color("#A0D0FF"))
	var hint := _mk_label(ui, Vector2(20, 508), 15, Color("#B8C0CC"))
	hint.text = "車:Shift 氮氣 空白 手煞 · E 上下車 · 步行:WASD J 射擊 Shift 衝刺 空白 跳 · , . 轉視角 · T 日夜"
	var mm := FPMinimap.new()
	mm.game = self
	mm.position = Vector2(794.0, 60.0)
	ui.add_child(mm)
	_refresh()

func _mk_label(ui: CanvasLayer, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(400, 36)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	ui.add_child(l)
	return l
