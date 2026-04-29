## End screen for Night Market Shopping.
##
## v0.6 drama pass: builds the full layout up-front (so it settles) but
## fades each row in on a staggered schedule, popping a sparkle ParticleBurst
## next to each ingredient as it appears. Player can press any key once to
## skip the animation; a second press returns to the title.
class_name EndScreen
extends Control

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

## How long the full reveal takes from header to prompt.
const REVEAL_TOTAL: float = 3.0

## Color of each row's sparkle on appear.
const SPARKLE_COLOR: Color = Color("#F2A227")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Children of the vbox keyed by reveal order — each is faded in by
## `_reveal_at(i, delay)`. ParticleBurst spawned for ingredient rows only.
var _reveal_targets: Array[Control] = []
var _ingredient_targets: Array[Control] = []
var _animation_complete: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	Music.stop()
	_build_ui()
	_start_reveal_sequence()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEvent and event.is_pressed()):
		return
	# First press: skip animation. Second press: return to title.
	if not _animation_complete:
		_skip_to_end()
	else:
		Game.goto_level("title")


# ---------------------------------------------------------------------------
# UI construction (builds everything, hides for staggered reveal)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	vbox.position = Vector2(0, 0)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# v0.14: incomplete runs swap the cheery header for a softer "made do" line.
	var header_text: String = (
		"湊合一頓～" if Game.last_run_incomplete else "謝謝，今晚加菜！"
	)
	var header_color: Color = (
		Color("#888888") if Game.last_run_incomplete else Color("#F5EDDA")
	)
	_add_revealable(vbox, _make_label(header_text, 16, header_color))

	# Ingredient checklist — only the ingredients the player actually bought.
	# (Each row tracked separately so we can sparkle it during the reveal.)
	for id in Inventory.owned_ingredients():
		var row: Label = _make_label(
			"  ✓ %s" % Inventory.display_name(id), 10, Color("#C8E66D")
		)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_add_revealable(vbox, row)
		_ingredient_targets.append(row)

	# v0.14: dish description changes when the kid came home short.
	var dish_text: String = (
		"今晚的料理：簡單炒一炒"
		if Game.last_run_incomplete
		else "今晚的料理：醬油雞炒蔥蛋高麗菜"
	)
	_add_revealable(vbox, _make_label(dish_text, 9, Color("#F2A227")))

	# Money remaining (bounce-tweened from 0 to actual value when revealed).
	var money: Label = _make_label("剩 $0", 12, Color("#F2A227"))
	_add_revealable(vbox, money)
	_money_label_for_bounce = money

	_add_revealable(vbox, _make_label(
		"用時 %.1fs" % Game.session_time, 10, Color("#F5EDDA")
	))

	# v0.12: perfect run takes priority — even bigger badge, gold tint.
	if Game.last_run_perfect:
		_add_revealable(vbox, _make_label(
			"★ 滿漢全席！", 14, Color("#F2A227")
		))
	if Game.last_run_was_record:
		_add_revealable(vbox, _make_label("★ 新紀錄！", 12, Color("#F2A227")))
	elif HiScore.has_record():
		_add_revealable(vbox, _make_label(
			"最佳 %s" % HiScore.format_best(), 9, Color("#888888")
		))

	_add_revealable(vbox, _make_label("按任何鍵回到首頁", 10, Color("#888888")))


var _money_label_for_bounce: Label = null


## Centred label + adds it to vbox; hidden initially via modulate.a=0.
func _add_revealable(parent: VBoxContainer, label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1, 1, 1, 0)
	parent.add_child(label)
	_reveal_targets.append(label)


# ---------------------------------------------------------------------------
# Reveal sequencing
# ---------------------------------------------------------------------------

func _start_reveal_sequence() -> void:
	var n: int = _reveal_targets.size()
	if n == 0:
		_animation_complete = true
		return
	var step: float = REVEAL_TOTAL / float(n)
	for i in n:
		_schedule_reveal(_reveal_targets[i], i * step)
	# Mark complete a hair after the last reveal.
	get_tree().create_timer(REVEAL_TOTAL + 0.1).timeout.connect(
		func() -> void:
			_animation_complete = true
	)


func _schedule_reveal(target: Control, delay: float) -> void:
	# Use a timer instead of tween_delay so the await is cancellable on skip.
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(target) or target.modulate.a >= 0.99:
			return
		_reveal_one(target)
	)


func _reveal_one(target: Control) -> void:
	# Fade in.
	var t: Tween = create_tween()
	t.tween_property(target, "modulate:a", 1.0, 0.25)
	# Money line gets the bounce as it appears.
	if target == _money_label_for_bounce:
		_bounce_money(_money_label_for_bounce, Inventory.money)
	# Ingredient rows pop a sparkle next to their leading checkmark.
	if target in _ingredient_targets:
		_pop_sparkle_at(target)


## Spawns a 4-particle gold burst at the label's left-of-text position.
func _pop_sparkle_at(label: Control) -> void:
	var burst: ParticleBurst = ParticleBurst.new()
	# Anchor under the label, biased left where the checkmark sits.
	var local: Vector2 = label.global_position + Vector2(
		label.size.x / 2.0 - 30.0, label.size.y / 2.0
	)
	burst.position = local
	burst.count = 4
	burst.color = SPARKLE_COLOR
	burst.speed_min = 25.0
	burst.speed_max = 60.0
	burst.particle_size = 2.0
	burst.lifetime = 0.30
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.6
	add_child(burst)


## Skips remaining reveals — snaps every label to fully visible.
func _skip_to_end() -> void:
	for target in _reveal_targets:
		if not is_instance_valid(target):
			continue
		target.modulate = Color(1, 1, 1, 1)
	if _money_label_for_bounce != null:
		_money_label_for_bounce.text = "剩 $%d" % Inventory.money
	_animation_complete = true


# ---------------------------------------------------------------------------
# Helpers (unchanged from v0.5)
# ---------------------------------------------------------------------------

func _bounce_money(label: Label, target: int) -> void:
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BOUNCE)
	t.tween_method(
		func(v: float) -> void: label.text = "剩 $%d" % int(v),
		0.0, float(target), 0.6
	)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _make_cjk_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_cjk_font() -> FontFile:
	var f: FontFile = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f
