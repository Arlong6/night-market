## Follower cat for Night Market Shopping (v0.50).
##
## Pure flavour pet — once the player has rescued at least one 走丟的小貓
## (HiScore.cat_rescues >= 1), a tabby trots out at HOME_CELL on every
## market spawn and follows the player around at a 2-cell delay. No
## collision, no dialogue, no gameplay effect — just companionship.
##
## Movement style: trails the player's recent cells via a small ring buffer
## so the cat steps onto a cell ~2 player-steps after the player did, with
## a 0.18s tween (matches PlayerGrid.STEP_DURATION) for a glued-on feel.
class_name FollowerCat
extends Node2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## How many player-steps behind the cat trails. 2 = cat steps onto a cell
## that the player vacated 2 steps ago. Bigger = lazier; smaller = clingy.
const FOLLOW_DELAY: int = 2

## Tween length per cell-to-cell hop. Matches the player's STEP_DURATION
## so the cat stays at a fixed visual distance during sustained movement.
const STEP_DURATION: float = 0.18

# ---------------------------------------------------------------------------
# Visuals — tabby palette
# ---------------------------------------------------------------------------

const COLOR_FUR: Color = Color("#C8884A")        ## warm tabby orange
const COLOR_FUR_STRIPE: Color = Color("#8A4A22") ## darker stripes
const COLOR_PAW: Color = Color("#E8C8A8")        ## pale belly / paws
const COLOR_NOSE: Color = Color("#3A1A0A")
const COLOR_EYE: Color = Color("#3A1A0A")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Sequence of recent cells the player visited. Index 0 = current player
## cell; we step onto _trail[FOLLOW_DELAY] when it's full enough.
var _trail: Array[Vector2i] = []
var _cell: Vector2i = Vector2i.ZERO
var _is_stepping: bool = false
## Tail wag accumulator (free-running so it twitches even when stationary).
var _t: float = 0.0
## Last facing direction (drives the side-aware sprite). Defaults to facing right.
var _facing: Vector2i = Vector2i.RIGHT


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Configures the cat to spawn at the same cell as the player and starts
## listening to cell_changed signals so the trail builds up.
func configure(player: PlayerGrid) -> void:
	_cell = player.cell
	position = GridWorld.cell_to_px(_cell)
	# Seed trail with the player's spawn cell repeated so the first few
	# steps don't drag the cat awkwardly across the map.
	_trail.clear()
	for i in FOLLOW_DELAY + 1:
		_trail.append(player.cell)
	player.cell_changed.connect(_on_player_cell_changed)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Game.test_mode:
		return
	_t += delta
	queue_redraw()


# ---------------------------------------------------------------------------
# Trail logic
# ---------------------------------------------------------------------------

func _on_player_cell_changed(new_player_cell: Vector2i) -> void:
	# Push the new cell onto the front; trail length stays bounded.
	_trail.push_front(new_player_cell)
	if _trail.size() > FOLLOW_DELAY + 2:
		_trail.pop_back()
	# Step the cat onto the trail-delayed cell if we're not mid-tween.
	if _is_stepping:
		return
	var target_index: int = mini(FOLLOW_DELAY, _trail.size() - 1)
	var target: Vector2i = _trail[target_index]
	if target == _cell:
		return
	_facing = (target - _cell)
	# Sometimes the player teleports (level reset) — clamp facing to ±1 so
	# diagonal jumps don't read as weird sprite flips.
	if _facing.x != 0:
		_facing.x = sign(_facing.x)
	if _facing.y != 0:
		_facing.y = sign(_facing.y)
	_cell = target
	_is_stepping = true
	var tween: Tween = create_tween()
	tween.tween_property(
		self, "position", GridWorld.cell_to_px(target), STEP_DURATION
	)
	tween.tween_callback(_on_step_finished)


func _on_step_finished() -> void:
	_is_stepping = false


# ---------------------------------------------------------------------------
# Drawing — small tabby cat with twitching tail
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Tail wag: small horizontal sin wobble that runs even when stationary.
	var wag: float = roundf(sin(_t * 5.0) * 1.0)
	var bob: float = -1.0 if (sin(_t * 3.0) > 0.4) else 0.0
	var face_x: int = 1 if _facing.x >= 0 else -1
	# Body — 6×3 oval-ish flat cat
	draw_rect(Rect2(-3.0, 1.0 + bob, 6.0, 3.0), COLOR_FUR)
	# Belly stripe (1 px lighter)
	draw_rect(Rect2(-2.0, 3.0 + bob, 4.0, 1.0), COLOR_PAW)
	# Tabby stripes — two darker columns on the body
	draw_rect(Rect2(-1.0, 1.0 + bob, 1.0, 2.0), COLOR_FUR_STRIPE)
	draw_rect(Rect2(1.0, 1.0 + bob, 1.0, 2.0), COLOR_FUR_STRIPE)
	# Head — 3×3 to the facing side
	var head_x: float = 1.0 if face_x > 0 else -4.0
	draw_rect(Rect2(head_x, -1.0 + bob, 3.0, 3.0), COLOR_FUR)
	# Ears — two 1×1 triangles on top of head (stand-ins as squares)
	draw_rect(Rect2(head_x, -2.0 + bob, 1.0, 1.0), COLOR_FUR)
	draw_rect(Rect2(head_x + 2.0, -2.0 + bob, 1.0, 1.0), COLOR_FUR)
	# Eyes — 1px dots, biased to the facing side
	var eye_x: float = head_x + (1.0 if face_x > 0 else 1.0)
	draw_rect(Rect2(eye_x, 0.0 + bob, 1.0, 1.0), COLOR_EYE)
	# Nose — single dark pixel between eyes/below
	draw_rect(Rect2(head_x + 1.0, 1.0 + bob, 1.0, 1.0), COLOR_NOSE)
	# Tail — 3px segments curling back from the body's trailing side
	var tail_x: float = -4.0 if face_x > 0 else 3.0
	draw_rect(Rect2(tail_x, 1.0 + bob, 1.0, 1.0), COLOR_FUR)
	draw_rect(Rect2(tail_x - (1.0 if face_x > 0 else -1.0),
		0.0 + bob + wag, 1.0, 1.0), COLOR_FUR)
	# Paws — two 1px dots peeking out below the body
	draw_rect(Rect2(-2.0, 4.0 + bob, 1.0, 1.0), COLOR_PAW)
	draw_rect(Rect2(1.0, 4.0 + bob, 1.0, 1.0), COLOR_PAW)
