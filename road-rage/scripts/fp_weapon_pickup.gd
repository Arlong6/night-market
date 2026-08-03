## FPWeaponPickup — a floating weapon crate. Walk over it on foot to permanently
## unlock that weapon (ownership lives on FPMain so it survives car trips + respawns).
class_name FPWeaponPickup
extends Area3D

signal collected(weapon_index: int, pos: Vector3)

const NAMES: Array[String] = ["手槍", "衝鋒槍", "散彈槍", "火箭筒"]
const COLORS: Array[Color] = [Color("#3B3D47"), Color("#2E2F37"), Color("#B8742E"), Color("#6FA23A")]

@export var weapon_index: int = 2

var _icon: Node3D = null
var _t: float = 0.0

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 3.0, 2.2)   # generous grab volume
	col.shape = shape
	col.position = Vector3(0.0, 1.3, 0.0)
	add_child(col)
	var tint: Color = COLORS[weapon_index]
	# Glowing base pad so the crate is easy to spot.
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 0.16
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = tint
	pmat.emission_enabled = true
	pmat.emission = tint
	pmat.emission_energy_multiplier = 0.7
	cyl.material = pmat
	pad.mesh = cyl
	pad.position = Vector3(0.0, 0.08, 0.0)
	add_child(pad)
	# Floating, spinning weapon icon.
	_icon = Node3D.new()
	_icon.position = Vector3(0.0, 1.1, 0.0)
	add_child(_icon)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.24, 0.24, 0.95)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = tint
	gmat.metallic = 0.4
	gmat.roughness = 0.5
	gm.material = gmat
	gun.mesh = gm
	_icon.add_child(gun)
	# Name floating above.
	var lbl := Label3D.new()
	lbl.text = NAMES[weapon_index]
	lbl.position = Vector3(0.0, 2.1, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 64
	lbl.modulate = Color("#FFE6A6")
	lbl.outline_size = 8
	add_child(lbl)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	if _icon != null:
		_icon.rotation.y = _t * 2.2
		_icon.position.y = 1.1 + sin(_t * 2.5) * 0.12

func _on_body_entered(body: Node) -> void:
	if body is FPWalker:
		if body.has_method("grant_weapon"):
			body.grant_weapon(weapon_index)
		collected.emit(weapon_index, global_position)
		queue_free()
