## Lost cat — random street event for Night Market Shopping (v0.21).
##
## Spawns at a random walkable cell with ~25% chance per run. Bumping the
## cat asks the player whether to return it to its owner; saying 是 awards
## a small reward and despawns the cat. 否 leaves the cat sitting there.
##
## Pure visual + dialogue. Doesn't shift any persistent state — the reward
## is just an immediate Inventory.money credit.
class_name LostCat
extends Node2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted just before the cat queue_free's itself, so the level can free up
## the cell (mark walkable again, drop from _lost_cats_by_cell).
signal despawned(cell: Vector2i)

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Reward in NT$ when the player returns the cat.
const REWARD: int = 20

## Per-cycle period for the idle bob (slightly different from NPCs so they
## don't move in lockstep).
const BOB_PERIOD: float = 0.45

## Tail wag period — slower than the bob for a relaxed feel.
const TAIL_PERIOD: float = 0.9

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_BODY: Color = Color("#E8A050")        ## tabby orange
const COLOR_BODY_SHADOW: Color = Color("#A86028") ## belly / underside
const COLOR_STRIPE: Color = Color("#7A4020")      ## tabby stripe brown
const COLOR_INK: Color = Color("#2A1408")         ## eyes + ear edge
const COLOR_BLUSH: Color = Color("#FFB0A0")       ## tiny pink nose

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Grid cell this cat sits on.
@export var cell: Vector2i = Vector2i(0, 0)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _t: float = 0.0
var _despawning: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	position = GridWorld.cell_to_px(cell)
	_t = randf() * BOB_PERIOD


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing — small tabby kitten silhouette with bobbing head + tail wag
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bob_phase: float = (_t / BOB_PERIOD) * TAU
	var bob: float = roundf(sin(bob_phase))  # {-1, 0, 1}
	var tail_phase: float = (_t / TAIL_PERIOD) * TAU
	var tail_offset: int = int(roundf(sin(tail_phase) * 1.0))

	# Body — 8×4 oval-ish shape sitting on the cell
	draw_rect(Rect2(-4.0, -1.0 + bob, 8.0, 4.0), COLOR_BODY)
	# Belly shadow (bottom 1px)
	draw_rect(Rect2(-4.0, 2.0 + bob, 8.0, 1.0), COLOR_BODY_SHADOW)
	# Tabby stripes — 3 short lines on the back
	draw_rect(Rect2(-3.0, -1.0 + bob, 1.0, 1.0), COLOR_STRIPE)
	draw_rect(Rect2(-1.0, -1.0 + bob, 1.0, 1.0), COLOR_STRIPE)
	draw_rect(Rect2(1.0, -1.0 + bob, 1.0, 1.0), COLOR_STRIPE)
	# Head — 5×4 perched on the front
	draw_rect(Rect2(2.0, -3.0 + bob, 5.0, 4.0), COLOR_BODY)
	# Ears — two small triangles approximated with 1×1 dots
	draw_rect(Rect2(2.0, -4.0 + bob, 1.0, 1.0), COLOR_BODY)
	draw_rect(Rect2(6.0, -4.0 + bob, 1.0, 1.0), COLOR_BODY)
	draw_rect(Rect2(2.0, -3.0 + bob, 1.0, 1.0), COLOR_INK)
	draw_rect(Rect2(6.0, -3.0 + bob, 1.0, 1.0), COLOR_INK)
	# Eyes
	draw_rect(Rect2(3.0, -2.0 + bob, 1.0, 1.0), COLOR_INK)
	draw_rect(Rect2(5.0, -2.0 + bob, 1.0, 1.0), COLOR_INK)
	# Nose
	draw_rect(Rect2(4.0, -1.0 + bob, 1.0, 1.0), COLOR_BLUSH)
	# Tail — wags side to side at the back
	var tail_x: float = -5.0 + float(tail_offset)
	draw_rect(Rect2(tail_x, -2.0 + bob, 1.0, 4.0), COLOR_BODY)
	draw_rect(Rect2(tail_x - 1.0, -3.0 + bob, 1.0, 1.0), COLOR_BODY)
	# Legs hint — 2 small darker dots underneath
	draw_rect(Rect2(-2.0, 3.0 + bob, 1.0, 1.0), COLOR_BODY_SHADOW)
	draw_rect(Rect2(2.0, 3.0 + bob, 1.0, 1.0), COLOR_BODY_SHADOW)


# ---------------------------------------------------------------------------
# Bump handler — opens "幫主人找到？" choice
# ---------------------------------------------------------------------------

## Called by ShilinMarket when the player bumps the cat's cell.
func on_bumped() -> void:
	if _despawning:
		return
	if Dialogue.is_active():
		return
	var question: String = "啊，這隻小貓走丟了！要幫忙送回去嗎？"
	Dialogue.ask_choice(question, ["是", "否"], _on_choice)


func _on_choice(index: int) -> void:
	if index != 0:
		Dialogue.show(["好喔…那再見了小貓"])
		return
	# 是 — give the reward and despawn the cat with a thank-you.
	Inventory.money += REWARD
	Inventory.money_changed.emit(Inventory.money)
	Sfx.play_pickup()
	_spawn_sparkle()
	_despawning = true
	# v0.50: record the rescue so the kid earns a follower cat at home from
	# the next run onwards. Cumulative across runs.
	HiScore.record_cat_rescue()
	var freed_cell: Vector2i = cell
	var on_done: Callable = func() -> void:
		if is_instance_valid(self):
			despawned.emit(freed_cell)
			queue_free()
	Dialogue.show(
		["喵～找到主人了！", "謝謝你～這 NT$%d 給你！" % REWARD], on_done
	)


func _spawn_sparkle() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = position
	burst.count = 6
	burst.color = Color("#F2A227")
	burst.speed_min = 30.0
	burst.speed_max = 70.0
	burst.particle_size = 2.0
	burst.lifetime = 0.4
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.7
	parent.add_child(burst)
