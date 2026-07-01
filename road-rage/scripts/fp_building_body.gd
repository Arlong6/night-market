## FPBuildingBody — a building that collapses when the car rams it at speed.
## Extends StaticBody3D so it's a solid wall until broken.
class_name FPBuildingBody
extends StaticBody3D

signal collapsed(pos: Vector3)

var broke: bool = false

## Crush the building down into rubble: drop its collision so the car barrels
## through, squash it flat with a dust burst, then remove it.
func collapse() -> void:
	if broke:
		return
	broke = true
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	_dust()
	collapsed.emit(global_position)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale:y", 0.12, 0.55).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale:x", 1.12, 0.55)
	t.tween_property(self, "scale:z", 1.12, 0.55)
	t.chain().tween_interval(0.45)
	t.chain().tween_callback(queue_free)

func _dust() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 90.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.6, 0.56, 0.85)
	var bm := BoxMesh.new()
	bm.material = m
	p.mesh = bm
	host.add_child(p)
	p.global_position = global_position + Vector3(0.0, 4.0, 0.0)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())
