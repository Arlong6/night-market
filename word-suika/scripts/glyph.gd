## Glyph — single character in the Word Suika container.
##
## A RigidBody2D with a CircleShape2D collider + a Label showing the
## tier's character. On collision with same-tier glyph, requests a merge
## from the Main scene (which dedupes to one merge per pair).
class_name Glyph
extends RigidBody2D

const TierData = preload("res://scripts/tier_data.gd")

## Which tier this glyph belongs to (0-indexed, 0..TIER_COUNT-1).
@export var tier: int = 0:
	set(value):
		tier = clampi(value, 0, TierData.TIER_COUNT - 1)
		_apply_tier()

## Set true after the manager schedules merge — prevents double-merging.
var _merging: bool = false

var _shape: CircleShape2D = null
var _collider: CollisionShape2D = null
var _label: Label = null
var _back_circle: Node2D = null

## Signal emitted on collision with same-tier glyph.
## Main listens, dedupes pairs, and triggers _merge_with().
signal collided_same_tier(other: Glyph)

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	# Bouncier "drop" feel — small bounce + low damp so glyphs visibly settle
	# with a bit of life. Heavy damping killed the playful Suika feel.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.55
	physics_material_override.bounce = 0.12
	linear_damp = 0.1
	angular_damp = 0.4
	_apply_tier()

func _apply_tier() -> void:
	# Lazy create children (since setter may fire pre-_ready)
	if _shape == null:
		_shape = CircleShape2D.new()
	if _collider == null:
		_collider = CollisionShape2D.new()
		_collider.shape = _shape
		add_child(_collider)
	if _back_circle == null:
		_back_circle = Node2D.new()
		_back_circle.name = "Back"
		_back_circle.set_script(preload("res://scripts/glyph_drawer.gd"))
		_back_circle.set("glyph", self)
		add_child(_back_circle)
	if _label == null:
		_label = Label.new()
		_label.name = "Char"
		_label.add_theme_color_override("font_color", Color(0.10, 0.07, 0.04, 1.0))
		_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.5))
		_label.add_theme_constant_override("outline_size", 4)
		add_child(_label)
	# Apply tier visuals + physics
	var data: Dictionary = TierData.get_tier(tier)
	_shape.radius = data.radius
	# Label size scales with tier; centered on the body.
	var font_size: int = int(data.radius * 1.05)
	_label.text = data.char
	_label.add_theme_font_size_override("font_size", font_size)
	_label.size = Vector2(data.radius * 2.4, data.radius * 2.4)
	_label.position = -_label.size * 0.5
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Mass scales by area (tier^2-ish), heavier higher tiers settle faster.
	mass = max(1.0, pow(data.radius / 32.0, 2.0))
	if _back_circle:
		_back_circle.queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _merging:
		return
	if not body is Glyph:
		return
	var other: Glyph = body
	if other._merging:
		return
	if other.tier != tier:
		return
	# Defer dedup to the Main manager via signal.
	collided_same_tier.emit(other)

## Called by Main when a merge is committed — prevents further merges
## while we wait to be freed.
func mark_merging() -> void:
	_merging = true
	# Visual hint: shrink + fade slightly before disappearing.
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.4, 0.4), 0.08)
	t.tween_property(self, "modulate:a", 0.0, 0.05)

func is_merging() -> bool:
	return _merging
