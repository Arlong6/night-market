## FPBuildings — a factory for VARIED, designed 3D buildings built from primitive
## meshes only (no art assets) for the 橫衝直撞 first-person spike.
##
## Each building is a single StaticBody3D with ONE BoxShape3D collider covering the
## main mass; everything else (tiers, windows, trim bands, roof features) is
## visual-only MeshInstance3D children. Buildings are built UPWARD FROM y=0, so the
## caller sets global_position directly with NO vertical offset.
##
## Usage (from FPMain):
##   var b := FPBuildings.make(TILE3D * 0.82, _rng)
##   add_child(b)
##   b.global_position = _world_pos(cell)   # base sits on the ground (y=0)
class_name FPBuildings
extends RefCounted

const STOREY_H: float = 3.0          ## World height of one storey.
const MIN_STOREYS: int = 1
const MAX_STOREYS: int = 6
const SETBACK_CHANCE: float = 0.40   ## Probability a building tiers inward as it rises.
const SETBACK_FACTOR: float = 0.74   ## Each setback tier shrinks footprint to this fraction.
const WINDOW_LIT_CHANCE: float = 0.62 ## Fraction of windows that glow warm at night.
const MAX_WINDOW_COLS: int = 3        ## Cap window grid density (node-count budget).
const MAX_WINDOW_ROWS_PER_TIER: int = 2

## Body palette — concrete greys, brick reds, teal, tan.
const PALETTE: Array[Color] = [
	Color("#5B5E66"),  # concrete grey
	Color("#6E7178"),  # light concrete
	Color("#8A4332"),  # brick red
	Color("#A8533C"),  # terracotta
	Color("#2F6E6A"),  # teal
	Color("#B79B6A"),  # tan / sandstone
]
## Contrasting trim-band colors keyed loosely off the body (cool vs warm).
const TRIM_PALETTE: Array[Color] = [
	Color("#C8C2B0"),  # bone / pale stone
	Color("#D9A441"),  # brass
	Color("#3C4756"),  # slate
	Color("#E2E6EA"),  # white concrete
]
## Window glow tints (warm interior light).
const GLOW_WARM: Array[Color] = [
	Color("#FFD27A"),
	Color("#FFC153"),
	Color("#FFE2A8"),
]
const GLOW_DARK: Color = Color("#1A1C22")  ## Unlit window — dark glass.


## Build a finished building node. `footprint` is the ground width/depth
## (~TILE3D*0.82 ≈ 9.8). `rng` drives all variation deterministically.
static func make(footprint: float, rng: RandomNumberGenerator) -> StaticBody3D:
	var storeys: int = rng.randi_range(MIN_STOREYS, MAX_STOREYS)
	var total_h: float = float(storeys) * STOREY_H
	var body_color: Color = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
	var trim_color: Color = TRIM_PALETTE[rng.randi_range(0, TRIM_PALETTE.size() - 1)]
	var tiered: bool = storeys >= 3 and rng.randf() < SETBACK_CHANCE

	var root := StaticBody3D.new()

	# Single collider covering the main (ground-level, widest) mass.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint, total_h, footprint)
	col.shape = shape
	col.position = Vector3(0.0, total_h * 0.5, 0.0)  # center the box; base at y=0
	root.add_child(col)

	# Shared materials (re-used across tiers to keep allocations low).
	var body_mat: StandardMaterial3D = _solid_mat(body_color, 0.85, 0.0)
	var trim_mat: StandardMaterial3D = _solid_mat(trim_color, 0.7, 0.05)

	# Build the stack of tiers from the ground up.
	var y_base: float = 0.0
	var cur_w: float = footprint
	var remaining: int = storeys
	var top_tier_w: float = footprint
	var top_tier_top: float = 0.0
	var tier_index: int = 0
	while remaining > 0:
		var tier_storeys: int = remaining
		if tiered and tier_index == 0 and storeys >= 3:
			# Tall base tier, then narrower stacks above.
			tier_storeys = maxi(1, storeys - rng.randi_range(1, 2))
		elif tiered:
			tier_storeys = maxi(1, mini(remaining, rng.randi_range(1, 2)))
		var tier_h: float = float(tier_storeys) * STOREY_H

		_add_tier_block(root, cur_w, tier_h, y_base, body_mat)
		# Windows temporarily OFF: thousands of window meshes were the prime
		# suspect for the GL-compat render crash. Re-add via MultiMesh once stable.
		# _add_windows(root, cur_w, tier_h, y_base, rng)
		_add_trim_band(root, cur_w, y_base + tier_h, trim_mat)

		top_tier_w = cur_w
		top_tier_top = y_base + tier_h
		y_base += tier_h
		remaining -= tier_storeys
		tier_index += 1
		if tiered:
			cur_w *= SETBACK_FACTOR
		else:
			break  # single block — one tier only

	# Roof feature on top of the highest tier.
	_add_roof(root, top_tier_w, top_tier_top, body_color, rng)

	return root


# ── Building pieces ─────────────────────────────────────────────────────────

## One solid box tier sitting on top of `y_base`, of width `w` and height `h`.
static func _add_tier_block(root: StaticBody3D, w: float, h: float, y_base: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, w)
	bm.material = mat
	mi.mesh = bm
	mi.position = Vector3(0.0, y_base + h * 0.5, 0.0)
	root.add_child(mi)


## A thin contrasting band wrapping the building near the top of a tier.
static func _add_trim_band(root: StaticBody3D, w: float, y_top: float, mat: StandardMaterial3D) -> void:
	var band_h: float = 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w + 0.16, band_h, w + 0.16)  # slight overhang so it reads as a ledge
	bm.material = mat
	mi.mesh = bm
	mi.position = Vector3(0.0, y_top - band_h * 0.5, 0.0)
	root.add_child(mi)


## Emissive window grids on all four faces of a tier. Most glow warm, some dark.
## Each face uses ONE MeshInstance3D per row-color group is avoided — instead we
## use a small grid of thin emissive quads but cap density to stay within budget.
static func _add_windows(root: StaticBody3D, w: float, h: float, y_base: float, rng: RandomNumberGenerator) -> void:
	var rows: int = clampi(int(h / STOREY_H), 1, MAX_WINDOW_ROWS_PER_TIER)
	var cols: int = clampi(int(w / 2.5), 2, MAX_WINDOW_COLS)
	var win_w: float = w / float(cols) * 0.52
	var win_h: float = STOREY_H * 0.5
	var margin: float = 0.04  # push windows just proud of the wall to avoid z-fighting
	var half: float = w * 0.5

	# Faces: +Z, -Z, +X, -X. For +/-Z windows span the X axis; for +/-X they span Z.
	for face in 4:
		var on_z: bool = face < 2
		var sign: float = 1.0 if (face % 2 == 0) else -1.0
		for r in rows:
			var cy: float = y_base + (float(r) + 0.5) * STOREY_H
			for c in cols:
				var lit: bool = rng.randf() < WINDOW_LIT_CHANCE
				var slot: float = (float(c) - float(cols - 1) * 0.5) * (w / float(cols))
				var mi := MeshInstance3D.new()
				mi.mesh = _shared_quad()
				mi.material_override = (_lit_mat(rng) if lit else _dark_mat())
				if on_z:
					mi.position = Vector3(slot, cy, sign * (half + margin))
					mi.rotation_degrees = Vector3(0.0, 0.0 if sign > 0.0 else 180.0, 0.0)
				else:
					mi.position = Vector3(sign * (half + margin), cy, slot)
					mi.rotation_degrees = Vector3(0.0, 90.0 if sign > 0.0 else -90.0, 0.0)
				root.add_child(mi)


## Roof feature: flat (nothing), pyramid (PrismMesh), water tank (cylinder),
## or antenna mast (thin box). Built on top of the highest tier.
static func _add_roof(root: StaticBody3D, w: float, y_top: float, body_color: Color, rng: RandomNumberGenerator) -> void:
	var roll: float = rng.randf()
	if roll < 0.30:
		# Slanted pyramid / hip roof.
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(w, STOREY_H * 1.1, w)
		pm.material = _solid_mat(body_color.darkened(0.28), 0.9, 0.0)
		mi.mesh = pm
		mi.position = Vector3(0.0, y_top + STOREY_H * 0.55, 0.0)
		root.add_child(mi)
	elif roll < 0.58:
		# Rooftop water tank (cylinder) on stubby legs implied by offset.
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var tank_r: float = w * 0.18
		cm.top_radius = tank_r
		cm.bottom_radius = tank_r
		cm.height = STOREY_H * 0.9
		cm.material = _solid_mat(Color("#7A6A52"), 0.8, 0.1)
		mi.mesh = cm
		mi.position = Vector3(w * 0.18, y_top + cm.height * 0.5 + 0.3, -w * 0.18)
		root.add_child(mi)
	elif roll < 0.80:
		# Antenna / comms mast with a small blinking-style red beacon tip.
		var mast := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, STOREY_H * 1.6, 0.18)
		bm.material = _solid_mat(Color("#3A3D44"), 0.6, 0.3)
		mast.mesh = bm
		mast.position = Vector3(0.0, y_top + bm.size.y * 0.5, 0.0)
		root.add_child(mast)
		var beacon := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		sm.material = _emission_mat(Color("#FF3B30"), 2.4)
		beacon.mesh = sm
		beacon.position = Vector3(0.0, y_top + bm.size.y + 0.1, 0.0)
		root.add_child(beacon)
	# else: flat roof — leave bare (the trim band already caps it cleanly).


# ── Materials ─────────────────────────────────────────────────────────────────

## Shared window resources — one quad + a few materials reused across ALL
## buildings (was one mesh+material per window → thousands of allocations).
static var _quad: QuadMesh = null
static var _lit_cache: Array[StandardMaterial3D] = []
static var _dark_cache: StandardMaterial3D = null

static func _shared_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(0.9, 1.4)
	return _quad

static func _lit_mat(rng: RandomNumberGenerator) -> StandardMaterial3D:
	if _lit_cache.is_empty():
		for g in GLOW_WARM:
			var m := StandardMaterial3D.new()
			m.albedo_color = g
			m.emission_enabled = true
			m.emission = g
			m.emission_energy_multiplier = 2.0
			m.roughness = 0.3
			_lit_cache.append(m)
	return _lit_cache[rng.randi() % _lit_cache.size()]

static func _dark_mat() -> StandardMaterial3D:
	if _dark_cache == null:
		_dark_cache = StandardMaterial3D.new()
		_dark_cache.albedo_color = GLOW_DARK
		_dark_cache.roughness = 0.2
		_dark_cache.metallic = 0.35
	return _dark_cache

static func _solid_mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## A window quad — lit windows glow warm (emission); dark windows are dim glass.
static func _window_mat(lit: bool, rng: RandomNumberGenerator) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if lit:
		var glow: Color = GLOW_WARM[rng.randi_range(0, GLOW_WARM.size() - 1)]
		m.albedo_color = glow
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = rng.randf_range(1.4, 2.4)
		m.roughness = 0.3
	else:
		m.albedo_color = GLOW_DARK
		m.roughness = 0.2
		m.metallic = 0.35
	return m


static func _emission_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
