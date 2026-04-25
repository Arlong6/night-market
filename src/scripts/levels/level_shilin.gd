## Level 1 — Shilin Night Market for Night Market Runner.
##
## THE INTEGRATION LEVEL: first end-to-end playable scene. Assembles all
## systems built in Stories 001–008 into a single playable run.
##
## Signal wiring (set up in _ready):
##   Collectible.picked_up  → Game.add_score
##   Enemy.player_hit       → Game.record_death
##   Player.died            → Game.record_death
##   Goal.body_entered      → _on_goal_reached → +500 bonus + restart_level
##
## MVP shortcuts (replace in later stories):
##   - Floor/platforms are StaticBody2D ColorRects, not TileMapLayer tiles
##   - No parallax background (solid default_clear_color is the atmosphere)
##   - All entities drawn with ColorRects/_draw(), no sprite assets
##   - Goal loops the level (Game.restart_level). Story 010 intercepts for next-level flow.
##
## Story 009 — Depends on: 003 (Player), 004 (Obstacles), 005 (Enemy),
##   006 (GameCamera), 007 (Game state), 008 (HUD).
class_name LevelShilin
extends Node2D

# ---------------------------------------------------------------------------
# Level geometry constants
# ---------------------------------------------------------------------------

## Total level width in pixels. Passed to GameCamera for clamp math.
const LEVEL_WIDTH: int = 960
## Total level height in pixels (viewport height).
const LEVEL_HEIGHT: int = 180

## Y-coordinate of the floor's top surface. Player feet sit here.
## Matches the "FLOOR_TOP_Y=120" convention from all prior stories / tests.
const FLOOR_TOP_Y: float = 120.0
const FLOOR_THICKNESS: float = 40.0  ## floor body extends down 40px from top

## Shilin art-bible §4B palette.
const COLOUR_FLOOR: Color = Color("#4A2010")   ## char-smoke brown
const COLOUR_PLATFORM: Color = Color("#8B1A1A") ## brick red
const COLOUR_WALL: Color = Color("#3A1008")

# ---------------------------------------------------------------------------
# Private references (populated in _ready — programmatic build)
# ---------------------------------------------------------------------------

var _player: Player
var _camera: GameCamera
var _hud: Hud
var _collectibles_container: Node2D
var _enemies_container: Node2D
var _goal: Area2D

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_geometry()
	_spawn_collectibles()
	_spawn_obstacles()
	_spawn_enemies()
	_spawn_goal()
	_spawn_player()
	_spawn_camera()
	_spawn_hud()
	_wire_signals()


# ---------------------------------------------------------------------------
# Build helpers — called in order from _ready
# ---------------------------------------------------------------------------

## Spawns floor, left wall, and jump platforms as StaticBody2D rectangles.
## MVP: coloured rects only — real tile pass replaces in art sprint.
func _build_geometry() -> void:
	# Floor (full level width)
	_add_static_rect(
		Vector2(LEVEL_WIDTH / 2.0, FLOOR_TOP_Y + FLOOR_THICKNESS / 2.0),
		Vector2(LEVEL_WIDTH, FLOOR_THICKNESS),
		COLOUR_FLOOR
	)

	# Left wall — prevents player walking off-screen left.
	# 8px wide, full height, positioned so its right edge is at x=0.
	_add_static_rect(
		Vector2(-4.0, LEVEL_HEIGHT / 2.0),
		Vector2(8.0, LEVEL_HEIGHT),
		COLOUR_WALL
	)

	# Jump platforms — stepping stones between ground obstacles.
	var platforms: Array[Dictionary] = [
		{"x": 180.0, "y": 100.0, "w": 48.0, "h": 8.0},
		{"x": 360.0, "y": 80.0,  "w": 48.0, "h": 8.0},
		{"x": 560.0, "y": 96.0,  "w": 48.0, "h": 8.0},
		{"x": 740.0, "y": 84.0,  "w": 48.0, "h": 8.0},
	]
	for p: Dictionary in platforms:
		_add_static_rect(
			Vector2(p["x"], p["y"] + p["h"] / 2.0),
			Vector2(p["w"], p["h"]),
			COLOUR_PLATFORM
		)


## Spawns 6 Collectible instances into the Collectibles container.
## Positions reward different play styles (ground, platform, airborne).
func _spawn_collectibles() -> void:
	_collectibles_container = Node2D.new()
	_collectibles_container.name = "Collectibles"
	add_child(_collectibles_container)

	var positions: Array[Vector2] = [
		Vector2(120.0, 108.0),   # ground-level, early easy pickup
		Vector2(220.0, 120.0),   # ground, near first platform base
		Vector2(330.0, 60.0),    # airborne — reward high jump over first hanging sign
		Vector2(430.0, 120.0),   # ground, between patrol enemy zone
		Vector2(560.0, 88.0),    # platform level — land on platform to grab
		Vector2(800.0, 60.0),    # high reward near level end
	]
	for pos: Vector2 in positions:
		var c: Collectible = Collectible.new()
		c.position = pos
		_collectibles_container.add_child(c)


## Spawns ground and hanging obstacles into the Obstacles container.
func _spawn_obstacles() -> void:
	var obs_container: Node2D = Node2D.new()
	obs_container.name = "Obstacles"
	add_child(obs_container)

	# Ground obstacles — player must jump over.
	var ground_xs: Array[float] = [260.0, 460.0, 680.0]
	for gx: float in ground_xs:
		var og: ObstacleGround = ObstacleGround.new()
		# Foot sits on floor surface: position.y = FLOOR_TOP_Y (foot-centre convention).
		og.position = Vector2(gx, FLOOR_TOP_Y)
		obs_container.add_child(og)

	# Hanging obstacles — default top_y=78 blocks standing, clears ducking (Story 004 lesson).
	var hanging_xs: Array[float] = [320.0, 850.0]
	for hx: float in hanging_xs:
		var oh: ObstacleHanging = ObstacleHanging.new()
		oh.position.x = hx
		obs_container.add_child(oh)


## Spawns patrol enemies into the Enemies container.
func _spawn_enemies() -> void:
	_enemies_container = Node2D.new()
	_enemies_container.name = "Enemies"
	add_child(_enemies_container)

	# Enemy origin = centre of body; y = FLOOR_TOP_Y + BODY_H/2 = 120 + 12 = 132
	# so the enemy's bottom edge sits exactly on the floor surface.
	var enemy_data: Array[Dictionary] = [
		{"x": 400.0, "range": 50.0},
		{"x": 700.0, "range": 60.0},
	]
	for ed: Dictionary in enemy_data:
		var e: Enemy = Enemy.new()
		e.position = Vector2(ed["x"], 132.0)
		e.patrol_range = ed["range"]
		_enemies_container.add_child(e)


## Spawns the goal zone — Area2D at the level's right edge.
func _spawn_goal() -> void:
	_goal = Area2D.new()
	_goal.name = "Goal"
	_goal.monitoring = true
	_goal.collision_mask = 1

	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(16.0, 40.0)
	cs.shape = rect
	_goal.add_child(cs)

	_goal.position = Vector2(944.0, FLOOR_TOP_Y + 20.0)
	add_child(_goal)


## Spawns Player at (30, 121) — 1px embedded in floor for fast is_on_floor() latch.
func _spawn_player() -> void:
	_player = Player.new()
	_player.name = "Player"
	_player.position = Vector2(30.0, 121.0)
	add_child(_player)


## Spawns the GameCamera and assigns Player as target.
## Camera position.y is set to viewport centre (90) BEFORE add_child so that
## GameCamera._ready captures _locked_y=90 — otherwise default position.y=0
## shows world y=[-90,90] which is ABOVE our level content (floor at y=120+).
func _spawn_camera() -> void:
	_camera = GameCamera.new()
	_camera.name = "GameCamera"
	_camera.target = _player
	_camera.level_width = LEVEL_WIDTH
	_camera.position = Vector2(0.0, LEVEL_HEIGHT / 2.0)  # y=90 → view shows y=[0,180]
	add_child(_camera)


## Spawns the HUD (CanvasLayer — renders above world geometry).
func _spawn_hud() -> void:
	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)


## Connects cross-system signals. Called last so all child _ready() have run.
func _wire_signals() -> void:
	# Collectibles → score
	for child: Node in _collectibles_container.get_children():
		if child is Collectible:
			child.picked_up.connect(Game.add_score)

	# Enemies → death + juice (camera shake on contact)
	for child: Node in _enemies_container.get_children():
		if child is Enemy:
			child.player_hit.connect(Game.record_death)
			child.player_hit.connect(_on_enemy_hit_player)

	# Player life-cycle: death particles + white flash on died.
	_player.died.connect(Game.record_death)
	_player.died.connect(_on_player_died)

	# Player jump/land → dust + optional camera nudge.
	_player.jumped.connect(_on_player_jumped)
	_player.landed.connect(_on_player_landed)

	# Goal zone → victory bonus + level restart (Story 010 will intercept)
	_goal.body_entered.connect(_on_goal_reached)


# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

## Called when any physics body enters the goal zone.
## Awards 500-point victory bonus and restarts the level.
## Story 010 replaces the restart_level() call with goto_level("fengjia").
func _on_goal_reached(body: Node) -> void:
	if body is Player:
		Game.add_score(500)
		Game.goto_level("level_end")


# ---------------------------------------------------------------------------
# Juice handlers — spawn VFX in response to player / enemy events.
# All guard on camera/player being valid because scene may tear down mid-frame.
# ---------------------------------------------------------------------------

func _on_enemy_hit_player() -> void:
	if _camera != null:
		_camera.shake(3.0, 0.18)


func _on_player_died() -> void:
	if _player == null:
		return
	# Shatter-burst: 8 yellow particles plus a brief white flash overlay.
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = _player.position
	burst.count = 8
	burst.color = Color("#E8F542")
	burst.speed_min = 60.0
	burst.speed_max = 140.0
	burst.particle_size = 3.0
	burst.lifetime = 0.55
	burst.gravity_scale = 1.0
	burst.upward_bias = 0.3
	add_child(burst)

	var flash: FlashOverlay = FlashOverlay.new()
	flash.flash_color = Color(1.0, 1.0, 1.0, 0.85)
	flash.duration = 0.28
	add_child(flash)

	if _camera != null:
		_camera.shake(2.0, 0.25)


func _on_player_jumped() -> void:
	_spawn_foot_dust(4)


func _on_player_landed() -> void:
	_spawn_foot_dust(5)
	if _camera != null:
		_camera.shake(0.8, 0.08)


## Spawns a small tan-coloured dust puff at the player's foot position.
func _spawn_foot_dust(particle_count: int) -> void:
	if _player == null:
		return
	var dust: ParticleBurst = ParticleBurst.new()
	dust.position = _player.position  # origin = foot centre
	dust.count = particle_count
	dust.color = Color("#CFAC6E")
	dust.speed_min = 25.0
	dust.speed_max = 55.0
	dust.particle_size = 2.0
	dust.lifetime = 0.28
	dust.gravity_scale = 0.2
	dust.upward_bias = 0.1
	add_child(dust)


# ---------------------------------------------------------------------------
# Private geometry helpers
# ---------------------------------------------------------------------------

## Creates a StaticBody2D with rectangle collision + matching ColorRect visual.
## Origin at body centre; visual offset to align.
func _add_static_rect(
	centre: Vector2,
	size: Vector2,
	colour: Color
) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = centre

	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)

	var cr: ColorRect = ColorRect.new()
	cr.color = colour
	cr.size = size
	cr.position = Vector2(-size.x / 2.0, -size.y / 2.0)
	body.add_child(cr)

	add_child(body)
	return body
