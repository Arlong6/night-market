## Background "shopper" NPC for Night Market Shopping (v0.17).
##
## Pure atmosphere — walks horizontally along a fixed Y lane, wraps around
## when they reach the edge. No collision, no dialogue, no grid snap. Adds
## crowd life to the otherwise static market.
##
## Spawned by `ShilinMarket._spawn_shoppers()` with varied speed / colour /
## direction so the lanes don't look choreographed.
class_name WanderShopper
extends Node2D

# ---------------------------------------------------------------------------
# Kinds (v0.36)
# ---------------------------------------------------------------------------
#
# Each shopper picks one silhouette style so the crowd doesn't look like
# a row of clones. All kinds share the same walk-cycle + lane logic; only
# the _draw branch differs. New kinds: append here, add a draw helper
# below, and update SHOPPER_DATA in shilin_market.gd.

enum Kind {
	ADULT,        ## default — original v0.17 silhouette
	GRANNY,       ## hunched, taller hat, slower default speed
	BUSINESSMAN,  ## briefcase blob beside leg
	KID,          ## smaller body, taller head proportionally
	COUPLE,       ## two heads / two bodies side by side
}

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## How long each leg-alternation step takes. Combined with `speed` this gives
## the visible cadence of the walk cycle.
const STEP_PERIOD: float = 0.32

## Width of the silhouette in pixels.
const SHOPPER_W: int = 8

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Walking speed in px/sec along the lane.
@export var speed: float = 18.0

## Horizontal travel range. The shopper wraps when leaving this band so they
## reappear from the opposite edge.
@export var x_min: float = 16.0
@export var x_max: float = 384.0

## Y lane (world px). Shopper stays at this Y the whole time.
@export var lane_y: float = 100.0

## 1 = walking right, -1 = walking left.
@export var direction: int = 1

## Shirt / body colour. Each shopper picks a different value for variety.
@export var body_color: Color = Color("#5A8A5A")

## Hair / hat colour drawn as a 2px stripe at the top of the head.
@export var hat_color: Color = Color("#2A1A0A")

## v0.36: silhouette style. See `Kind` enum at the top of the file.
@export var kind: Kind = Kind.ADULT

## v0.36: secondary accent colour — used for granny's shawl, businessman's
## briefcase, the couple's second body. Default falls back to a darker
## tint of body_color in _draw if not overridden.
@export var accent_color: Color = Color("#5A2A2A")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _x: float = 0.0
var _t: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_x = x_min if direction > 0 else x_max
	position = Vector2(roundf(_x), lane_y)


func _process(delta: float) -> void:
	# Test mode: freeze so unit tests aren't time-dependent.
	if Game.test_mode:
		return
	_x += speed * delta * float(direction)
	if direction > 0 and _x > x_max:
		_x = x_min
	elif direction < 0 and _x < x_min:
		_x = x_max
	_t += delta
	position = Vector2(roundf(_x), lane_y)
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing — small humanoid silhouette with a 2-step walk cycle
# ---------------------------------------------------------------------------

const COLOR_SKIN: Color = Color("#F2D6A8")

## v0.43 — per-kind umbrella canopy colours so a rainy market doesn't look
## like everyone shopped at the same convenience store.
const UMBRELLA_COLORS: Dictionary = {
	Kind.ADULT:       Color("#3A8AC0"),  ## blue
	Kind.GRANNY:      Color("#D8C040"),  ## yellow plastic
	Kind.BUSINESSMAN: Color("#1A1A1A"),  ## black office umbrella
	Kind.KID:         Color("#D04848"),  ## bright red
	Kind.COUPLE:      Color("#A040A0"),  ## shared purple
}

func _draw() -> void:
	# 2-step walk via a step phase in {0, 1}; alternates legs each step.
	var step_phase: int = int(_t / STEP_PERIOD * 2.0) % 2
	var bob_y: float = -1.0 if step_phase == 0 else 0.0
	match kind:
		Kind.GRANNY:      _draw_granny(step_phase, bob_y)
		Kind.BUSINESSMAN: _draw_businessman(step_phase, bob_y)
		Kind.KID:         _draw_kid(step_phase, bob_y)
		Kind.COUPLE:      _draw_couple(step_phase, bob_y)
		_:                _draw_adult(step_phase, bob_y)
	# v0.43 — every shopper carries an umbrella when it's raining or storming.
	# COUPLE gets a wider shared umbrella; everyone else uses the standard one.
	_draw_umbrella(bob_y)


## Original v0.17 silhouette — adult shopper.
func _draw_adult(step_phase: int, bob_y: float) -> void:
	# Head (6×4) + hair stripe (6×2)
	draw_rect(Rect2(-3, -6 + bob_y, 6, 4), COLOR_SKIN)
	draw_rect(Rect2(-3, -6 + bob_y, 6, 2), hat_color)
	# Body (6×4)
	draw_rect(Rect2(-3, -2 + bob_y, 6, 4), body_color)
	# Legs alternate width so it looks like one foot is forward
	var legs: Color = body_color.darkened(0.35)
	if step_phase == 0:
		draw_rect(Rect2(-2, 2 + bob_y, 2, 3), legs)
		draw_rect(Rect2(1, 2 + bob_y, 1, 3), legs)
	else:
		draw_rect(Rect2(-2, 2 + bob_y, 1, 3), legs)
		draw_rect(Rect2(0, 2 + bob_y, 2, 3), legs)


## 阿嬤 — slightly hunched, white-grey hair, draped accent shawl.
func _draw_granny(step_phase: int, bob_y: float) -> void:
	# Hunch — head sits 1px lower than adult.
	# White-grey hair stripe (use hat_color but lighten slightly).
	var hair: Color = hat_color.lightened(0.55)
	# Head
	draw_rect(Rect2(-3, -5 + bob_y, 6, 4), COLOR_SKIN)
	# Hair (rounded — 2 px stripe with side stubs)
	draw_rect(Rect2(-3, -5 + bob_y, 6, 2), hair)
	draw_rect(Rect2(-3, -3 + bob_y, 1, 1), hair)
	draw_rect(Rect2(2, -3 + bob_y, 1, 1), hair)
	# Body
	draw_rect(Rect2(-3, -1 + bob_y, 6, 4), body_color)
	# Shawl drape across shoulders (accent stripe over body top)
	draw_rect(Rect2(-3, -1 + bob_y, 6, 1), accent_color)
	draw_rect(Rect2(-4, 0 + bob_y, 1, 2), accent_color)
	draw_rect(Rect2(3, 0 + bob_y, 1, 2), accent_color)
	# Cane — diagonal stick to the right of body
	draw_rect(Rect2(3, -1 + bob_y, 1, 1), Color("#3A1A0A"))
	draw_rect(Rect2(4, 0 + bob_y, 1, 4), Color("#3A1A0A"))
	# Slow shuffly legs (smaller stride, both same width)
	var legs: Color = body_color.darkened(0.4)
	if step_phase == 0:
		draw_rect(Rect2(-2, 3 + bob_y, 2, 2), legs)
		draw_rect(Rect2(1, 3 + bob_y, 1, 2), legs)
	else:
		draw_rect(Rect2(-2, 3 + bob_y, 1, 2), legs)
		draw_rect(Rect2(0, 3 + bob_y, 2, 2), legs)


## 上班族 — square-shoulder body + briefcase blob beside the trailing leg.
func _draw_businessman(step_phase: int, bob_y: float) -> void:
	# Standard adult silhouette as base
	draw_rect(Rect2(-3, -6 + bob_y, 6, 4), COLOR_SKIN)
	draw_rect(Rect2(-3, -6 + bob_y, 6, 2), hat_color)
	# Body — slightly squarer (extra 1px shoulders)
	draw_rect(Rect2(-4, -2 + bob_y, 8, 4), body_color)
	# Tie stripe down the middle
	draw_rect(Rect2(0, -2 + bob_y, 1, 3), accent_color)
	# Legs (same alternating walk)
	var legs: Color = body_color.darkened(0.45)
	if step_phase == 0:
		draw_rect(Rect2(-2, 2 + bob_y, 2, 3), legs)
		draw_rect(Rect2(1, 2 + bob_y, 1, 3), legs)
	else:
		draw_rect(Rect2(-2, 2 + bob_y, 1, 3), legs)
		draw_rect(Rect2(0, 2 + bob_y, 2, 3), legs)
	# Briefcase swings on the side opposite to the leading foot.
	# 1 px handle + 3×2 box, brown-leather coloured.
	var case_x: float = 3.0 if direction > 0 else -5.0
	draw_rect(Rect2(case_x, -1 + bob_y, 1, 1), Color("#5A2A12"))      # handle
	draw_rect(Rect2(case_x - 1, 0 + bob_y, 3, 2), Color("#8A4A22"))   # body
	draw_rect(Rect2(case_x - 1, 0 + bob_y, 3, 1), Color("#5A2A12"))   # rim


## 小朋友 — shorter body, slightly larger head proportionally, faster bounce.
func _draw_kid(step_phase: int, bob_y: float) -> void:
	# Bob harder so the kid looks like they're skipping
	var kbob: float = bob_y - (1.0 if step_phase == 0 else 0.0)
	# Head (5×4) — relatively bigger vs body
	draw_rect(Rect2(-3, -5 + kbob, 6, 4), COLOR_SKIN)
	draw_rect(Rect2(-3, -5 + kbob, 6, 2), hat_color)
	# Tiny tuft of hair on top
	draw_rect(Rect2(-1, -6 + kbob, 2, 1), hat_color)
	# Smaller body (4×3)
	draw_rect(Rect2(-2, -1 + kbob, 4, 3), body_color)
	# Legs (only 2 px tall — kid is shorter)
	var legs: Color = body_color.darkened(0.35)
	if step_phase == 0:
		draw_rect(Rect2(-2, 2 + kbob, 1, 2), legs)
		draw_rect(Rect2(1, 2 + kbob, 1, 2), legs)
	else:
		draw_rect(Rect2(-2, 2 + kbob, 1, 2), legs)
		draw_rect(Rect2(1, 2 + kbob, 1, 2), legs)


## 情侶 — two figures side by side, second one drawn in accent_color.
## Slightly wider footprint; both bob in lockstep so it reads as one unit.
func _draw_couple(step_phase: int, bob_y: float) -> void:
	# Left partner — body_color
	draw_rect(Rect2(-5, -6 + bob_y, 4, 4), COLOR_SKIN)
	draw_rect(Rect2(-5, -6 + bob_y, 4, 2), hat_color)
	draw_rect(Rect2(-5, -2 + bob_y, 4, 4), body_color)
	# Right partner — accent_color
	draw_rect(Rect2(1, -6 + bob_y, 4, 4), COLOR_SKIN)
	draw_rect(Rect2(1, -6 + bob_y, 4, 2), hat_color.lightened(0.3))
	draw_rect(Rect2(1, -2 + bob_y, 4, 4), accent_color)
	# Holding hands — single pixel between them at body height
	draw_rect(Rect2(-1, 0 + bob_y, 2, 1), COLOR_SKIN)
	# Four legs (alternating)
	var legs_l: Color = body_color.darkened(0.35)
	var legs_r: Color = accent_color.darkened(0.35)
	if step_phase == 0:
		draw_rect(Rect2(-5, 2 + bob_y, 2, 3), legs_l)
		draw_rect(Rect2(-2, 2 + bob_y, 1, 3), legs_l)
		draw_rect(Rect2(1, 2 + bob_y, 2, 3), legs_r)
		draw_rect(Rect2(4, 2 + bob_y, 1, 3), legs_r)
	else:
		draw_rect(Rect2(-5, 2 + bob_y, 1, 3), legs_l)
		draw_rect(Rect2(-3, 2 + bob_y, 2, 3), legs_l)
		draw_rect(Rect2(1, 2 + bob_y, 1, 3), legs_r)
		draw_rect(Rect2(3, 2 + bob_y, 2, 3), legs_r)


# ---------------------------------------------------------------------------
# Umbrella (v0.43)
# ---------------------------------------------------------------------------

## Draws a small umbrella above the shopper's head when the current weather
## is non-sunny. Reads /root/Inventory.current_weather() so the rain mode is
## a single source of truth (set in inventory.gd v0.42). COUPLE gets a wider
## shared umbrella (10px canopy) since they have two heads.
func _draw_umbrella(bob_y: float) -> void:
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv == null or not inv.has_method("current_weather"):
		return
	var weather: String = inv.current_weather()
	if weather == inv.WEATHER_SUNNY:
		return
	var canopy: Color = UMBRELLA_COLORS.get(kind, Color("#3A8AC0"))
	# Typhoon mode darkens the canopy slightly so a stormy crowd reads moodier
	# than a normal shower.
	if weather == inv.WEATHER_TYPHOON:
		canopy = canopy.darkened(0.20)
	var rim: Color = canopy.darkened(0.30)
	# Couple gets a wider canopy so it shelters both heads.
	if kind == Kind.COUPLE:
		# Spike + wide canopy centred over the gap between the two heads.
		draw_rect(Rect2(0, -13 + bob_y, 1, 1), rim)
		draw_rect(Rect2(-5, -12 + bob_y, 11, 1), canopy)
		draw_rect(Rect2(-6, -11 + bob_y, 13, 1), canopy)
		draw_rect(Rect2(-6, -11 + bob_y, 1, 1), rim)
		draw_rect(Rect2(6, -11 + bob_y, 1, 1), rim)
		# Pole reaches between the two heads (which top out at y≈-6).
		draw_rect(Rect2(0, -10 + bob_y, 1, 4), Color("#3A1A0A"))
		return
	# Standard 7-wide canopy (matches PlayerGrid umbrella shape).
	draw_rect(Rect2(0, -13 + bob_y, 1, 1), rim)
	draw_rect(Rect2(-3, -12 + bob_y, 7, 1), canopy)
	draw_rect(Rect2(-4, -11 + bob_y, 9, 1), canopy)
	draw_rect(Rect2(-4, -11 + bob_y, 1, 1), rim)
	draw_rect(Rect2(4, -11 + bob_y, 1, 1), rim)
	draw_rect(Rect2(0, -10 + bob_y, 1, 4), Color("#3A1A0A"))
