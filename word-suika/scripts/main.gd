## Main — game manager for 一字一句 (Word Suika).
##
## Spawns glyphs on click, tracks score, detects game-over (glyph above
## the danger line for too long), handles merging, and shows the
## next-glyph preview.
extends Node2D

const Glyph = preload("res://scripts/glyph.gd")
const TierData = preload("res://scripts/tier_data.gd")

## Viewport dimensions (matching project.godot).
const VIEWPORT_W: float = 540.0
const VIEWPORT_H: float = 960.0

## Play-field box dimensions.
const FIELD_LEFT: float = 30.0
const FIELD_RIGHT: float = 510.0
const FIELD_TOP: float = 180.0
const FIELD_BOTTOM: float = 900.0

## Spawn cursor (where the preview glyph sits) y-position.
const SPAWN_Y: float = 110.0

## Danger line — if a glyph stays above this for too long, game over.
## Pushed lower so player has more room to recover.
const DANGER_Y: float = 240.0

## Seconds a glyph can stay above DANGER_Y before triggering game over.
## More forgiving so players can recover mid-pileup.
const DANGER_GRACE_SEC: float = 3.0

## Cooldown between drops.
const DROP_COOLDOWN: float = 0.45

## Combo: chain merges within this window for bonus multiplier.
const COMBO_WINDOW: float = 1.6
const COMBO_MAX_MULT: int = 8

## Mode constants
enum Mode { DROP, LAUNCH }

## Launch mode tuning
const LAUNCH_FIXED_X: float = 270.0  # center of field
const LAUNCH_MIN_SPEED: float = 240.0
const LAUNCH_MAX_SPEED: float = 900.0
const LAUNCH_CHARGE_TIME: float = 0.55  # seconds to full charge

var _rng := RandomNumberGenerator.new()
var _score: int = 0
var _can_drop: bool = true
var _spawn_x: float = VIEWPORT_W * 0.5
var _next_tier: int = 0
var _danger_timer: float = 0.0
var _game_over: bool = false

## Combo state
var _combo_count: int = 0
var _combo_timer: float = 0.0
var _combo_label: Label = null
var _combo_tween: Tween = null

## Trajectory aim line (dashed preview from cursor down to predicted landing).
var _trajectory_line: Node2D = null

## Camera shake state
var _shake_strength: float = 0.0
var _shake_decay: float = 18.0
var _ui_layer: CanvasLayer = null

## Mode state
var _mode: int = Mode.DROP
var _mode_label: Label = null
var _mode_button: Button = null

## Launch mode state
var _is_charging: bool = false
var _charge_amount: float = 0.0
var _aim_renderer: Node2D = null

# UI references (set in _ready by name lookup)
var _ui_score: Label = null
var _ui_next: Label = null
var _ui_status: Label = null
var _preview: Node2D = null
var _preview_drawer: Node2D = null
var _next_card: Node2D = null  # large visual card showing next glyph
var _next_card_drawer: Node2D = null
var _next_card_label: Label = null

func _ready() -> void:
	_rng.randomize()
	_build_field()
	_build_ui()
	_build_preview()
	_build_trajectory_line()
	_build_aim_renderer()
	_next_tier = TierData.pick_droppable_tier(_rng)
	_build_next_card()
	_update_preview()
	_refresh_mode_ui()

func _build_aim_renderer() -> void:
	_aim_renderer = Node2D.new()
	_aim_renderer.name = "AimRenderer"
	_aim_renderer.set_script(preload("res://scripts/aim_renderer.gd"))
	_aim_renderer.set("origin", Vector2(LAUNCH_FIXED_X, SPAWN_Y))
	_aim_renderer.set("aim_target", Vector2(LAUNCH_FIXED_X, SPAWN_Y + 200))
	_aim_renderer.set("charge", 0.0)
	_aim_renderer.visible = false
	_aim_renderer.z_index = -3
	add_child(_aim_renderer)

func _build_trajectory_line() -> void:
	# Dashed line from spawn cursor straight down to floor, indicates aim.
	_trajectory_line = Node2D.new()
	_trajectory_line.name = "Trajectory"
	_trajectory_line.set_script(preload("res://scripts/trajectory_line.gd"))
	_trajectory_line.set("from_y", SPAWN_Y)
	_trajectory_line.set("to_y", FIELD_BOTTOM)
	_trajectory_line.z_index = -5
	add_child(_trajectory_line)

func _build_field() -> void:
	# Static walls + floor with StaticBody2D
	var walls := StaticBody2D.new()
	walls.name = "FieldWalls"
	add_child(walls)
	# Left wall
	_add_segment(walls, Vector2(FIELD_LEFT, FIELD_TOP - 20), Vector2(FIELD_LEFT, FIELD_BOTTOM + 20))
	# Right wall
	_add_segment(walls, Vector2(FIELD_RIGHT, FIELD_TOP - 20), Vector2(FIELD_RIGHT, FIELD_BOTTOM + 20))
	# Floor
	_add_segment(walls, Vector2(FIELD_LEFT, FIELD_BOTTOM), Vector2(FIELD_RIGHT, FIELD_BOTTOM))
	# Visual: parchment field bg
	var bg := ColorRect.new()
	bg.color = Color(0.92, 0.88, 0.76, 1.0)
	bg.position = Vector2(FIELD_LEFT, FIELD_TOP)
	bg.size = Vector2(FIELD_RIGHT - FIELD_LEFT, FIELD_BOTTOM - FIELD_TOP)
	bg.z_index = -10
	add_child(bg)
	# Top edge frame
	var top_edge := ColorRect.new()
	top_edge.color = Color(0.4, 0.3, 0.2, 1.0)
	top_edge.position = Vector2(FIELD_LEFT, FIELD_TOP - 2)
	top_edge.size = Vector2(FIELD_RIGHT - FIELD_LEFT, 2)
	top_edge.z_index = -5
	add_child(top_edge)
	# Danger line indicator (faint dashed look via ColorRect)
	var danger := ColorRect.new()
	danger.color = Color(0.7, 0.3, 0.25, 0.45)
	danger.position = Vector2(FIELD_LEFT, DANGER_Y)
	danger.size = Vector2(FIELD_RIGHT - FIELD_LEFT, 1)
	danger.z_index = -3
	add_child(danger)

func _add_segment(parent: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var col := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	col.shape = seg
	parent.add_child(col)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	_ui_layer = ui
	# Score
	_ui_score = Label.new()
	_ui_score.name = "Score"
	_ui_score.position = Vector2(30, 30)
	_ui_score.size = Vector2(300, 40)
	_ui_score.add_theme_font_size_override("font_size", 28)
	_ui_score.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78, 1.0))
	ui.add_child(_ui_score)
	# Title (top center)
	var title := Label.new()
	title.text = "一字一句"
	title.size = Vector2(VIEWPORT_W, 30)
	title.position = Vector2(0, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45, 0.85))
	ui.add_child(title)
	# Next preview label (top-right, bigger so player can read at a glance)
	_ui_next = Label.new()
	_ui_next.text = ""
	_ui_next.position = Vector2(VIEWPORT_W - 200, 24)
	_ui_next.size = Vector2(170, 56)
	_ui_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_next.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_next.add_theme_font_size_override("font_size", 28)
	_ui_next.add_theme_color_override("font_color", Color(0.92, 0.83, 0.55, 1.0))
	ui.add_child(_ui_next)
	# Status (game-over banner, hidden until needed)
	_ui_status = Label.new()
	_ui_status.text = ""
	_ui_status.size = Vector2(VIEWPORT_W, 80)
	_ui_status.position = Vector2(0, VIEWPORT_H * 0.4)
	_ui_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_status.add_theme_font_size_override("font_size", 42)
	_ui_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	_ui_status.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_ui_status.add_theme_constant_override("outline_size", 6)
	ui.add_child(_ui_status)
	# Combo display — hidden until combo > 1
	_combo_label = Label.new()
	_combo_label.name = "Combo"
	_combo_label.position = Vector2(30, 70)
	_combo_label.size = Vector2(300, 36)
	_combo_label.add_theme_font_size_override("font_size", 22)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.7))
	_combo_label.add_theme_constant_override("outline_size", 4)
	_combo_label.visible = false
	ui.add_child(_combo_label)
	# Mode switch button (top center, below title)
	_mode_button = Button.new()
	_mode_button.text = "落雨 (M 切換)"
	_mode_button.position = Vector2(VIEWPORT_W * 0.5 - 90, 50)
	_mode_button.size = Vector2(180, 28)
	_mode_button.add_theme_font_size_override("font_size", 14)
	_mode_button.pressed.connect(_toggle_mode)
	ui.add_child(_mode_button)
	_refresh_score()

func _build_next_card() -> void:
	# Large visual card on the upper-right showing the next glyph at full size.
	var ui = get_node_or_null("UI")
	if ui == null:
		return
	_next_card = Node2D.new()
	_next_card.name = "NextCard"
	_next_card.position = Vector2(VIEWPORT_W - 80, 110)
	ui.add_child(_next_card)
	# Card backplate (a faint rounded panel)
	var plate := ColorRect.new()
	plate.color = Color(0.18, 0.15, 0.20, 0.35)
	plate.position = Vector2(-55, -60)
	plate.size = Vector2(110, 130)
	_next_card.add_child(plate)
	# Top label "下一個"
	var caption := Label.new()
	caption.text = "下一個"
	caption.position = Vector2(-55, -58)
	caption.size = Vector2(110, 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6, 0.9))
	_next_card.add_child(caption)
	# Glyph drawer for the next-tier visual
	_next_card_drawer = Node2D.new()
	_next_card_drawer.set_script(preload("res://scripts/glyph_drawer.gd"))
	_next_card_drawer.set("direct_tier", _next_tier)
	_next_card_drawer.position = Vector2(0, 15)
	_next_card_drawer.scale = Vector2(0.55, 0.55)  # smaller than field glyph so card fits
	_next_card.add_child(_next_card_drawer)
	# Centered character on the card
	_next_card_label = Label.new()
	_next_card_label.size = Vector2(100, 60)
	_next_card_label.position = Vector2(-50, -15)
	_next_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_card_label.add_theme_font_size_override("font_size", 36)
	_next_card_label.add_theme_color_override("font_color", Color(0.10, 0.07, 0.04, 1.0))
	_next_card.add_child(_next_card_label)

func _build_preview() -> void:
	_preview = Node2D.new()
	_preview.name = "Preview"
	_preview.position = Vector2(_spawn_x, SPAWN_Y)
	add_child(_preview)
	# A small drawer + label (mirrors Glyph visuals at half-alpha).
	# Uses direct_tier rather than a Glyph reference (preview has no body).
	_preview_drawer = Node2D.new()
	_preview_drawer.set_script(preload("res://scripts/glyph_drawer.gd"))
	_preview_drawer.set("direct_tier", _next_tier)
	_preview.add_child(_preview_drawer)
	var lbl := Label.new()
	lbl.name = "Char"
	lbl.size = Vector2(120, 120)
	lbl.position = -lbl.size * 0.5
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.10, 0.07, 0.04, 1.0))
	_preview.add_child(lbl)
	_preview.modulate.a = 0.7

func _process(delta: float) -> void:
	if _game_over:
		_update_shake(delta)
		return
	_check_danger(delta)
	_update_combo(delta)
	_update_shake(delta)
	if _mode == Mode.DROP:
		_process_drop_mode()
	else:
		_process_launch_mode(delta)

func _process_drop_mode() -> void:
	# Move spawn cursor with mouse x (clamped to field)
	var mx: float = clampf(get_global_mouse_position().x,
		FIELD_LEFT + 40, FIELD_RIGHT - 40)
	_spawn_x = mx
	if _preview:
		_preview.position = Vector2(mx, SPAWN_Y)
		_preview.visible = true
	if _trajectory_line:
		_trajectory_line.position.x = mx
		_trajectory_line.visible = true
	if _aim_renderer:
		_aim_renderer.visible = false

func _process_launch_mode(delta: float) -> void:
	# Glyph sits at fixed origin, cursor is the aim direction
	var origin := Vector2(LAUNCH_FIXED_X, SPAWN_Y)
	var mouse_pos := get_global_mouse_position()
	_spawn_x = origin.x
	if _preview:
		_preview.position = origin
		_preview.visible = true
	# Hide vertical drop trajectory
	if _trajectory_line:
		_trajectory_line.visible = false
	# Charge while holding
	if _is_charging:
		_charge_amount = min(1.0, _charge_amount + delta / LAUNCH_CHARGE_TIME)
	# Update aim arrow
	if _aim_renderer:
		_aim_renderer.visible = true
		_aim_renderer.set("origin", origin)
		_aim_renderer.set("aim_target", mouse_pos)
		_aim_renderer.set("charge", _charge_amount if _is_charging else 0.5)
		_aim_renderer.queue_redraw()

func _toggle_mode() -> void:
	_mode = Mode.LAUNCH if _mode == Mode.DROP else Mode.DROP
	_is_charging = false
	_charge_amount = 0.0
	_refresh_mode_ui()

func _refresh_mode_ui() -> void:
	if _mode_button:
		_mode_button.text = "落雨 (M 切換)" if _mode == Mode.DROP else "投石 (M 切換)"
	if _aim_renderer:
		_aim_renderer.visible = (_mode == Mode.LAUNCH)
	if _trajectory_line:
		_trajectory_line.visible = (_mode == Mode.DROP)

func _update_combo(delta: float) -> void:
	if _combo_count == 0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_reset_combo()

func _update_shake(delta: float) -> void:
	if _shake_strength <= 0.01:
		position = Vector2.ZERO
		return
	position = Vector2(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength)
	)
	_shake_strength = max(0.0, _shake_strength - _shake_decay * delta)

func _add_shake(strength: float) -> void:
	_shake_strength = max(_shake_strength, strength)

func _bump_combo() -> void:
	_combo_count = min(COMBO_MAX_MULT, _combo_count + 1)
	_combo_timer = COMBO_WINDOW
	_refresh_combo_label()

func _reset_combo() -> void:
	_combo_count = 0
	_combo_timer = 0.0
	_refresh_combo_label()

func _refresh_combo_label() -> void:
	if _combo_label == null:
		return
	if _combo_count <= 1:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	_combo_label.text = "× %d 連擊" % _combo_count
	# Pulse animation each bump
	if _combo_tween:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_label.scale = Vector2(1.0, 1.0)
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.3, 1.3), 0.08)
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.18)

func _check_danger(delta: float) -> void:
	# Any settled (low velocity) glyph above DANGER_Y? Then count down.
	var any_danger: bool = false
	for ch in get_children():
		if not ch is Glyph: continue
		var g: Glyph = ch
		if g.is_merging(): continue
		if g.global_position.y < DANGER_Y and g.linear_velocity.length() < 25.0:
			any_danger = true
			break
	if any_danger:
		_danger_timer += delta
		if _danger_timer >= DANGER_GRACE_SEC:
			_trigger_game_over()
	else:
		_danger_timer = max(0.0, _danger_timer - delta * 2.0)

func _input(event: InputEvent) -> void:
	if _game_over:
		if event is InputEventMouseButton and event.pressed:
			_restart()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_restart()
		return
	# Mode toggle key
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_toggle_mode()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _mode == Mode.DROP:
			if mb.pressed:
				_try_drop()
		else:
			# Launch: press = start charging; release = fire
			if mb.pressed:
				if _can_drop:
					_is_charging = true
					_charge_amount = 0.0
			else:
				if _is_charging:
					_fire_launch()
					_is_charging = false
					_charge_amount = 0.0

func _try_drop() -> void:
	if not _can_drop or _game_over:
		return
	_can_drop = false
	# Spawn glyph at cursor x, falls under gravity
	var g := Glyph.new()
	g.tier = _next_tier
	g.position = Vector2(_spawn_x, SPAWN_Y)
	g.collided_same_tier.connect(_on_glyph_collision.bind(g))
	add_child(g)
	_advance_next_tier()
	get_tree().create_timer(DROP_COOLDOWN).timeout.connect(func(): _can_drop = true)

func _fire_launch() -> void:
	if not _can_drop or _game_over:
		return
	_can_drop = false
	var origin := Vector2(LAUNCH_FIXED_X, SPAWN_Y)
	var aim := get_global_mouse_position()
	var dir := (aim - origin).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2(0, 1)
	# Force downward bias: don't allow firing upward
	if dir.y < 0.05:
		dir.y = 0.05
		dir = dir.normalized()
	var speed: float = lerp(LAUNCH_MIN_SPEED, LAUNCH_MAX_SPEED, _charge_amount)
	var g := Glyph.new()
	g.tier = _next_tier
	g.position = origin
	g.collided_same_tier.connect(_on_glyph_collision.bind(g))
	add_child(g)
	# Apply velocity after add_child so physics is initialized
	g.linear_velocity = dir * speed
	_advance_next_tier()
	# Slight kickback shake to sell the launch
	_add_shake(1.0 + _charge_amount * 2.5)
	get_tree().create_timer(DROP_COOLDOWN).timeout.connect(func(): _can_drop = true)

func _advance_next_tier() -> void:
	_next_tier = TierData.pick_droppable_tier(_rng)
	_update_preview()

func _update_preview() -> void:
	# Top-right info label
	if _ui_next:
		_ui_next.text = ""  # the visual card replaces text; clear to avoid duplication
	# Cursor preview (the glyph floating above field where mouse hovers)
	if _preview_drawer:
		_preview_drawer.set("direct_tier", _next_tier)
		_preview_drawer.queue_redraw()
	if _preview:
		var lbl: Label = _preview.get_node_or_null("Char")
		if lbl:
			lbl.text = TierData.get_char(_next_tier)
			var data: Dictionary = TierData.get_tier(_next_tier)
			var font_size: int = int(data.radius * 1.05)
			lbl.add_theme_font_size_override("font_size", font_size)
	# Right-side "next" card visual
	if _next_card_drawer:
		_next_card_drawer.set("direct_tier", _next_tier)
		_next_card_drawer.queue_redraw()
	if _next_card_label:
		_next_card_label.text = TierData.get_char(_next_tier)

# Track pending merges to dedupe — if both Glyphs report each other in
# the same frame, we only process once.
var _pending_merges: Array = []  # Array of [a, b] sorted by instance id

func _on_glyph_collision(other: Glyph, self_glyph: Glyph) -> void:
	if self_glyph.is_merging() or other.is_merging():
		return
	# Pair key: lower instance id first to dedupe (a,b vs b,a).
	var a: Glyph = self_glyph
	var b: Glyph = other
	if a.get_instance_id() > b.get_instance_id():
		var tmp := a; a = b; b = tmp
	for existing in _pending_merges:
		if existing[0] == a and existing[1] == b:
			return
	_pending_merges.append([a, b])
	a.mark_merging()
	b.mark_merging()
	# Schedule merge on next physics frame
	call_deferred("_execute_merge", a, b)

func _execute_merge(a: Glyph, b: Glyph) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		_pending_merges = _pending_merges.filter(func(p): return p[0] != a or p[1] != b)
		return
	var t: int = a.tier
	var mid_pos: Vector2 = (a.global_position + b.global_position) * 0.5
	# Combo: each merge bumps multiplier, awards bonus score
	_bump_combo()
	var combo_mult: int = max(1, _combo_count)
	var base_score: int = TierData.score_for_merge(t)
	_score += base_score * combo_mult
	_refresh_score()
	# Visual feedback: floating "+N" near the merge
	_spawn_floating_score(mid_pos, base_score * combo_mult, t)
	# Ink-burst particles, scaled by tier
	_spawn_merge_particles(mid_pos, t)
	# Screen shake on bigger merges
	if t >= 4:  # T5+ (海 onwards)
		_add_shake(2.0 + float(t - 4) * 2.5)
	# Remove old glyphs
	a.queue_free()
	b.queue_free()
	# Reaching max tier (詩) is a "watermelon" — bonus points + dramatic burst.
	if TierData.is_max_tier(t):
		var poem_bonus: int = TierData.score_for_merge(TierData.TIER_COUNT - 1) * 2 * combo_mult
		_score += poem_bonus
		_refresh_score()
		_spawn_floating_score(mid_pos + Vector2(0, -40), poem_bonus, 7)
		_spawn_merge_particles(mid_pos, 7)  # extra burst
		_add_shake(12.0)
	else:
		var new_g := Glyph.new()
		new_g.tier = t + 1
		new_g.position = mid_pos
		new_g.collided_same_tier.connect(_on_glyph_collision.bind(new_g))
		add_child(new_g)
	# Clear pending merge entry
	_pending_merges = _pending_merges.filter(func(p): return p[0] != a or p[1] != b)

func _spawn_merge_particles(pos: Vector2, tier: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 12 + tier * 6
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0 + tier * 20.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.6
	p.color = TierData.get_color(tier).lightened(0.25)
	var ramp := Gradient.new()
	ramp.set_color(0, TierData.get_color(tier).lightened(0.35))
	ramp.set_color(1, Color(TierData.get_color(tier).r, TierData.get_color(tier).g, TierData.get_color(tier).b, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	# Cleanup after particles finish
	var timer := get_tree().create_timer(p.lifetime + 0.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func _spawn_floating_score(pos: Vector2, amount: int, tier: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % amount
	lbl.position = pos - Vector2(40, 20)
	lbl.size = Vector2(80, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18 + min(tier, 4) * 2)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.8))
	lbl.add_theme_constant_override("outline_size", 3)
	add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 50, 0.8)
	t.tween_property(lbl, "modulate:a", 0.0, 0.8)
	t.chain().tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _refresh_score() -> void:
	if _ui_score:
		_ui_score.text = "分數 %d" % _score

func _trigger_game_over() -> void:
	if _game_over:
		return
	_game_over = true
	if _ui_status:
		_ui_status.text = "結束\n%d 分\n點擊重來" % _score
		_ui_status.add_theme_font_size_override("font_size", 32)
	if _preview:
		_preview.visible = false

func _restart() -> void:
	get_tree().reload_current_scene()
