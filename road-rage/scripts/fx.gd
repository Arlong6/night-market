## FX — one-shot particle bursts + physics debris chunks (橫衝直撞).
class_name FX
extends RefCounted

static func burst(parent: Node, pos: Vector2, color: Color, count: int = 16) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = color
	p.emitting = true
	parent.add_child(p)
	parent.get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())

static func debris(parent: Node, pos: Vector2, color: Color, chunks: int = 5) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for i in chunks:
		var r := RigidBody2D.new()
		r.position = pos
		r.gravity_scale = 0.0
		r.linear_damp = 2.5
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.0
		col.shape = shape
		col.disabled = true   # debris is purely visual
		r.add_child(col)
		var poly := Polygon2D.new()
		var s: float = randf_range(2.0, 5.0)
		poly.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		poly.color = color
		r.add_child(poly)
		parent.add_child(r)
		r.linear_velocity = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(120.0, 320.0)
		r.angular_velocity = randf_range(-12.0, 12.0)
		var t := r.create_tween()
		t.tween_interval(0.4)
		t.tween_property(r, "modulate:a", 0.0, 0.5)
		t.tween_callback(func() -> void:
			if is_instance_valid(r): r.queue_free())
