## Floor item pickup for Night Market Shopping (v0.2 content pass).
##
## Sits on a single grid cell (walkable). When the player's cell_changed
## signal fires for this cell, the level credits the item's value to
## Inventory.money, spawns a sparkle FX, and frees this node. Pure cosmetic
## otherwise — no collision, no Area2D needed.
class_name ItemPickup
extends Node2D

const ITEM_SIZE: float = 6.0
const PULSE_PERIOD: float = 0.6  ## seconds for one breathing cycle

@export var cell: Vector2i = Vector2i(0, 0)
@export var value: int = 10            ## money awarded on pickup
@export var pickup_line: String = ""   ## optional dialogue ("撿到 $10")
@export var color: Color = Color("#F2A227")  ## gold default

var _t: float = 0.0


func _ready() -> void:
	position = GridWorld.cell_to_px(cell)
	_t = randf() * PULSE_PERIOD


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Sin-driven pulse: size oscillates by ±1px so item "breathes".
	var phase: float = (_t / PULSE_PERIOD) * TAU
	var pulse: float = roundf(sin(phase))  # ∈ {-1, 0, 1}
	var size: float = ITEM_SIZE + pulse
	var half: float = size / 2.0
	# Body
	draw_rect(Rect2(-half, -half, size, size), color)
	# Single-pixel highlight in the upper-left
	draw_rect(Rect2(-half, -half, 1.0, 1.0), Color("#FFFFFF"))


## Called by the level when the player steps onto this cell. Awards money
## via Inventory, spawns a sparkle, optionally shows pickup dialogue, then
## queue_frees self. Returns true if pickup happened.
func collect() -> bool:
	# Direct write — Inventory.buy is for ingredients, not free money.
	Inventory.money += value
	Inventory.money_changed.emit(Inventory.money)
	_spawn_sparkle()
	Sfx.play_pickup()
	if pickup_line != "" and not Dialogue.is_active():
		Dialogue.show([pickup_line])
	queue_free()
	return true


func _spawn_sparkle() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = position
	burst.count = 5
	burst.color = color
	burst.speed_min = 30.0
	burst.speed_max = 70.0
	burst.particle_size = 2.0
	burst.lifetime = 0.30
	burst.gravity_scale = 0.3
	burst.upward_bias = 0.7
	parent.add_child(burst)
