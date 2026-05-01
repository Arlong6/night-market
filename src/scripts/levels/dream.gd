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
# Tunables
# ---------------------------------------------------------------------------

const FLOOR_Y: int = 142             ## y at top of ground bricks
const GRAVITY: float = 600.0         ## px / s²
const MOVE_SPEED: float = 84.0       ## px / s on ground
const JUMP_VELOCITY: float = -210.0  ## initial jump py/s (negative = up)
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
var _walk_phase_t: float = 0.0         ## leg-cycle accumulator

# Combat
var _shoot_cd_t: float = 0.0
var _projectiles: Array = []           ## { pos: Vector2, vel: Vector2, age: float }
var _enemies: Array = []               ## { pos: Vector2, hp: int }
var _spawn_t: float = 0.0
var _enemies_killed: int = 0
var _wave_t: float = 0.0               ## total run time for difficulty ramp

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
	_player_pos.x += _player_vel.x * delta
	_player_pos.y += _player_vel.y * delta

	# Ground collision — player feet at FLOOR_Y is the ground line.
	if _player_pos.y >= float(FLOOR_Y):
		_player_pos.y = float(FLOOR_Y)
		_player_vel.y = 0.0
		_player_on_ground = true
	else:
		_player_on_ground = false

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
		# Walk toward player horizontally
		var dx: float = _player_pos.x - e["pos"].x
		var dir: float = signf(dx) if absf(dx) > 1.0 else 0.0
		var spd: float = ENEMY_SPEED_BASE + _wave_t * ENEMY_SPEED_RAMP
		e["pos"].x += dir * spd * delta
		# Enemies stick to the floor (oden wobble — no jumping)
		e["pos"].y = float(FLOOR_Y) - ENEMY_H * 0.5
		# Contact with player → damage
		if _player_invincible_t <= 0.0 and _rect_overlap(
				_player_pos - Vector2(0, PLAYER_H * 0.5), PLAYER_W, PLAYER_H,
				e["pos"] - Vector2(0, ENEMY_H * 0.5), ENEMY_W, ENEMY_H):
			_take_damage(e["pos"])
		alive.append(e)
	_enemies = alive


func _step_spawner(delta: float) -> void:
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
	_enemies.append({
		"pos": Vector2(spawn_x, float(FLOOR_Y) - ENEMY_H * 0.5),
		"hp": 1,
	})


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
	if _enemies_killed >= TARGET_KILLS:
		_outro_text = "夜市超人！"
		_won = true
		_outro_t = OUTRO_HOLD
		_show_outro_card()
		if not Game.test_mode:
			Sfx.play_win()
		return
	if _t >= TIME_LIMIT:
		# Timed out — count as a soft win (you survived)
		_outro_text = "夢醒了…"
		_won = true
		_outro_t = OUTRO_HOLD
		_show_outro_card()


## Single-shot transition to the title — guarded so the timer + ESC route
## can't both trigger and double-load the next scene.
func _advance() -> void:
	if _done:
		return
	_done = true
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
	_draw_projectiles()
	_draw_enemies()
	_draw_player()
	_draw_hud()
	if _outro_t > 0.0:
		_draw_outro_dim()


func _draw_sky() -> void:
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


## Background-lantern row swaying — non-interactive set dressing that
## echoes the night-market lantern motif so the dream stays "in world".
func _draw_bg_lanterns() -> void:
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


func _draw_floor() -> void:
	# Alternating brick band
	for i in (VIEWPORT_W / 8) + 1:
		var bx: float = float(i * 8)
		var c: Color = COLOR_FLOOR_BRICK_A if i % 2 == 0 else COLOR_FLOOR_BRICK_B
		draw_rect(Rect2(bx, FLOOR_Y, 8, VIEWPORT_H - FLOOR_Y), c)
	# Highlight stripe along the top
	draw_rect(Rect2(0, FLOOR_Y, VIEWPORT_W, 1), COLOR_FLOOR_TOP)


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
	# Kill count top-right
	if _font != null:
		var kill_text: String = "× %d / %d" % [_enemies_killed, TARGET_KILLS]
		draw_string(_font, Vector2(VIEWPORT_W - 70, 12),
			kill_text, HORIZONTAL_ALIGNMENT_RIGHT, 64, 9, COLOR_TEXT)
		# Time remaining bottom-left of HUD
		var remaining: float = maxf(TIME_LIMIT - _t, 0.0)
		var time_text: String = "%.1fs" % remaining
		draw_string(_font, Vector2(VIEWPORT_W / 2 - 32, 12),
			time_text, HORIZONTAL_ALIGNMENT_CENTER, 64, 9, COLOR_TEXT)


## Dim the playfield while the outro card is held so the text reads cleanly.
func _draw_outro_dim() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), COLOR_OUTRO_BG)
