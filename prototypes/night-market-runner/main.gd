# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does auto-scroll or player-paced feel right for Night Market Runner?
# Date: 2026-04-22

extends Node2D

enum Mode { PLAYER_PACED, AUTO_SCROLL }

const AUTO_SCROLL_SPEED := 80.0  # px/sec — tune this
const LEVEL_WIDTH := 960
const GROUND_Y := 160  # top of ground in 180h viewport
const VIEWPORT_W := 320
const VIEWPORT_H := 180
const HALF_VIEWPORT_W := 160

# Art-bible palette (Shilin market — for prototype we pick one)
const COLOR_PLAYER := Color("#E8F542")
const COLOR_COLLECTIBLE := Color("#F2A227")
const COLOR_HAZARD := Color("#D94F2B")
const COLOR_GROUND := Color("#4A2010")
const COLOR_PLATFORM := Color("#8B1A1A")
const COLOR_OBSTACLE := Color("#555555")
const COLOR_UI_CREAM := Color("#F5EDDA")
const COLOR_UI_RED := Color("#C2241A")
const COLOR_UI_INK := Color("#2A1A0A")

var mode: Mode = Mode.PLAYER_PACED
var score: int = 0
var deaths: int = 0
var player: Player
var camera: Camera2D
var auto_scroll_x: float = HALF_VIEWPORT_W
var score_label: Label
var debug_label: Label


func _ready() -> void:
	_build_level()
	_build_player()
	_build_camera()
	_build_ui()


func _build_level() -> void:
	_spawn_ground(0, LEVEL_WIDTH)

	# Platforms for jumping
	for pos in [Vector2(180, 120), Vector2(360, 96), Vector2(560, 128), Vector2(740, 104)]:
		_spawn_platform(pos)

	# Static obstacles (angular hard-edge = safety grammar)
	for pos in [Vector2(260, 144), Vector2(460, 144), Vector2(680, 144)]:
		_spawn_obstacle(pos)

	# Collectibles (food items — lantern-amber glow)
	for pos in [
		Vector2(120, 132),
		Vector2(220, 144),
		Vector2(330, 72),
		Vector2(430, 144),
		Vector2(560, 104),
		Vector2(640, 144),
		Vector2(800, 72),
		Vector2(880, 144),
	]:
		var c := Collectible.new()
		c.position = pos
		c.picked_up.connect(_on_collectible_pickup)
		add_child(c)

	# Patrol enemies — one at midpoint, one later
	for pos in [Vector2(400, 148), Vector2(700, 148)]:
		var e := Enemy.new()
		e.position = pos
		e.player_hit.connect(_on_player_hit)
		add_child(e)

	# Goal zone at level end
	var goal := Area2D.new()
	goal.position = Vector2(LEVEL_WIDTH - 16, 140)
	var goal_cs := CollisionShape2D.new()
	var goal_shape := RectangleShape2D.new()
	goal_shape.size = Vector2(16, 40)
	goal_cs.shape = goal_shape
	goal.add_child(goal_cs)
	var goal_visual := ColorRect.new()
	goal_visual.color = Color("#FFD966")  # score-pop gold
	goal_visual.size = Vector2(16, 40)
	goal_visual.position = Vector2(-8, -20)
	goal.add_child(goal_visual)
	goal.body_entered.connect(_on_goal_reached)
	add_child(goal)


func _spawn_ground(start_x: int, end_x: int) -> void:
	var ground := StaticBody2D.new()
	ground.position = Vector2(start_x, GROUND_Y)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(end_x - start_x, 40)
	cs.shape = shape
	cs.position = Vector2((end_x - start_x) / 2.0, 20)
	ground.add_child(cs)
	var visual := ColorRect.new()
	visual.color = COLOR_GROUND
	visual.size = Vector2(end_x - start_x, 40)
	ground.add_child(visual)
	add_child(ground)


func _spawn_platform(pos: Vector2) -> void:
	var platform := StaticBody2D.new()
	platform.position = pos
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 8)
	cs.shape = shape
	platform.add_child(cs)
	var visual := ColorRect.new()
	visual.color = COLOR_PLATFORM
	visual.size = Vector2(48, 8)
	visual.position = Vector2(-24, -4)
	platform.add_child(visual)
	add_child(platform)


func _spawn_obstacle(pos: Vector2) -> void:
	var obs := StaticBody2D.new()
	obs.position = pos
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	cs.shape = shape
	obs.add_child(cs)
	var visual := ColorRect.new()
	visual.color = COLOR_OBSTACLE
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	obs.add_child(visual)
	# Hazard tint edge (1–2px top border per art bible)
	var edge := ColorRect.new()
	edge.color = COLOR_HAZARD
	edge.size = Vector2(26, 2)
	edge.position = Vector2(-13, -14)
	obs.add_child(edge)
	add_child(obs)


func _build_player() -> void:
	player = Player.new()
	player.position = Vector2(24, 120)
	player.died.connect(_on_player_died)
	add_child(player)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(HALF_VIEWPORT_W, VIEWPORT_H / 2.0)
	camera.zoom = Vector2.ONE
	add_child(camera)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Receipt strip
	var panel := ColorRect.new()
	panel.color = COLOR_UI_CREAM
	panel.size = Vector2(200, 32)
	panel.position = Vector2(2, 2)
	canvas.add_child(panel)

	var border := ColorRect.new()
	border.color = COLOR_UI_INK
	border.size = Vector2(200, 1)
	border.position = Vector2(2, 33)
	canvas.add_child(border)

	score_label = Label.new()
	score_label.position = Vector2(6, 2)
	score_label.modulate = COLOR_UI_RED
	score_label.add_theme_font_size_override("font_size", 10)
	canvas.add_child(score_label)

	debug_label = Label.new()
	debug_label.position = Vector2(6, 16)
	debug_label.modulate = COLOR_UI_INK
	debug_label.add_theme_font_size_override("font_size", 8)
	canvas.add_child(debug_label)


func _process(delta: float) -> void:
	if mode == Mode.AUTO_SCROLL:
		auto_scroll_x += AUTO_SCROLL_SPEED * delta
		camera.position.x = clampf(auto_scroll_x, HALF_VIEWPORT_W, LEVEL_WIDTH - HALF_VIEWPORT_W)
		# Fell behind auto-scroll
		if player.position.x < camera.position.x - HALF_VIEWPORT_W - 8:
			_on_player_died()
	else:
		camera.position.x = clampf(player.position.x, HALF_VIEWPORT_W, LEVEL_WIDTH - HALF_VIEWPORT_W)

	score_label.text = "SCORE %d   MODE %s   DEATHS %d" % [
		score,
		"PACED" if mode == Mode.PLAYER_PACED else "AUTO",
		deaths,
	]
	debug_label.text = "VelY %+4.0f   VelX %+4.0f   [1]Paced [2]Auto [R]Restart" % [
		player.velocity.y,
		player.velocity.x,
	]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				mode = Mode.PLAYER_PACED
			KEY_2:
				mode = Mode.AUTO_SCROLL
				auto_scroll_x = max(auto_scroll_x, camera.position.x)
			KEY_R:
				_restart()


func _on_collectible_pickup() -> void:
	score += 100


func _on_player_hit() -> void:
	deaths += 1
	_restart()


func _on_player_died() -> void:
	deaths += 1
	_restart()


func _on_goal_reached(body: Node) -> void:
	if body is Player:
		# Victory — flash gold + restart
		score += 500
		_restart()


func _restart() -> void:
	get_tree().reload_current_scene()
