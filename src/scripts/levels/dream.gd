## 夢境關卡 — Night Market Hero dream sequence (v0.33).
##
## A short Mega-Man-style platformer beat embedded inside the bedroom
## bookend. The kid imagines they're 夜市超人, fending off a wave of 黑輪
## (oden) enemies on a single 320×180 screen with run / jump / shoot
## scallion-projectile mechanics.
##
## Win condition: kill TARGET_KILLS within TIME_LIMIT seconds.
## Lose condition: HP drops to 0.
## Either ending plays a 1.5 s outro card then routes to "title".
##
## Triggered by the bedroom scene on weekend nights (Inventory.is_weekend).
## Other days the bedroom advances straight to the title as before.
##
## All sprites are programmatic — same draw style as the rest of the game,
## just with platformer physics on top.
class_name Dream
extends Node2D

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

# ---------------------------------------------------------------------------
# Theme variants (v0.38)
# ---------------------------------------------------------------------------
#
# The dream now alternates between two visual + behavioural themes, picked
# from HiScore.dream_boss_clears at _ready time so consecutive weekend
# clears feel different rather than identical replays.
#
#   STANDARD — original v0.33/v0.34 night-market dream: purple sky,
#              brick floor, hanging lanterns. Boss drops sauce splats
#              straight down.
#   SEASIDE  — ocean-night variant: indigo→teal sky with a moon,
#              wooden boardwalk floor, string lights overhead. Boss
#              attacks track the player (aimed splat at spawn).

enum DreamTheme { STANDARD, SEASIDE }
# Stored as int so external test code can assign Dream.Theme values
# without tripping GDScript's strict-mode "external class member"
# type-check. Renamed from `_theme` to `dream_theme` because the
# underscore-prefixed name collided with an inherited member lookup
# in GDScript 4.6's stricter parser.
var dream_theme: int = DreamTheme.STANDARD

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

const FLOOR_Y: int = 142             ## y at top of ground bricks
const GRAVITY: float = 600.0         ## px / s²
const MOVE_SPEED: float = 84.0       ## px / s on ground
const JUMP_VELOCITY: float = -210.0  ## initial jump py/s (negative = up)

## Floating one-way platforms — landed on from above only. Each entry is the
## top-edge surface: x=left, y=top, w=width. Player feet at exactly `y` while
## standing. Cleared via "drop-through" not implemented (weekend scope).
const PLATFORMS: Array = [
	{"x": 56, "y": 110, "w": 40},
	{"x": 224, "y": 110, "w": 40},
	{"x": 140, "y": 84, "w": 40},
]
const PLAYER_W: float = 8.0
const PLAYER_H: float = 14.0
const PLAYER_HP_MAX: int = 3
const PLAYER_INVINCIBLE_T: float = 0.9
const PLAYER_KNOCKBACK_VX: float = 80.0
const PLAYER_KNOCKBACK_VY: float = -120.0

const SHOOT_COOLDOWN: float = 0.32   ## seconds between projectiles
const PROJECTILE_SPEED: float = 220.0
const PROJECTILE_W: float = 5.0
const PROJECTILE_H: float = 2.0
const PROJECTILE_LIFETIME: float = 1.6

const ENEMY_W: float = 9.0
const ENEMY_H: float = 9.0
const ENEMY_SPEED_BASE: float = 38.0
const ENEMY_SPEED_RAMP: float = 0.6  ## per-second speed gain over the run
const ENEMY_SPAWN_INTERVAL_BASE: float = 1.6
const ENEMY_SPAWN_INTERVAL_MIN: float = 0.7
const ENEMY_MAX_ALIVE: int = 4

## v0.34 — second enemy variant: 章魚燒 hopper. Walks-then-arcs toward the
## player so the dream isn't just a 1D shoot gallery. Takes 2 hits.
const TAKO_GRAVITY: float = 600.0
const TAKO_HOP_VX: float = 50.0      ## horizontal speed during a hop
const TAKO_HOP_VY: float = -160.0    ## initial hop velocity (negative = up)
const TAKO_HOP_COOLDOWN: float = 0.42 ## time spent grounded between hops
const TAKO_HP: int = 2
const TAKO_INTRO_WAVE_T: float = 10.0 ## tako only starts spawning after this

## v0.34 — 夜市大魔王 boss. Triggers when small-fry kill count reaches
## BOSS_TRIGGER_KILLS. Replaces the "10 small kills" win path: defeating
## the boss is the new big-win.
const BOSS_TRIGGER_KILLS: int = 8
const BOSS_HP_MAX: int = 5
const BOSS_W: float = 22.0
const BOSS_H: float = 14.0
const BOSS_HOVER_Y: float = 60.0    ## boss centre-y while patrolling
const BOSS_PATROL_X_MIN: float = 28.0
const BOSS_PATROL_X_MAX: float = 292.0
const BOSS_PATROL_SPEED: float = 50.0  ## px/s side-to-side
const BOSS_BOB_AMP: float = 4.0       ## sine-bob amplitude (px)
const BOSS_FIRE_INTERVAL: float = 1.1  ## sauce-splat drop cadence
const BOSS_INVINCIBLE_ON_HIT: float = 0.18  ## i-frames after each scallion
const BOSS_PROJECTILE_VY: float = 130.0
const BOSS_PROJECTILE_W: float = 5.0
const BOSS_PROJECTILE_H: float = 5.0
const BOSS_PROJECTILE_LIFETIME: float = 2.0

const TIME_LIMIT: float = 45.0       ## seconds to survive
const TARGET_KILLS: int = 10         ## early-win threshold
const OUTRO_HOLD: float = 1.5        ## hold ending card before goto_level

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

const COLOR_SKY_TOP: Color = Color("#3A1850")     ## dream purple
const COLOR_SKY_BOTTOM: Color = Color("#1A0F2A")
const COLOR_STAR: Color = Color("#F5EDDA")
const COLOR_BG_LANTERN_BODY: Color = Color("#5A2418")
const COLOR_BG_LANTERN_GLOW: Color = Color("#F2A227")
const COLOR_FLOOR_BRICK_A: Color = Color("#3A1A28")
const COLOR_FLOOR_BRICK_B: Color = Color("#2A1018")
const COLOR_FLOOR_TOP: Color = Color("#7A4A6A")
const COLOR_PROJECTILE: Color = Color("#7AC940")
const COLOR_PROJECTILE_TIP: Color = Color("#C8E66D")
const COLOR_ENEMY_BODY: Color = Color("#C8242A")    ## 黑輪 reddish
const COLOR_ENEMY_RIM: Color = Color("#3A1A0A")
const COLOR_ENEMY_FACE: Color = Color("#F5EDDA")
const COLOR_TAKO_BODY: Color = Color("#8A4A22")     ## browned takoyaki
const COLOR_TAKO_RIM: Color = Color("#3A1A0A")
const COLOR_TAKO_HIGHLIGHT: Color = Color("#F2D6A8") ## flake of bonito
const COLOR_TAKO_SAUCE: Color = Color("#5A2A12")    ## brown sauce drip
const COLOR_BOSS_BODY: Color = Color("#3A2A6A")     ## big boss purple-blue
const COLOR_BOSS_RIM: Color = Color("#1A0F2A")
const COLOR_BOSS_GLOW: Color = Color("#7AC940")     ## eye glow
const COLOR_BOSS_FLASH: Color = Color("#F5EDDA")    ## hit-flash highlight
const COLOR_BOSS_PROJ: Color = Color("#5A2A12")     ## sauce splat (matches tako sauce)
const COLOR_BOSS_PROJ_RIM: Color = Color("#3A1A0A")

# v0.38 SEASIDE theme palette — indigo sky, teal water hint, wood floor,
# warm string lights. Re-uses the boss/enemy colours (oden + tako stay red
# and brown — they're food, theme doesn't change them).
const SEA_COLOR_SKY_TOP: Color = Color("#1A2A5A")
const SEA_COLOR_SKY_BOTTOM: Color = Color("#0A1A3A")
const SEA_COLOR_MOON: Color = Color("#F5EDDA")
const SEA_COLOR_MOON_HALO: Color = Color("#F2D6A8")
const SEA_COLOR_HORIZON: Color = Color("#3A6A8A")    ## thin water-line band
const SEA_COLOR_FLOOR_PLANK_A: Color = Color("#5A3A22")
const SEA_COLOR_FLOOR_PLANK_B: Color = Color("#3A2818")
const SEA_COLOR_FLOOR_TOP: Color = Color("#8A5A32")
const SEA_COLOR_LIGHT_BULB: Color = Color("#F2E2A0")
const SEA_COLOR_LIGHT_WIRE: Color = Color("#3A2818")
const COLOR_HEART: Color = Color("#C2241A")
const COLOR_HEART_DIM: Color = Color("#3A1A28")
const COLOR_TEXT: Color = Color("#F5EDDA")
const COLOR_OUTRO_BG: Color = Color(0, 0, 0, 0.55)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# Player
var _player_pos: Vector2 = Vector2(160, 142)
var _player_vel: Vector2 = Vector2.ZERO
var _player_facing: int = 1            ## 1 = right, -1 = left
var _player_hp: int = PLAYER_HP_MAX
var _player_invincible_t: float = 0.0
var _player_on_ground: bool = true
var _player_prev_y: float = 142.0      ## last frame's y (for platform cross-from-above detection)
var _walk_phase_t: float = 0.0         ## leg-cycle accumulator

# Combat
var _shoot_cd_t: float = 0.0
var _projectiles: Array = []           ## { pos: Vector2, vel: Vector2, age: float }
var _enemies: Array = []               ## { pos: Vector2, hp: int }
var _spawn_t: float = 0.0
var _enemies_killed: int = 0
var _wave_t: float = 0.0               ## total run time for difficulty ramp

# Boss state — null until BOSS_TRIGGER_KILLS reached, then a single dict.
var _boss: Dictionary = {}            ## {} = no boss yet
var _boss_alive: bool = false
var _boss_defeated: bool = false
var _boss_dir: int = 1                 ## 1 = drift right, -1 = drift left
var _boss_invincible_t: float = 0.0
var _boss_fire_t: float = 0.0
var _boss_projectiles: Array = []     ## { pos: Vector2, vel: Vector2, age: float }

# Run state
var _t: float = 0.0
var _outro_t: float = 0.0              ## counts down once an ending fires
var _outro_text: String = ""
var _won: bool = false
var _done: bool = false

# UI
var _hint_label: Label = null
var _outro_label: Label = null
var _font: FontFile = null

# Cached input state — read in _process so frame-perfect inputs land even
# when the player holds keys across multiple frames.
var _hold_left: bool = false
var _hold_right: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Game.current_area = "dream"
	Game.in_dialogue = false
	# Music: switch back to the energetic market loop for the dream tempo.
	# Lullaby was playing during the bedroom bookend.
	if not Game.test_mode:
		Music.play_market()
	_player_pos = Vector2(VIEWPORT_W / 2, FLOOR_Y)
	# v0.38: alternate between STANDARD and SEASIDE themes based on the
	# player's lifetime boss clears. First clear → SEASIDE next, second
	# → STANDARD again, and so on. Test mode pins to STANDARD so unit
	# tests don't depend on HiScore state.
	var hs: Node = get_node_or_null("/root/HiScore")
	var clears: int = int(hs.dream_boss_clears) if hs != null else 0
	dream_theme = DreamTheme.SEASIDE if (clears % 2 == 1) else DreamTheme.STANDARD
	if Game.test_mode:
		dream_theme = DreamTheme.STANDARD
	_build_overlays()
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_t += delta
	# Skip simulation in test_mode so headless tests can poke state without
	# the world auto-spawning enemies / mutating the timer.
	if Game.test_mode:
		queue_redraw()
		return
	if _outro_t > 0.0:
		_outro_t = maxf(_outro_t - delta, 0.0)
		if _outro_t <= 0.0:
			_advance()
		queue_redraw()
		return
	_wave_t += delta
	_walk_phase_t += delta
	_step_player(delta)
	_step_projectiles(delta)
	_step_enemies(delta)
	_step_spawner(delta)
	_maybe_spawn_boss()
	_step_boss(delta)
	_step_boss_projectiles(delta)
	_check_endings()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# ESC handled globally by Game; here just process platformer inputs.
	if event is InputEventKey:
		var ke: InputEventKey = event
		match ke.physical_keycode:
			KEY_LEFT, KEY_A:
				_hold_left = ke.pressed
			KEY_RIGHT, KEY_D:
				_hold_right = ke.pressed
			KEY_UP, KEY_W:
				if ke.pressed and not ke.echo and _player_on_ground:
					_jump()
			KEY_SPACE, KEY_Z:
				if ke.pressed and not ke.echo:
					_try_shoot()


# ---------------------------------------------------------------------------
# Player physics
# ---------------------------------------------------------------------------

func _step_player(delta: float) -> void:
	# Horizontal velocity from held inputs
	var vx: float = 0.0
	if _hold_left:
		vx -= MOVE_SPEED
		_player_facing = -1
	if _hold_right:
		vx += MOVE_SPEED
		_player_facing = 1
	# Knockback decays toward 0 even if input is held — gives "hit recoil".
	if absf(_player_vel.x) > MOVE_SPEED:
		# Preserve sign, decay magnitude
		var sign_x: float = signf(_player_vel.x)
		var mag: float = absf(_player_vel.x) - 200.0 * delta
		_player_vel.x = sign_x * maxf(mag, MOVE_SPEED)
		# But still allow held input to override direction
		if (vx > 0.0 and sign_x < 0.0) or (vx < 0.0 and sign_x > 0.0):
			_player_vel.x = vx
	else:
		_player_vel.x = vx

	# Gravity
	_player_vel.y += GRAVITY * delta

	# Integrate
	_player_prev_y = _player_pos.y
	_player_pos.x += _player_vel.x * delta
	_player_pos.y += _player_vel.y * delta

	# Ground collision — player feet at FLOOR_Y is the ground line.
	_player_on_ground = false
	if _player_pos.y >= float(FLOOR_Y):
		_player_pos.y = float(FLOOR_Y)
		_player_vel.y = 0.0
		_player_on_ground = true
	# One-way platforms — only land if falling and feet crossed the top edge.
	# Skip when jumping up (vy < 0) so platforms feel cross-through from below.
	elif _player_vel.y >= 0.0:
		for plat in PLATFORMS:
			var top: float = float(plat["y"])
			var left: float = float(plat["x"])
			var right: float = left + float(plat["w"])
			# Player horizontally over platform?
			if _player_pos.x < left or _player_pos.x > right:
				continue
			# Crossed the top this frame?
			if _player_prev_y <= top and _player_pos.y >= top:
				_player_pos.y = top
				_player_vel.y = 0.0
				_player_on_ground = true
				break

	# Horizontal clamp inside viewport
	_player_pos.x = clampf(_player_pos.x,
		PLAYER_W * 0.5, float(VIEWPORT_W) - PLAYER_W * 0.5)

	# Invincibility timer
	if _player_invincible_t > 0.0:
		_player_invincible_t = maxf(_player_invincible_t - delta, 0.0)
	# Shoot cooldown
	if _shoot_cd_t > 0.0:
		_shoot_cd_t = maxf(_shoot_cd_t - delta, 0.0)


func _jump() -> void:
	_player_vel.y = JUMP_VELOCITY
	_player_on_ground = false
	if not Game.test_mode:
		Sfx.play_choice()


## v0.33: shoot a scallion projectile in the player's facing direction.
## Cooldown-gated so spamming Space stays balanced.
func _try_shoot() -> void:
	if _shoot_cd_t > 0.0:
		return
	_shoot_cd_t = SHOOT_COOLDOWN
	var spawn_x: float = _player_pos.x + float(_player_facing) * 6.0
	var spawn_y: float = _player_pos.y - PLAYER_H * 0.5
	_projectiles.append({
		"pos": Vector2(spawn_x, spawn_y),
		"vel": Vector2(float(_player_facing) * PROJECTILE_SPEED, 0.0),
		"age": 0.0,
	})
	if not Game.test_mode:
		Sfx.play_blip()


# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

func _step_projectiles(delta: float) -> void:
	var keep: Array = []
	for p in _projectiles:
		p["pos"] += p["vel"] * delta
		p["age"] += delta
		var off_screen: bool = (
			p["pos"].x < -8.0 or p["pos"].x > float(VIEWPORT_W) + 8.0
		)
		if p["age"] >= PROJECTILE_LIFETIME or off_screen:
			continue
		# Hit-test against enemies
		var hit: bool = false
		for e in _enemies:
			if e["hp"] <= 0:
				continue
			if _rect_overlap(p["pos"], PROJECTILE_W, PROJECTILE_H,
					e["pos"], ENEMY_W, ENEMY_H):
				e["hp"] -= 1
				hit = true
				if e["hp"] <= 0:
					_enemies_killed += 1
					if not Game.test_mode:
						Sfx.play_pickup()
				break
		# Hit-test against the boss (if alive and out of i-frames)
		if not hit and _boss_alive and _boss_invincible_t <= 0.0:
			if _rect_overlap(p["pos"], PROJECTILE_W, PROJECTILE_H,
					_boss["pos"], BOSS_W, BOSS_H):
				_boss["hp"] = int(_boss["hp"]) - 1
				_boss_invincible_t = BOSS_INVINCIBLE_ON_HIT
				hit = true
				if int(_boss["hp"]) <= 0:
					_boss_alive = false
					_boss_defeated = true
					if not Game.test_mode:
						Sfx.play_win()
				else:
					if not Game.test_mode:
						Sfx.play_bump()
		if not hit:
			keep.append(p)
	_projectiles = keep


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------

func _step_enemies(delta: float) -> void:
	var alive: Array = []
	for e in _enemies:
		if e["hp"] <= 0:
			continue
		match String(e.get("kind", "oden")):
			"tako":
				_step_tako(e, delta)
			_:
				_step_oden(e, delta)
		# Contact with player → damage (shared across kinds)
		if _player_invincible_t <= 0.0 and _rect_overlap(
				_player_pos - Vector2(0, PLAYER_H * 0.5), PLAYER_W, PLAYER_H,
				e["pos"] - Vector2(0, ENEMY_H * 0.5), ENEMY_W, ENEMY_H):
			_take_damage(e["pos"])
		alive.append(e)
	_enemies = alive


## 黑輪 — slow walker, sticks to ground, ramps speed with run length.
func _step_oden(e: Dictionary, delta: float) -> void:
	var dx: float = _player_pos.x - e["pos"].x
	var dir: float = signf(dx) if absf(dx) > 1.0 else 0.0
	var spd: float = ENEMY_SPEED_BASE + _wave_t * ENEMY_SPEED_RAMP
	e["pos"].x += dir * spd * delta
	e["pos"].y = float(FLOOR_Y) - ENEMY_H * 0.5


## 章魚燒 — hops in arcs toward the player. Grounded → cooldown countdown →
## launch in player's horizontal direction.
func _step_tako(e: Dictionary, delta: float) -> void:
	var vel: Vector2 = e.get("vel", Vector2.ZERO)
	var hop_cd: float = float(e.get("hop_cd_t", 0.0))
	var grounded: bool = bool(e.get("grounded", true))
	if grounded:
		hop_cd = maxf(hop_cd - delta, 0.0)
		if hop_cd <= 0.0:
			# Launch a hop toward the player
			var dx: float = _player_pos.x - e["pos"].x
			var dir: float = signf(dx) if absf(dx) > 1.0 else 1.0
			vel = Vector2(dir * TAKO_HOP_VX, TAKO_HOP_VY)
			grounded = false
	else:
		vel.y += TAKO_GRAVITY * delta
		e["pos"] += vel * delta
		# Landing on the floor — clamp + reset cooldown.
		if e["pos"].y >= float(FLOOR_Y) - ENEMY_H * 0.5:
			e["pos"].y = float(FLOOR_Y) - ENEMY_H * 0.5
			vel = Vector2.ZERO
			grounded = true
			hop_cd = TAKO_HOP_COOLDOWN
	e["vel"] = vel
	e["hop_cd_t"] = hop_cd
	e["grounded"] = grounded


func _step_spawner(delta: float) -> void:
	# Pause small-fry spawning during the boss fight and after victory.
	if _boss_alive or _boss_defeated:
		return
	if _enemies.size() >= ENEMY_MAX_ALIVE:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	# Interval shrinks linearly down to MIN over the run
	var ratio: float = clampf(_wave_t / TIME_LIMIT, 0.0, 1.0)
	_spawn_t = lerpf(
		ENEMY_SPAWN_INTERVAL_BASE, ENEMY_SPAWN_INTERVAL_MIN, ratio
	)
	# Pick a side opposite to player so they have time to react
	var side: int = -1 if _player_pos.x > float(VIEWPORT_W) / 2.0 else 1
	var spawn_x: float = -8.0 if side > 0 else float(VIEWPORT_W) + 8.0
	# v0.34: every 3rd spawn after TAKO_INTRO_WAVE_T is a 章魚燒 hopper.
	# Counter is _enemies_killed + alive count → close enough to "Nth spawn".
	var spawn_index: int = _enemies_killed + _enemies.size()
	var is_tako: bool = (
		_wave_t >= TAKO_INTRO_WAVE_T and (spawn_index % 3) == 2
	)
	if is_tako:
		_enemies.append({
			"pos": Vector2(spawn_x, float(FLOOR_Y) - ENEMY_H * 0.5),
			"hp": TAKO_HP,
			"kind": "tako",
			"vel": Vector2.ZERO,
			"hop_cd_t": 0.0,         ## launch immediately on first tick
			"grounded": true,
		})
	else:
		_enemies.append({
			"pos": Vector2(spawn_x, float(FLOOR_Y) - ENEMY_H * 0.5),
			"hp": 1,
			"kind": "oden",
		})


# ---------------------------------------------------------------------------
# Boss (v0.34) — 夜市大魔王
# ---------------------------------------------------------------------------

## One-time spawn check. Once the player has cleared BOSS_TRIGGER_KILLS small
## fries, the boss flies in centred and the small-fry spawner stops.
func _maybe_spawn_boss() -> void:
	if _boss_alive or _boss_defeated:
		return
	if _enemies_killed < BOSS_TRIGGER_KILLS:
		return
	_boss = {
		"pos": Vector2(float(VIEWPORT_W) / 2.0, BOSS_HOVER_Y),
		"hp": BOSS_HP_MAX,
	}
	_boss_alive = true
	_boss_dir = 1 if _player_pos.x < float(VIEWPORT_W) / 2.0 else -1
	_boss_fire_t = BOSS_FIRE_INTERVAL * 0.6
	if not Game.test_mode:
		Sfx.play_choice()


func _step_boss(delta: float) -> void:
	if not _boss_alive:
		return
	# Side-to-side patrol with sine bob.
	var pos: Vector2 = _boss["pos"]
	pos.x += float(_boss_dir) * BOSS_PATROL_SPEED * delta
	if pos.x < BOSS_PATROL_X_MIN:
		pos.x = BOSS_PATROL_X_MIN
		_boss_dir = 1
	elif pos.x > BOSS_PATROL_X_MAX:
		pos.x = BOSS_PATROL_X_MAX
		_boss_dir = -1
	pos.y = BOSS_HOVER_Y + sin(_t * 2.4) * BOSS_BOB_AMP
	_boss["pos"] = pos
	# i-frame timer
	if _boss_invincible_t > 0.0:
		_boss_invincible_t = maxf(_boss_invincible_t - delta, 0.0)
	# Fire sauce splats on a fixed cadence
	_boss_fire_t -= delta
	if _boss_fire_t <= 0.0:
		_boss_fire_t = BOSS_FIRE_INTERVAL
		# v0.38: SEASIDE boss aims at the player on spawn instead of dropping
		# straight down. Speed is normalized to BOSS_PROJECTILE_VY so the
		# attack difficulty stays roughly comparable.
		var spawn_pos: Vector2 = Vector2(pos.x, pos.y + BOSS_H * 0.5)
		var vel: Vector2
		if dream_theme == DreamTheme.SEASIDE:
			var dir_vec: Vector2 = (_player_pos - spawn_pos).normalized()
			# Clamp downward bias so the splat never travels purely sideways
			# (would feel cheap if it crossed the whole screen at head height).
			if dir_vec.y < 0.2:
				dir_vec.y = 0.2
				dir_vec = dir_vec.normalized()
			vel = dir_vec * BOSS_PROJECTILE_VY
		else:
			vel = Vector2(0.0, BOSS_PROJECTILE_VY)
		_boss_projectiles.append({
			"pos": spawn_pos,
			"vel": vel,
			"age": 0.0,
		})
		if not Game.test_mode:
			Sfx.play_blip()


func _step_boss_projectiles(delta: float) -> void:
	var keep: Array = []
	for p in _boss_projectiles:
		p["pos"] += p["vel"] * delta
		p["age"] += delta
		var off: bool = (
			p["pos"].y > float(VIEWPORT_H) + 8.0
			or p["age"] >= BOSS_PROJECTILE_LIFETIME
		)
		if off:
			continue
		# Hit-test against player (only if not invincible)
		if _player_invincible_t <= 0.0 and _rect_overlap(
				_player_pos - Vector2(0, PLAYER_H * 0.5), PLAYER_W, PLAYER_H,
				p["pos"], BOSS_PROJECTILE_W, BOSS_PROJECTILE_H):
			_take_damage(p["pos"])
			continue
		keep.append(p)
	_boss_projectiles = keep


# ---------------------------------------------------------------------------
# Damage + endings
# ---------------------------------------------------------------------------

func _take_damage(source_pos: Vector2) -> void:
	if _player_invincible_t > 0.0:
		return
	_player_hp -= 1
	_player_invincible_t = PLAYER_INVINCIBLE_T
	# Knockback away from the source
	var away: float = signf(_player_pos.x - source_pos.x)
	if away == 0.0:
		away = 1.0
	_player_vel.x = away * PLAYER_KNOCKBACK_VX
	_player_vel.y = PLAYER_KNOCKBACK_VY
	if not Game.test_mode:
		Sfx.play_bump()


func _check_endings() -> void:
	if _outro_t > 0.0 or _done:
		return
	if _player_hp <= 0:
		_outro_text = "嚇醒了！"
		_won = false
		_outro_t = OUTRO_HOLD
		_show_outro_card()
		return
	if _boss_defeated:
		# Beat the boss — biggest win ending. Theme picks the flavour text.
		_outro_text = (
			"海王沉海底！" if dream_theme == DreamTheme.SEASIDE
			else "打倒大魔王！"
		)
		_won = true
		_outro_t = OUTRO_HOLD
		_show_outro_card()
		# (play_win was already played at the kill-shot; don't double-play.)
		return
	if _t >= TIME_LIMIT:
		# Timed out. If the boss is still alive on screen, that's a lose
		# (you ran out of time mid-fight). Otherwise treat as soft win.
		if _boss_alive:
			_outro_text = "差一點…"
			_won = false
		else:
			_outro_text = "夢醒了…"
			_won = true
		_outro_t = OUTRO_HOLD
		_show_outro_card()


## Single-shot transition to the title — guarded so the timer + ESC route
## can't both trigger and double-load the next scene.
##
## v0.34: persists the dream's best-kill count + boss-clear count to HiScore
## before the scene swap. Records on every exit (win OR lose) so the player
## still gets credit for partial progress.
func _advance() -> void:
	if _done:
		return
	_done = true
	HiScore.record_dream(_enemies_killed, _boss_defeated)
	Game.goto_level("title")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Centre-anchored AABB overlap. `pos` is the centre of each rect.
func _rect_overlap(p1: Vector2, w1: float, h1: float,
		p2: Vector2, w2: float, h2: float) -> bool:
	return absf(p1.x - p2.x) < (w1 + w2) * 0.5 \
		and absf(p1.y - p2.y) < (h1 + h2) * 0.5


# ---------------------------------------------------------------------------
# UI overlays
# ---------------------------------------------------------------------------

func _build_overlays() -> void:
	_font = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	if _font != null:
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.subpixel_positioning = (
			TextServer.SUBPIXEL_POSITIONING_DISABLED
		)
	_hint_label = Label.new()
	_hint_label.text = "← → 移動　↑ 跳　Space 射擊"
	_hint_label.add_theme_font_override("font", _font)
	_hint_label.add_theme_font_size_override("font_size", 8)
	_hint_label.add_theme_color_override("font_color", Color("#888888"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.size = Vector2(VIEWPORT_W, 10)
	_hint_label.position = Vector2(0, VIEWPORT_H - 12)
	add_child(_hint_label)


func _show_outro_card() -> void:
	if _outro_label != null:
		return
	_outro_label = Label.new()
	_outro_label.text = _outro_text
	_outro_label.add_theme_font_override("font", _font)
	_outro_label.add_theme_font_size_override("font_size", 18)
	_outro_label.add_theme_color_override(
		"font_color", Color("#F2A227") if _won else Color("#C2241A")
	)
	_outro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outro_label.size = Vector2(VIEWPORT_W, 22)
	_outro_label.position = Vector2(0, VIEWPORT_H / 2 - 12)
	add_child(_outro_label)


# ---------------------------------------------------------------------------
# Drawing — back to front
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_sky()
	_draw_bg_lanterns()
	_draw_floor()
	_draw_platforms()
	_draw_projectiles()
	_draw_enemies()
	_draw_boss()
	_draw_boss_projectiles()
	_draw_player()
	_draw_hud()
	if _outro_t > 0.0:
		_draw_outro_dim()


func _draw_sky() -> void:
	if dream_theme == DreamTheme.SEASIDE:
		_draw_sky_seaside()
		return
	# Vertical gradient via 2 stacked rects (cheap)
	draw_rect(Rect2(0, 0, VIEWPORT_W, FLOOR_Y / 2), COLOR_SKY_TOP)
	draw_rect(Rect2(0, FLOOR_Y / 2, VIEWPORT_W, FLOOR_Y - FLOOR_Y / 2),
		COLOR_SKY_BOTTOM)
	# Stars
	var positions: Array = [
		[18, 14], [54, 24], [92, 8], [128, 32], [168, 20],
		[208, 12], [244, 28], [288, 18], [310, 36],
		[40, 60], [120, 70], [220, 56], [280, 78],
	]
	for p in positions:
		draw_rect(Rect2(int(p[0]), int(p[1]), 1, 1), COLOR_STAR)


## v0.38 SEASIDE — indigo gradient with a moon and a thin water-line
## horizon stripe. Stars in the upper band only (lower band is "water").
func _draw_sky_seaside() -> void:
	# Sky gradient
	draw_rect(Rect2(0, 0, VIEWPORT_W, FLOOR_Y / 2), SEA_COLOR_SKY_TOP)
	draw_rect(Rect2(0, FLOOR_Y / 2, VIEWPORT_W, FLOOR_Y - FLOOR_Y / 2),
		SEA_COLOR_SKY_BOTTOM)
	# Horizon water-line — single dark teal stripe just above the floor
	var horizon_y: int = FLOOR_Y - 18
	draw_rect(Rect2(0, horizon_y, VIEWPORT_W, 4), SEA_COLOR_HORIZON)
	draw_rect(Rect2(0, horizon_y, VIEWPORT_W, 1),
		SEA_COLOR_HORIZON.lightened(0.15))
	# Moon — round-ish rect with halo, top-right
	var moon_x: int = 248
	var moon_y: int = 22
	var halo: Color = SEA_COLOR_MOON_HALO
	halo.a = 0.30
	draw_rect(Rect2(moon_x - 6, moon_y - 1, 16, 12), halo)
	draw_rect(Rect2(moon_x - 4, moon_y, 12, 10), SEA_COLOR_MOON)
	# Bite out of the moon (crescent hint) — small dark wedge
	draw_rect(Rect2(moon_x + 4, moon_y + 1, 4, 8), SEA_COLOR_SKY_TOP)
	# Stars only in the upper band
	var positions: Array = [
		[18, 14], [54, 24], [92, 8], [128, 32], [168, 20],
		[208, 12], [40, 38], [78, 46], [128, 50],
	]
	for p in positions:
		draw_rect(Rect2(int(p[0]), int(p[1]), 1, 1), COLOR_STAR)


## Background-lantern row swaying — non-interactive set dressing that
## echoes the night-market lantern motif so the dream stays "in world".
func _draw_bg_lanterns() -> void:
	if dream_theme == DreamTheme.SEASIDE:
		_draw_bg_string_lights()
		return
	var rope_y: int = 96
	draw_rect(Rect2(0, rope_y, VIEWPORT_W, 1), Color("#3A1A0A"))
	for i in 5:
		var x: float = 32.0 + float(i) * 64.0 + sin(_t * 1.4 + float(i)) * 1.5
		# String
		draw_rect(Rect2(x, rope_y, 1, 4), Color("#3A1A0A"))
		# Body
		draw_rect(Rect2(x - 4, rope_y + 5, 9, 6), COLOR_BG_LANTERN_BODY)
		# Glow halo
		var halo: Color = COLOR_BG_LANTERN_GLOW
		halo.a = 0.45
		draw_rect(Rect2(x - 6, rope_y + 4, 13, 8), halo)
		# Rim hits
		draw_rect(Rect2(x - 4, rope_y + 4, 9, 1), COLOR_BG_LANTERN_GLOW)
		draw_rect(Rect2(x - 4, rope_y + 11, 9, 1), COLOR_BG_LANTERN_GLOW)


## v0.38 SEASIDE — twinkling string-light row instead of paper lanterns.
## Each bulb has a stagger phase so they alternate-blink. Wire dips slightly.
func _draw_bg_string_lights() -> void:
	var rope_y: int = 96
	# Wire — slight dip in the middle by drawing two lines that meet lower.
	for x in range(0, VIEWPORT_W, 2):
		var dip: int = int(round(sin(float(x) / float(VIEWPORT_W) * PI) * 2.0))
		draw_rect(Rect2(x, rope_y + dip, 2, 1), SEA_COLOR_LIGHT_WIRE)
	# Bulbs — 9 evenly spaced, each twinkling on its own phase
	for i in 9:
		var x: float = 18.0 + float(i) * 32.0
		var phase: float = float(i) * 0.7
		var sine_dip: float = sin(float(x) / float(VIEWPORT_W) * PI) * 2.0
		var bx: float = x
		var by: float = float(rope_y) + sine_dip + 1.0
		var lit: bool = sin(_t * 1.6 + phase) > -0.2
		var bulb: Color = SEA_COLOR_LIGHT_BULB if lit else \
			SEA_COLOR_LIGHT_BULB.darkened(0.55)
		# Halo (translucent) — only when lit
		if lit:
			var halo: Color = bulb
			halo.a = 0.35
			draw_rect(Rect2(bx - 3, by - 1, 7, 5), halo)
		# Bulb body
		draw_rect(Rect2(bx - 1, by, 3, 3), bulb)
		# Cap on top
		draw_rect(Rect2(bx - 1, by - 1, 3, 1), SEA_COLOR_LIGHT_WIRE)


func _draw_floor() -> void:
	if dream_theme == DreamTheme.SEASIDE:
		_draw_floor_seaside()
		return
	# Alternating brick band
	for i in (VIEWPORT_W / 8) + 1:
		var bx: float = float(i * 8)
		var c: Color = COLOR_FLOOR_BRICK_A if i % 2 == 0 else COLOR_FLOOR_BRICK_B
		draw_rect(Rect2(bx, FLOOR_Y, 8, VIEWPORT_H - FLOOR_Y), c)
	# Highlight stripe along the top
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1), COLOR_FLOOR_TOP)


## v0.38 SEASIDE — wooden boardwalk floor with vertical plank seams every
## 12 px and a warmer top-edge highlight.
func _draw_floor_seaside() -> void:
	# Base plank field — alternating stripes, vertical orientation
	for i in (VIEWPORT_W / 12) + 1:
		var bx: float = float(i * 12)
		var c: Color = SEA_COLOR_FLOOR_PLANK_A if i % 2 == 0 else SEA_COLOR_FLOOR_PLANK_B
		draw_rect(Rect2(bx, FLOOR_Y, 12, VIEWPORT_H - FLOOR_Y), c)
		# Plank seam (1 px darker line on the right edge)
		draw_rect(Rect2(bx + 11, FLOOR_Y, 1, VIEWPORT_H - FLOOR_Y),
			SEA_COLOR_FLOOR_PLANK_B.darkened(0.4))
	# Warmer highlight along the top edge of the boardwalk
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1), SEA_COLOR_FLOOR_TOP)


## Floating brick-top platforms. Drawn as a 4-px-tall slab so the player can
## tell from a glance there is a landable surface.
func _draw_platforms() -> void:
	for plat in PLATFORMS:
		var x: float = float(plat["x"])
		var y: float = float(plat["y"])
		var w: float = float(plat["w"])
		# Underside slab
		draw_rect(Rect2(x, y, w, 4), COLOR_FLOOR_BRICK_A)
		# Brick joins — every 8 px
		var i: int = 0
		while i < int(w):
			var jc: Color = COLOR_FLOOR_BRICK_B if (i / 8) % 2 == 0 else COLOR_FLOOR_BRICK_A
			draw_rect(Rect2(x + float(i), y + 1, 8, 3), jc)
			i += 8
		# Bright top edge
		draw_rect(Rect2(x, y, w, 1), COLOR_FLOOR_TOP)


func _draw_projectiles() -> void:
	for p in _projectiles:
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		var dir: int = 1 if vel.x >= 0 else -1
		# Body — green stick
		draw_rect(Rect2(pos.x - PROJECTILE_W * 0.5, pos.y - PROJECTILE_H * 0.5,
			PROJECTILE_W, PROJECTILE_H), COLOR_PROJECTILE)
		# Bright tip in travel direction
		draw_rect(Rect2(pos.x + float(dir) * (PROJECTILE_W * 0.5 - 1.0),
			pos.y - PROJECTILE_H * 0.5, 1, PROJECTILE_H),
			COLOR_PROJECTILE_TIP)


func _draw_enemies() -> void:
	for e in _enemies:
		if e["hp"] <= 0:
			continue
		match String(e.get("kind", "oden")):
			"tako":
				_draw_tako(e)
			_:
				_draw_oden(e)


func _draw_oden(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	# Body — round-ish red 黑輪
	draw_rect(Rect2(pos.x - ENEMY_W * 0.5, pos.y - ENEMY_H * 0.5,
		ENEMY_W, ENEMY_H), COLOR_ENEMY_BODY)
	# Top + bottom rim
	draw_rect(Rect2(pos.x - ENEMY_W * 0.5, pos.y - ENEMY_H * 0.5,
		ENEMY_W, 1), COLOR_ENEMY_RIM)
	draw_rect(Rect2(pos.x - ENEMY_W * 0.5, pos.y + ENEMY_H * 0.5 - 1,
		ENEMY_W, 1), COLOR_ENEMY_RIM)
	# Tiny eyes — face direction of player
	var eye_dir: float = signf(_player_pos.x - pos.x)
	var ex: float = pos.x + eye_dir * 1.5
	draw_rect(Rect2(ex - 1, pos.y - 1, 1, 1), COLOR_ENEMY_FACE)
	draw_rect(Rect2(ex + 1, pos.y - 1, 1, 1), COLOR_ENEMY_FACE)


## 章魚燒 — browned ball with bonito flake highlights and angry eyes.
## Squashes vertically when grounded for visible "anticipation" before a hop.
func _draw_tako(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var grounded: bool = bool(e.get("grounded", true))
	# Visual squash — slightly flattened on ground, full-tall in air.
	var sq: float = 0.0 if not grounded else 1.0
	var w: float = ENEMY_W
	var h: float = ENEMY_H - sq
	var dy: float = sq * 0.5
	# Body
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h * 0.5 + dy, w, h),
		COLOR_TAKO_BODY)
	# Sauce drip on the upper-left
	draw_rect(Rect2(pos.x - w * 0.5 + 1, pos.y - h * 0.5 + dy + 1, 2, 1),
		COLOR_TAKO_SAUCE)
	draw_rect(Rect2(pos.x - w * 0.5 + 2, pos.y - h * 0.5 + dy + 2, 1, 1),
		COLOR_TAKO_SAUCE)
	# Bonito flake highlight (off-white sliver)
	draw_rect(Rect2(pos.x + 1, pos.y - h * 0.5 + dy + 1, 2, 1),
		COLOR_TAKO_HIGHLIGHT)
	# Top + bottom rim
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h * 0.5 + dy, w, 1),
		COLOR_TAKO_RIM)
	draw_rect(Rect2(pos.x - w * 0.5, pos.y + h * 0.5 + dy - 1, w, 1),
		COLOR_TAKO_RIM)
	# Eyes — angled inward "angry" pair, face direction of player
	var eye_dir: float = signf(_player_pos.x - pos.x)
	var ex: float = pos.x + eye_dir * 1.5
	draw_rect(Rect2(ex - 2, pos.y, 1, 1), COLOR_ENEMY_FACE)
	draw_rect(Rect2(ex + 1, pos.y, 1, 1), COLOR_ENEMY_FACE)
	# Pupil — single dark dot on the side facing the player
	var pupil_x: float = ex + 1.0 if eye_dir > 0 else ex - 2.0
	draw_rect(Rect2(pupil_x, pos.y, 1, 1), COLOR_TAKO_RIM)


## Player sprite — yellow-shirt kid, but armed. 2-frame leg cycle on the
## ground; tucked legs in the air. Flicker on invincibility.
func _draw_player() -> void:
	# Flicker during invincibility — skip every other 60ms
	if _player_invincible_t > 0.0 and int(_t * 16.0) % 2 == 0:
		return
	var x: float = _player_pos.x
	var y: float = _player_pos.y
	var leg_phase: bool = (int(_walk_phase_t * 5.0) % 2) == 0
	var bob: int = (-1 if leg_phase else 0) if _player_on_ground else 0
	# Hair
	draw_rect(Rect2(x - 3.0, y - 13.0 + bob, 6.0, 2.0), Color("#3A1A0A"))
	# Head
	draw_rect(Rect2(x - 3.0, y - 11.0 + bob, 6.0, 4.0), Color("#F2D6A8"))
	# Eyes — face direction of travel
	var eye_x_off: float = 0.0 if _player_facing > 0 else -1.0
	draw_rect(Rect2(x - 1.0 + eye_x_off, y - 9.0 + bob, 1.0, 1.0),
		Color("#2A1A0A"))
	draw_rect(Rect2(x + 2.0 + eye_x_off, y - 9.0 + bob, 1.0, 1.0),
		Color("#2A1A0A"))
	# Shirt — gold "hero cape" tone instead of plain yellow for dream flair
	draw_rect(Rect2(x - 4.0, y - 7.0 + bob, 8.0, 5.0), Color("#F2D827"))
	draw_rect(Rect2(x - 4.0, y - 7.0 + bob, 8.0, 1.0),
		Color("#F2D827").darkened(0.25))
	# Shorts
	draw_rect(Rect2(x - 3.0, y - 2.0 + bob, 2.0, 3.0), Color("#3A4A8A"))
	draw_rect(Rect2(x + 1.0, y - 2.0 + bob, 2.0, 3.0), Color("#3A4A8A"))
	# Legs (alternate on ground; tucked when airborne)
	if _player_on_ground:
		if leg_phase:
			draw_rect(Rect2(x - 3.0, y + 1.0, 2.0, 2.0), Color("#F2D6A8"))
			draw_rect(Rect2(x + 1.0, y, 2.0, 3.0), Color("#F2D6A8"))
		else:
			draw_rect(Rect2(x - 3.0, y, 2.0, 3.0), Color("#F2D6A8"))
			draw_rect(Rect2(x + 1.0, y + 1.0, 2.0, 2.0), Color("#F2D6A8"))
	else:
		# Tucked legs while jumping
		draw_rect(Rect2(x - 3.0, y, 2.0, 2.0), Color("#F2D6A8"))
		draw_rect(Rect2(x + 1.0, y, 2.0, 2.0), Color("#F2D6A8"))
	# Buster glow when shoot is on cooldown — small green muzzle flash
	if _shoot_cd_t > SHOOT_COOLDOWN - 0.08:
		var fx: float = x + float(_player_facing) * 5.0
		var fy: float = y - 7.0
		draw_rect(Rect2(fx - 1.0, fy - 1.0, 3.0, 3.0), COLOR_PROJECTILE_TIP)


## 夜市大魔王 — chunky purple-blue rectangle with glowing eye and a hit-flash
## white frame during i-frames so successful hits read clearly.
func _draw_boss() -> void:
	if not _boss_alive:
		return
	var pos: Vector2 = _boss["pos"]
	var x: float = pos.x - BOSS_W * 0.5
	var y: float = pos.y - BOSS_H * 0.5
	var flashing: bool = _boss_invincible_t > 0.0 and \
		(int(_t * 32.0) % 2 == 0)
	var body: Color = COLOR_BOSS_FLASH if flashing else COLOR_BOSS_BODY
	# Body slab
	draw_rect(Rect2(x, y, BOSS_W, BOSS_H), body)
	# Top + bottom rim
	draw_rect(Rect2(x, y, BOSS_W, 1), COLOR_BOSS_RIM)
	draw_rect(Rect2(x, y + BOSS_H - 1, BOSS_W, 1), COLOR_BOSS_RIM)
	# Side rims
	draw_rect(Rect2(x, y, 1, BOSS_H), COLOR_BOSS_RIM)
	draw_rect(Rect2(x + BOSS_W - 1, y, 1, BOSS_H), COLOR_BOSS_RIM)
	# Eye stripe — big single eye that follows the player
	var eye_dir: float = signf(_player_pos.x - pos.x)
	var eye_x: float = pos.x + eye_dir * 4.0
	draw_rect(Rect2(eye_x - 3.0, pos.y - 3.0, 6.0, 4.0),
		COLOR_BOSS_RIM)
	draw_rect(Rect2(eye_x - 2.0, pos.y - 2.0, 4.0, 2.0),
		COLOR_BOSS_GLOW)
	# Pupil
	var pupil_x: float = eye_x + (1.0 if eye_dir > 0 else -2.0)
	draw_rect(Rect2(pupil_x, pos.y - 1.0, 1.0, 1.0), COLOR_BOSS_RIM)
	# Crown — three small spikes on top
	for i in 3:
		var sx: float = pos.x - 4.0 + float(i) * 4.0
		draw_rect(Rect2(sx, y - 2.0, 2.0, 2.0), COLOR_BG_LANTERN_GLOW)


func _draw_boss_projectiles() -> void:
	for p in _boss_projectiles:
		var pos: Vector2 = p["pos"]
		var x: float = pos.x - BOSS_PROJECTILE_W * 0.5
		var y: float = pos.y - BOSS_PROJECTILE_H * 0.5
		# Sauce blob — darker rim, lighter centre
		draw_rect(Rect2(x, y, BOSS_PROJECTILE_W, BOSS_PROJECTILE_H),
			COLOR_BOSS_PROJ_RIM)
		draw_rect(Rect2(x + 1.0, y + 1.0,
			BOSS_PROJECTILE_W - 2.0, BOSS_PROJECTILE_H - 2.0), COLOR_BOSS_PROJ)


func _draw_hud() -> void:
	# HP hearts top-left
	for i in PLAYER_HP_MAX:
		var hx: int = 4 + i * 8
		var hy: int = 4
		var c: Color = COLOR_HEART if i < _player_hp else COLOR_HEART_DIM
		# 3-pixel stylised heart
		draw_rect(Rect2(hx, hy, 1, 1), c)
		draw_rect(Rect2(hx + 2, hy, 1, 1), c)
		draw_rect(Rect2(hx, hy + 1, 3, 1), c)
		draw_rect(Rect2(hx + 1, hy + 2, 1, 1), c)
	# Kill count / boss progress top-right
	if _font != null:
		var top_text: String
		if _boss_alive:
			top_text = "BOSS  %d / %d" % [int(_boss["hp"]), BOSS_HP_MAX]
		elif _boss_defeated:
			top_text = "★ CLEAR ★"
		else:
			top_text = "× %d / %d" % [_enemies_killed, BOSS_TRIGGER_KILLS]
		draw_string(_font, Vector2(VIEWPORT_W - 86, 12),
			top_text, HORIZONTAL_ALIGNMENT_RIGHT, 80, 9, COLOR_TEXT)
		# Time remaining centre-top
		var remaining: float = maxf(TIME_LIMIT - _t, 0.0)
		var time_text: String = "%.1fs" % remaining
		draw_string(_font, Vector2(VIEWPORT_W / 2 - 32, 12),
			time_text, HORIZONTAL_ALIGNMENT_CENTER, 64, 9, COLOR_TEXT)
	# Boss HP bar — drawn as a slim segmented bar above the boss
	if _boss_alive:
		var bx: float = float(_boss["pos"].x) - BOSS_W * 0.5
		var by: float = float(_boss["pos"].y) - BOSS_H * 0.5 - 5.0
		for i in BOSS_HP_MAX:
			var sx: float = bx + float(i) * (BOSS_W / float(BOSS_HP_MAX))
			var seg_w: float = (BOSS_W / float(BOSS_HP_MAX)) - 1.0
			var c: Color = COLOR_HEART if i < int(_boss["hp"]) \
				else COLOR_HEART_DIM
			draw_rect(Rect2(sx, by, seg_w, 2.0), c)


## Dim the playfield while the outro card is held so the text reads cleanly.
func _draw_outro_dim() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_OUTRO_BG)
